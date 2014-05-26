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

try:
  import json
except ImportError:
  import simplejson as json

from django.conf import settings
from django.http import HttpResponse
from django.utils.translation import ugettext as _

from desktop.lib.django_util import render
from desktop.models import Settings
from desktop.views import check_config
from desktop import appmanager

from hadoop.core_site import get_trash_interval


def admin_wizard(request):
  apps = appmanager.get_apps(request.user)
  app_names = [app.name for app in sorted(apps, key=lambda app: app.menu_index)]

  collect_usage = Settings.get_settings().collect_usage

  return render('admin_wizard.mako', request, {
      'version': settings.HUE_DESKTOP_VERSION,
      'check_config': check_config(request).content,
      'apps': dict([(app.name, app) for app in apps]),
      'app_names': app_names,
      'collect_usage': collect_usage,
      'trash_enabled': get_trash_interval()
  })


def collect_usage(request):
  response = {'status': -1, 'data': ''}

  if request.method == 'POST':
    try:
      settings = Settings.get_settings()
      settings.collect_usage = request.POST.get('collect_usage', False)
      settings.save()
      response['status'] = 0
      response['collect_usage'] = settings.collect_usage
    except Exception, e:
      response['data'] = str(e)
  else:
    response['data'] = _('POST request required.')

  return HttpResponse(json.dumps(response), mimetype="application/json")
