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

import copy
import base64
import datetime
import logging
import traceback

from django.db import models
from django.contrib.auth.models import User
from django.utils.translation import ugettext as _, ugettext_lazy as _t

from enum import Enum

from desktop.lib.exceptions_renderable import PopupException

from beeswax.design import HQLdesign, hql_query
from beeswaxd.ttypes import QueryHandle as BeeswaxdQueryHandle, QueryState
from TCLIService.ttypes import TSessionHandle, THandleIdentifier,\
  TOperationState, TOperationHandle, TOperationType


LOG = logging.getLogger(__name__)

QUERY_SUBMISSION_TIMEOUT = datetime.timedelta(0, 60 * 60)               # 1 hour

# Constants for DB fields, hue ini
BEESWAX = 'beeswax'
HIVE_SERVER2 = 'hiveserver2'
QUERY_TYPES = (HQL, IMPALA) = range(2)


class QueryHistory(models.Model):
  """
  Holds metadata about all queries that have been executed.
  """
  STATE = Enum('submitted', 'running', 'available', 'failed', 'expired')
  SERVER_TYPE = ((BEESWAX, 'Beeswax'), (HIVE_SERVER2, 'Hive Server 2'))

  owner = models.ForeignKey(User, db_index=True)
  query = models.TextField()

  last_state = models.IntegerField(db_index=True)
  has_results = models.BooleanField(default=False)          # If true, this query will eventually return tabular results.
  submission_date = models.DateTimeField(auto_now_add=True)
  # In case of multi statements in a query, these are the id of the currently running statement
  server_id = models.CharField(max_length=1024, null=True)  # Aka secret, only query in the "submitted" state is allowed to have no server_id
  server_guid = models.CharField(max_length=1024, null=True, default=None)
  statement_number = models.SmallIntegerField(default=0)    # The index of the currently running statement
  operation_type = models.SmallIntegerField(null=True)
  modified_row_count = models.FloatField(null=True)
  log_context = models.CharField(max_length=1024, null=True)

  server_host = models.CharField(max_length=128, help_text=_('Host of the query server.'), default='')
  server_port = models.SmallIntegerField(help_text=_('Port of the query server.'), default=0)
  server_name = models.CharField(max_length=128, help_text=_('Name of the query server.'), default='')
  server_type = models.CharField(max_length=128, help_text=_('Type of the query server.'), default=BEESWAX, choices=SERVER_TYPE)
  query_type = models.SmallIntegerField(help_text=_('Type of the query.'), default=HQL, choices=((HQL, 'HQL'), (IMPALA, 'IMPALA')))

  design = models.ForeignKey('SavedQuery', to_field='id', null=True) # Some queries (like read/create table) don't have a design
  notify = models.BooleanField(default=False)                        # Notify on completion

  class Meta:
    ordering = ['-submission_date']

  @staticmethod
  def build(*args, **kwargs):
    if kwargs['server_type'] == HIVE_SERVER2:
      return HiveServerQueryHistory(*args, **kwargs)
    else:
      return BeeswaxQueryHistory(*args, **kwargs)

  def get_full_object(self):
    if self.server_type == HiveServerQueryHistory.node_type:
      return HiveServerQueryHistory.objects.get(id=self.id)
    else:
      return BeeswaxQueryHistory.objects.get(id=self.id)

  @staticmethod
  def get(id):
    if QueryHistory.objects.filter(id=id, server_type=BEESWAX).exists():
      return BeeswaxQueryHistory.objects.get(id=id)
    else:
      return HiveServerQueryHistory.objects.get(id=id)

  def get_type_name(self):
    if self.query_type == 1:
      return 'impala'
    else:
      return 'beeswax'

  def get_query_server_config(self):
    from beeswax.server.dbms import get_query_server_config

    query_server = get_query_server_config(self.get_type_name())
    query_server.update({
        'server_name': self.server_name,
        'server_host': self.server_host,
        'server_port': self.server_port,
        'server_type': self.server_type,
    })

    return query_server


  def get_current_statement(self):
    if self.design is not None:
      design = self.design.get_design()
      return design.get_query_statement(self.statement_number)
    else:
      return self.query

  def is_finished(self):
    is_statement_finished = not self.is_running()

    if self.design is not None:
      design = self.design.get_design()
      return is_statement_finished and self.statement_number + 1 == design.statement_count # Last statement
    else:
      return is_statement_finished

  def is_running(self):
    return self.last_state in (QueryHistory.STATE.running.index, QueryHistory.STATE.submitted.index)

  def is_success(self):
    return self.last_state in (QueryHistory.STATE.available.index,)

  def is_failure(self):
    return self.last_state in (QueryHistory.STATE.expired.index, QueryHistory.STATE.failed.index)

  def set_to_running(self):
    self.last_state = QueryHistory.STATE.running.index

  def set_to_failed(self):
    self.last_state = QueryHistory.STATE.failed.index

  def set_to_available(self):
    self.last_state = QueryHistory.STATE.available.index


