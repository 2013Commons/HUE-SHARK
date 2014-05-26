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

from django.conf.urls.defaults import patterns, url

urlpatterns = patterns('beeswax.views',
  url(r'^$', 'index', name='index'),

  url(r'^execute/(?P<design_id>\d+)?$', 'execute_query', name='execute_query'),
  url(r'^explain_parameterized/(?P<design_id>\d+)$', 'explain_parameterized_query', name='explain_parameterized_query'),
  url(r'^execute_parameterized/(?P<design_id>\d+)$', 'execute_parameterized_query', name='execute_parameterized_query'),
  url(r'^watch/(?P<id>\d+)$', 'watch_query', name='watch_query'),
  url(r'^watch/json/(?P<id>\d+)$', 'watch_query_refresh_json', name='watch_query_refresh_json'),
  url(r'^cancel_operation/(?P<query_id>\d+)?$', 'cancel_operation', name='cancel_operation'),
  url(r'^results/(?P<id>\d+)/(?P<first_row>\d+)$', 'view_results', name='view_results'),
  url(r'^download/(?P<id>\d+)/(?P<format>\w+)$', 'download', name='download'),
  url(r'^save_results/(?P<id>\d+)$', 'save_results', name='save_results'),
  url(r'^save_design_properties$', 'save_design_properties', name='save_design_properties'), # Ajax

  url(r'^autocomplete/$', 'autocomplete', name='autocomplete'),
  url(r'^autocomplete/(?P<database>\w+)/$', 'autocomplete', name='autocomplete'),
  url(r'^autocomplete/(?P<database>\w+)/(?P<table>\w+)$', 'autocomplete', name='autocomplete'),


  url(r'^my_queries$', 'my_queries', name='my_queries'),
  url(r'^list_designs$', 'list_designs', name='list_designs'),
  url(r'^list_trashed_designs$', 'list_trashed_designs', name='list_trashed_designs'),
  url(r'^delete_designs$', 'delete_design', name='delete_design'),
  url(r'^restore_designs$', 'restore_design', name='restore_design'),
  url(r'^clone_design/(?P<design_id>\d+)$', 'clone_design', name='clone_design'),
  url(r'^query_history$', 'list_query_history', name='list_query_history'),

  url(r'^configuration$', 'configuration', name='configuration'),
  url(r'^install_examples$', 'install_examples', name='install_examples'),
  url(r'^query_cb/done/(?P<server_id>\S+)$', 'query_done_cb', name='query_done_cb'),
)

urlpatterns += patterns(
  'beeswax.create_database',

  url(r'^create/database$', 'create_database', name='create_database'),
)

urlpatterns += patterns(
  'beeswax.create_table',

  url(r'^create/create_table/(?P<database>\w+)$', 'create_table', name='create_table'),
  url(r'^create/import_wizard/(?P<database>\w+)$', 'import_wizard', name='import_wizard'),
  url(r'^create/auto_load/(?P<database>\w+)$', 'load_after_create', name='load_after_create'),
)
