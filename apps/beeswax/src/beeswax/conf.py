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

import os.path
import sys

from django.utils.translation import ugettext_lazy as _t, ugettext as _

from desktop.lib.conf import Config, coerce_bool

from beeswax.settings import NICE_NAME


SERVER_INTERFACE = Config(
  key="server_interface",
  help=_t("Beeswax or Hive Server 2 Thrift API used. Choices are: 'beeswax' or 'hiveserver2'."),
  default="beeswax")

BEESWAX_SERVER_HOST = Config(
  key="beeswax_server_host",
  help=_t("Host where Beeswax server Thrift daemon is running. If Kerberos security is enabled, "
         "the fully-qualified domain name (FQDN) is required, even if the Thrift daemon is running "
         "on the same host as Hue."),
  default="localhost")

BEESWAX_SERVER_PORT = Config(
  key="beeswax_server_port",
  help=_t("Configure the port the Beeswax Thrift server runs on."),
  default=8002,
  type=int)

BEESWAX_META_SERVER_HOST = Config(
  key="beeswax_meta_server_host",
  help=_t("Host where internal metastore Thrift daemon is running."),
  private=True,
  default="localhost")

BEESWAX_META_SERVER_PORT = Config(
  key="beeswax_meta_server_port",
  help=_t("Configure the port the internal metastore daemon runs on. Used only if "
       "hive.metastore.local is true."),
  default=8003,
  type=int)

BEESWAX_SERVER_BIN = Config(
  key="beeswax_server_bin",
  help=_t("Path to beeswax_server.sh"),
  private=True,
  default=os.path.join(os.path.dirname(__file__), "..", "..", "beeswax_server.sh"))

BEESWAX_SERVER_HEAPSIZE = Config(
  key="beeswax_server_heapsize",
  help=_t("Maximum Java heap size (in megabytes) used by Beeswax Server.  " + \
    "Note that the setting of HADOOP_HEAPSIZE in $HADOOP_CONF_DIR/hadoop-env.sh " + \
    "may override this setting."),
  default="1000")

BEESWAX_HIVE_HOME_DIR = Config(
  key="hive_home_dir",
  default=os.environ.get("HIVE_HOME", "/usr/lib/hive"),
  help=_t("Path to the root of the Hive installation; " +
        "defaults to environment variable when not set."))

BEESWAX_HIVE_CONF_DIR = Config(
  key='hive_conf_dir',
  help=_t('Hive configuration directory, where hive-site.xml is located.'),
  default=os.environ.get("HIVE_CONF_DIR", '/etc/hive/conf'))

LOCAL_EXAMPLES_DATA_DIR = Config(
  key='local_examples_data_dir',
  default=os.path.join(os.path.dirname(__file__), "..", "..", "data"),
  help=_t('The local filesystem path containing the Beeswax examples.'))

BEESWAX_SERVER_CONN_TIMEOUT = Config(
  key='beeswax_server_conn_timeout',
  default=120,
  type=int,
  help=_t('Timeout in seconds for Thrift calls to Beeswax service.'))

METASTORE_CONN_TIMEOUT= Config(
  key='metastore_conn_timeout',
  default=10,
  type=int,
  help=_t('Timeouts in seconds for Thrift calls to the Hive metastore. This timeout should take into account that the metastore could talk to an external database.'))

BEESWAX_RUNNING_QUERY_LIFETIME = Config(
  key='beeswax_running_query_lifetime',
  default=604800000L, # 7*24*60*60*1000 (1 week)
  type=long,
  help=_t('Time in milliseconds for Beeswax to persist queries in its cache.'))

BROWSE_PARTITIONED_TABLE_LIMIT = Config(
  key='browse_partitioned_table_limit',
  default=250,
  type=int,
  help=_t('Set a LIMIT clause when browsing a partitioned table. A positive value will be set as the LIMIT. If 0 or negative, do not set any limit.'))

SHARE_SAVED_QUERIES = Config(
  key='share_saved_queries',
  default=True,
  type=coerce_bool,
  help=_t('Share saved queries with all users. If set to false, saved queries are visible only to the owner and administrators.'))

def config_validator(user):
  # dbms is dependent on beeswax.conf (this file)
  # import in method to avoid circular dependency
  from beeswax.server import dbms

  res = []
  try:
    if not 'test' in sys.argv: # Avoid tests hanging
      server = dbms.get(user)
      server.get_databases()
  except:
    res.append((NICE_NAME, _("The app won't work without a running Beeswax/HiveServer2 server and/or Hive Metastore.")))

  return res