def make_query_context(type, info):
  """
  ``type`` is one of "table" and "design", and ``info`` is the table name or design id.
  Returns a value suitable for GET param.
  """
  if type == 'table':
    return "%s:%s" % (type, info)
  elif type == 'design':
    # Use int() to validate that info is a number
    return "%s:%s" % (type, int(info))
  LOG.error("Invalid query context type: %s" % (type,))
  return ''                                     # Empty string is safer than None


class HiveServerQueryHistory(QueryHistory):
  # Map from (thrift) server state
  STATE_MAP = {
    TOperationState.INITIALIZED_STATE          : QueryHistory.STATE.submitted,
    TOperationState.RUNNING_STATE         : QueryHistory.STATE.running,
    TOperationState.FINISHED_STATE      : QueryHistory.STATE.available,
    TOperationState.CANCELED_STATE          : QueryHistory.STATE.failed,
    TOperationState.CLOSED_STATE         : QueryHistory.STATE.expired,
    TOperationState.ERROR_STATE        : QueryHistory.STATE.failed,
    TOperationState.UKNOWN_STATE        : QueryHistory.STATE.failed,
  }

  node_type = HIVE_SERVER2

  class Meta:
    proxy = True

  def get_handle(self):
    secret, guid = HiveServerQueryHandle.get_decoded(self.server_id, self.server_guid)

    return HiveServerQueryHandle(secret=secret,
                                 guid=guid,
                                 has_result_set=self.has_results,
                                 operation_type=self.operation_type,
                                 modified_row_count=self.modified_row_count)

  def save_state(self, new_state):
    self.last_state = new_state.index
    self.save()


class BeeswaxQueryHistory(QueryHistory):
  # Map from (thrift) server state
  STATE_MAP = {
    QueryState.CREATED          : QueryHistory.STATE.submitted,
    QueryState.INITIALIZED      : QueryHistory.STATE.submitted,
    QueryState.COMPILED         : QueryHistory.STATE.running,
    QueryState.RUNNING          : QueryHistory.STATE.running,
    QueryState.FINISHED         : QueryHistory.STATE.available,
    QueryState.EXCEPTION        : QueryHistory.STATE.failed
  }

  node_type = BEESWAX

  class Meta:
    proxy = True

  def get_handle(self):
    """
    get_server_id() ->  (server-side query id)

    The boolean indicates success/failure. The server_id follows, and may be None.
    Note that the server_id can legally be None when the query is just submitted.
    This method handles the various cases of the server_id being absent.

    Does not issue RPC.
    """
    if self.server_id:
      return BeeswaxQueryHandle(secret=self.server_id, has_result_set=self.has_results, log_context=self.log_context)
    else:
      # Query being submitted have no server_id?
      if self.last_state == QueryHistory.STATE.submitted.index:
        # (1) Really? Check the submission date.
        #     This is possibly due to the server dying when compiling the query
        if self.submission_date.now() - self.submission_date > QUERY_SUBMISSION_TIMEOUT:
          LOG.error("Query submission taking too long. Expiring id %s: [%s]..." % (self.id, self.query[:40]))
          self.save_state(QueryHistory.STATE.expired)
        else:
          # (2) It's not an error. Return the current state
          LOG.debug("Query %s (submitted) has no server id yet" % (self.id,))
      else:
        # (3) It has no server_id for no good reason. A case (1) will become this
        #     after we expire it. Note that we'll never be able to recover this
        #     query.
        LOG.error("Query %s (%s) has no server id [%s]..." %
                  (self.id, QueryHistory.STATE[self.last_state], self.query[:40]))
        self.save_state(QueryHistory.STATE.expired)
      return None

  def save_state(self, new_state):
    """Set the last_state from an enum, and save"""
    if self.last_state != new_state.index:
      if new_state.index < self.last_state:
        backtrace = ''.join(traceback.format_stack(limit=5))
        LOG.error("Invalid query state transition: %s -> %s\n%s" % (QueryHistory.STATE[self.last_state], new_state, backtrace))
        return
      self.last_state = new_state.index
      self.save()


