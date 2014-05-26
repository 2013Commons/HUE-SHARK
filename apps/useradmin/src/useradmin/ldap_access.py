#!/usr/bin/env python
# Licensed to Cloudera, Inc. under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  Cloudera, Inc. licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""
This module provides access to LDAP servers, along with some basic functionality required for Hue and
User Admin to work seamlessly with LDAP.
"""
import re

import desktop.conf
import ldap
import ldap.filter

import logging
LOG = logging.getLogger(__name__)

CACHED_LDAP_CONN = None

def get_connection():
  global CACHED_LDAP_CONN
  if CACHED_LDAP_CONN is not None:
    return CACHED_LDAP_CONN

  ldap_url = desktop.conf.LDAP.LDAP_URL.get()
  nt_domain = desktop.conf.LDAP.NT_DOMAIN.get()
  username = desktop.conf.LDAP.BIND_DN.get()
  password = desktop.conf.LDAP.BIND_PASSWORD.get()
  ldap_cert = desktop.conf.LDAP.LDAP_CERT.get()

  if ldap_url is None:
    raise Exception('No LDAP URL was specified')

  return LdapConnection(ldap_url, get_ldap_username(username, nt_domain),
                        password, ldap_cert)

def get_ldap_username(username, nt_domain):
  if nt_domain:
    return '%s@%s' % (username, nt_domain)
  else:
    return username


class LdapConnection(object):
  """
  Constructor creates LDAP connection. Contains methods
  to easily query an LDAP server.
  """

  def __init__(self, ldap_url, bind_user=None, bind_password=None, cert_file=None):
    """
    Constructor initializes the LDAP connection
    """
    if cert_file is not None:
      ldap.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_ALLOW)
      ldap.set_option(ldap.OPT_X_TLS_CACERTFILE, cert_file)

    ldap.set_option(ldap.OPT_REFERRALS, 0)

    self.ldap_handle = ldap.initialize(ldap_url)

    if bind_user is not None:
      try:
        self.ldap_handle.simple_bind_s(bind_user, bind_password)
      except:
        raise RuntimeError("Failed to bind to LDAP server as user %s" %
            (bind_user,))
    else:
      try:
        # Do anonymous bind
        self.ldap_handle.simple_bind_s('','')
      except:
        raise RuntimeError("Failed to bind to LDAP server anonymously")

  def _get_search_params(self, name, attr, find_by_dn=False):
    """
      if we are to find this ldap object by full distinguished name,
      then search by setting search_dn to the 'name'
      rather than by filtering by 'attr'.
    """
    base_dn = self._get_root_dn()
    if find_by_dn:
      search_dn = re.sub(r'(\w+=)', lambda match: match.group(0).upper(), name)

      if not search_dn.upper().endswith(base_dn.upper()):
        raise RuntimeError("Distinguished Name provided does not contain configured Base DN. Base DN: %(base_dn)s, DN: %(dn)s" % {
          'base_dn': base_dn,
          'dn': search_dn
        })

      return (search_dn, '')
    else:
      return (base_dn, '(' + attr + '=' + name + ')')

  def _transform_find_user_results(self, result_data, user_name_attr):
    """
    :param result_data: List of dictionaries that have ldap attributes and their associated values. Generally the result list from an ldapsearch request.
    :param user_name_attr: The ldap attribute that is returned by the server to map to ``username`` in the return dictionary.
    
    :returns list of dictionaries that take on the following form: {
      'dn': <distinguished name of entry>,
      'username': <ldap attribute associated with user_name_attr>
      'first': <first name>
      'last': <last name>
      'email': <email>
      'groups': <list of DNs of groups that user is a member of>
    }
    """
    user_info = []
    if result_data:
      for dn, data in result_data:
        # Skip Active Directory # refldap entries.
        if dn is not None:

          # Skip unnamed entries.
          if user_name_attr not in data:
            LOG.warn('Could not find %s in ldap attributes' % user_name_attr)
            continue

          ldap_info = {
            'dn': dn,
            'username': data[user_name_attr][0]
          }

          if 'givenName' in data:
            ldap_info['first'] = data['givenName'][0]
          if 'sn' in data:
            ldap_info['last'] = data['sn'][0]
          if 'mail' in data:
            ldap_info['email'] = data['mail'][0]
          # memberOf and isMemberOf should be the same if they both exist
          if 'memberOf' in data:
            ldap_info['groups'] = data['memberOf']
          if 'isMemberOf' in data:
            ldap_info['groups'] = data['isMemberOf']

          user_info.append(ldap_info)
    return user_info


  def _transform_find_group_results(self, result_data, group_name_attr):
    group_info = []
    if result_data:
      for dn, data in result_data:

        # Skip Active Directory # refldap entries.
        if dn is not None:

          # Skip unnamed entries.
          if group_name_attr not in data:
            LOG.warn('Could not find %s in ldap attributes' % group_name_attr)
            continue

          ldap_info = {
            'dn': dn,
            'name': data[group_name_attr][0]
          }

          member_attr = desktop.conf.LDAP.GROUPS.GROUP_MEMBER_ATTR.get()
          if member_attr in data:
            ldap_info['members'] = data[member_attr]
          else:
            ldap_info['members'] = []

          if 'posixGroup' in data['objectClass'] and 'memberUid' in data:
            ldap_info['posix_members'] = data['memberUid']
          else:
            ldap_info['posix_members'] = []

          group_info.append(ldap_info)

    return group_info

  def find_users(self, username_pattern, search_attr=None, user_name_attr=None, find_by_dn=False, scope=ldap.SCOPE_SUBTREE):
    """
    LDAP search helper method finding users. This supports searching for users
    by distinguished name, or the configured username attribute.

    :param username_pattern: The pattern to match ``search_attr`` against. Defaults to ``search_attr`` if none.
    :param search_attr: The ldap attribute to search for ``username_pattern``. Defaults to LDAP -> USERS -> USER_NAME_ATTR config value.
    :param user_name_attr: The ldap attribute that is returned by the server to map to ``username`` in the return dictionary.
    :param find_by_dn: Search by distinguished name.
    :param scope: ldapsearch scope.
    
    :returns: List of dictionaries that take on the following form: {
      'dn': <distinguished name of entry>,
      'username': <ldap attribute associated with user_name_attr>
      'first': <first name>
      'last': <last name>
      'email': <email>
      'groups': <list of DNs of groups that user is a member of>
    }
    ``
    """
    if not search_attr:
      search_attr = desktop.conf.LDAP.USERS.USER_NAME_ATTR.get()
    if not user_name_attr:
      user_name_attr = search_attr

    user_filter = desktop.conf.LDAP.USERS.USER_FILTER.get()
    if not user_filter.startswith('('):
      user_filter = '(' + user_filter + ')'

    # Allow wild cards on non distinguished names
    sanitized_name = ldap.filter.escape_filter_chars(username_pattern).replace(r'\2a', r'*')
    search_dn, user_name_filter = self._get_search_params(sanitized_name, search_attr, find_by_dn)
    ldap_filter = '(&' + user_filter + user_name_filter + ')'
    attrlist = ['objectClass', 'isMemberOf', 'memberOf', 'givenName', 'sn', 'mail', 'dn', user_name_attr]

    ldap_result_id = self.ldap_handle.search(search_dn, scope, ldap_filter, attrlist)
    result_type, result_data = self.ldap_handle.result(ldap_result_id)

    if result_type == ldap.RES_SEARCH_RESULT:
      return self._transform_find_user_results(result_data, user_name_attr)
    else:
      return []

  def find_groups(self, groupname_pattern, search_attr=None, group_name_attr=None, find_by_dn=False, scope=ldap.SCOPE_SUBTREE):
    """
    LDAP search helper method for finding groups

    :param groupname_pattern: The pattern to match ``search_attr`` against. Defaults to ``search_attr`` if none.
    :param search_attr: The ldap attribute to search for ``groupname_pattern``. Defaults to LDAP -> GROUPS -> GROUP_NAME_ATTR config value.
    :param group_name_attr: The ldap attribute that is returned by the server to map to ``name`` in the return dictionary.
    :param find_by_dn: Search by distinguished name.
    :param scope: ldapsearch scope.
    
    :returns: List of dictionaries that take on the following form: {
      'dn': <distinguished name of entry>,
      'name': <ldap attribute associated with group_name_attr>
      'first': <first name>
      'last': <last name>
      'email': <email>
      'groups': <list of DNs of groups that user is a member of>
    }
    """
    if not search_attr:
      search_attr = desktop.conf.LDAP.GROUPS.GROUP_NAME_ATTR.get()
    if not group_name_attr:
      group_name_attr = search_attr

    group_filter = desktop.conf.LDAP.GROUPS.GROUP_FILTER.get()
    if not group_filter.startswith('('):
      group_filter = '(' + group_filter + ')'

    # Allow wild cards on non distinguished names
    sanitized_name = ldap.filter.escape_filter_chars(groupname_pattern).replace(r'\2a', r'*')
    search_dn, group_name_filter = self._get_search_params(sanitized_name, search_attr, find_by_dn)
    ldap_filter = '(&' + group_filter + group_name_filter + ')'
    attrlist = ['objectClass', 'dn', 'memberUid', desktop.conf.LDAP.GROUPS.GROUP_MEMBER_ATTR.get(), group_name_attr]

    ldap_result_id = self.ldap_handle.search(search_dn, scope, ldap_filter, attrlist)
    result_type, result_data = self.ldap_handle.result(ldap_result_id)

    if result_type == ldap.RES_SEARCH_RESULT:
      return self._transform_find_group_results(result_data, group_name_attr)
    else:
      return []

  def _get_root_dn(self):
    """
    Returns the configured base DN (DC=desktop,DC=local).
    """
    return desktop.conf.LDAP.BASE_DN.get()
