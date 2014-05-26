#!/usr/bin/env python2.5
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
Configuration options for the "user admin" application
"""

from desktop.lib.conf import Config

DEFAULT_USER_GROUP = Config(
    key="default_user_group",
    help="The name of a default group for users at creation time, or at first login "
         "if the server is configured to authenticate against an external source.",
    type=str,
    default='default')