class SavedQuery(models.Model):
  """
  Stores the query that people have save or submitted.

  Note that this used to be called QueryDesign. Any references to 'design'
  probably mean a SavedQuery.
  """
  DEFAULT_NEW_DESIGN_NAME = _('My saved query')
  AUTO_DESIGN_SUFFIX = _(' (new)')
  TYPES = QUERY_TYPES
  TYPES_MAPPING = {'beeswax': HQL, 'hql': HQL, 'impala': IMPALA}

  type = models.IntegerField(null=False)
  owner = models.ForeignKey(User, db_index=True)
  # Data is a json of dictionary. See the beeswax.design module.
  data = models.TextField(max_length=65536)
  name = models.CharField(max_length=64)
  desc = models.TextField(max_length=1024)
  mtime = models.DateTimeField(auto_now=True)
  # An auto design is a place-holder for things users submit but not saved.
  # We still want to store it as a design to allow users to save them later.
  is_auto = models.BooleanField(default=False, db_index=True)
  is_trashed = models.BooleanField(default=False, db_index=True, verbose_name=_t('Is trashed'),
                                   help_text=_t('If this query is trashed.'))

  class Meta:
    ordering = ['-mtime']

  def get_design(self):
    return HQLdesign.loads(self.data)

  def clone(self):
    """clone() -> A new SavedQuery with a deep copy of the same data"""
    design = SavedQuery(type=self.type, owner=self.owner)
    design.data = copy.deepcopy(self.data)
    design.name = copy.deepcopy(self.name)
    design.desc = copy.deepcopy(self.desc)
    design.is_auto = copy.deepcopy(self.is_auto)
    return design

  @classmethod
  def create_empty(cls, app_name, owner):
    query_type = SavedQuery.TYPES_MAPPING[app_name]
    design = SavedQuery(owner=owner, type=query_type)
    design.name = SavedQuery.DEFAULT_NEW_DESIGN_NAME
    design.desc = ''
    design.data = hql_query('').dumps()
    design.is_auto = True
    design.save()
    return design

  @staticmethod
  def get(id, owner=None, type=None):
    """
    get(id, owner=None, type=None) -> SavedQuery object

    Checks that the owner and type match (when given).
    May raise PopupException (type/owner mismatch).
    May raise SavedQuery.DoesNotExist.
    """
    try:
      design = SavedQuery.objects.get(id=id)
    except SavedQuery.DoesNotExist, err:
      msg = _('Cannot retrieve Beeswax design id %(id)s') % {'id': id}
      raise err

    if owner is not None and design.owner != owner:
      msg = _('Design id %(id)s does not belong to user %(user)s') % {'id': id, 'user': owner}
      LOG.error(msg)
      raise PopupException(msg)

    if type is not None and design.type != type:
      msg = _('Type mismatch for design id %(id)s (owner %(owner)s) - Expected %(expected_type)s got %(real_type)s') % \
            {'id': id, 'owner': owner, 'expected_type': design.type, 'real_type': type}
      LOG.error(msg)
      raise PopupException(msg)

    return design

  def __str__(self):
    return '%s %s' % (self.name, self.owner)

  def get_query_context(self):
    try:
      return make_query_context('design', self.id)
    except:
      return ""


class SessionManager(models.Manager):
  def get_session(self, user, application='beeswax'):
    try:
      return self.filter(owner=user, application=application).latest("last_used")
    except Session.DoesNotExist:
      pass


class Session(models.Model):
  """
  A sessions is bound to a user and an application (e.g. Bob with the Impala application).
  """
  owner = models.ForeignKey(User, db_index=True)
  status_code = models.PositiveSmallIntegerField()
  secret = models.TextField(max_length='100')
  guid = models.TextField(max_length='100')
  server_protocol_version = models.SmallIntegerField(default=0)
  last_used = models.DateTimeField(auto_now=True, db_index=True, verbose_name=_t('Last used'))
  application = models.CharField(max_length=128, help_text=_t('Application we communicate with.'), default='beeswax')

  objects = SessionManager()

  def get_handle(self):
    secret, guid = HiveServerQueryHandle.get_decoded(secret=self.secret, guid=self.guid)

    handle_id = THandleIdentifier(secret=secret, guid=guid)
    return TSessionHandle(sessionId=handle_id)

  def __str__(self):
    return '%s %s' % (self.owner, self.last_used)




class QueryHandle(object):
  def __init__(self, secret, guid=None, operation_type=None, has_result_set=None, modified_row_count=None, log_context=None):
    self.secret = secret
    self.guid = guid
    self.operation_type = operation_type
    self.has_result_set = has_result_set
    self.modified_row_count = modified_row_count
    self.log_context = log_context

  def is_valid(self):
    return sum([bool(obj) for obj in [self.get()]]) > 0

  def __str__(self):
    return '%s %s' % (self.secret, self.guid)



class HiveServerQueryHandle(QueryHandle):
  """
  QueryHandle for Hive Server 2.

  Store THandleIdentifier base64 encoded in order to be unicode compatible with Django.
  """
  def __init__(self, **kwargs):
    super(HiveServerQueryHandle, self).__init__(**kwargs)
    self.secret, self.guid = self.get_encoded()

  def get(self):
    return self.secret, self.guid

  def get_rpc_handle(self):
    secret, guid = self.get_decoded(self.secret, self.guid)

    operation = getattr(TOperationType, TOperationType._NAMES_TO_VALUES.get(self.operation_type, 'EXECUTE_STATEMENT'))
    return TOperationHandle(operationId=THandleIdentifier(guid=guid, secret=secret),
                            operationType=operation,
                            hasResultSet=self.has_result_set,
                            modifiedRowCount=self.modified_row_count)

  # TODO hide
  @classmethod
  def get_decoded(cls, secret, guid):
    return base64.decodestring(secret), base64.decodestring(guid)

  # TODO hide
  def get_encoded(self):
    return base64.encodestring(self.secret), base64.encodestring(self.guid)


class BeeswaxQueryHandle(QueryHandle):
  """
  QueryHandle for Beeswax.
  """
  def __init__(self, secret, has_result_set, log_context):
    super(BeeswaxQueryHandle, self).__init__(secret=secret,
                                             has_result_set=has_result_set,
                                             log_context=log_context)

  def get(self):
    return self.secret, None

  def get_rpc_handle(self):
    return BeeswaxdQueryHandle(id=self.secret, log_context=self.log_context)

  # TODO remove
  def get_encoded(self):
    return self.get(), None


class MetaInstall(models.Model):
  """
  Metadata about the installation. Should have at most one row.
  """
  installed_example = models.BooleanField()

  @staticmethod
  def get():
    """
    MetaInstall.get() -> MetaInstall object

    It helps dealing with that this table has just one row.
    """
    try:
      return MetaInstall.objects.get(id=1)
    except MetaInstall.DoesNotExist:
      return MetaInstall(id=1)
