## -*- coding: utf-8 -*-
## Licensed to Cloudera, Inc. under one
## or more contributor license agreements.  See the NOTICE file
## distributed with this work for additional information
## regarding copyright ownership.  Cloudera, Inc. licenses this file
## to you under the Apache License, Version 2.0 (the
## "License"); you may not use this file except in compliance
## with the License.  You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.

<%!
  from django.utils.translation import ugettext as _
%>

<%namespace name="utils" file="../utils.inc.mako" />


<form action="${ action }" method="POST">

  <div class="modal-header">
    <a href="#" class="close" data-dismiss="modal">&times;</a>
    <h2>${ _('Rerun this job?') }</h2>
  </div>

  <div class="modal-body">
    <fieldset>
      <div id="config-container">
        <h3>${ _('Select actions to rerun') }</h3>
          <div class="fieldWrapper">
            <div class="row-fluid">
              <div class="span6">
                <input type="radio" name="rerun_form_choice" value="skip_nodes" id="skip_nodes" checked>
                  ${ _('All or skip successful') }
                  ${ utils.render_field(rerun_form['skip_nodes'], show_label=False) }
                </div>
              <div class="span6">
                <input type="radio" name="rerun_form_choice" value="fail_nodes" id="fail_nodes">
                ${ _('Only failed') }
              </div>
            </div>
          </div>
      </div>

      <div id="param-container">
        ${ params_form.management_form | n,unicode }

        % if params_form.forms:
          % if len(params_form.forms) > 1:
            <h3>${ _('Variables') }</h3>
          % endif
          % for form in params_form.forms:
            % for hidden in form.hidden_fields():
              ${ hidden | n,unicode }
            % endfor
            <div class="fieldWrapper">
              <div class="row-fluid
                % if form['name'].form.initial.get('name') == 'oozie.use.system.libpath':
                  hide
                % endif
                ">
                <div class="span6">
                  ${ form['name'].form.initial.get('name') }
                </div>
                <div class="span6">
                  ${ utils.render_field(form['value'], show_label=False) }
                </div>
              </div>
            </div>
          % endfor
        % endif
      </div>
    </fieldset>
  </div>

  <div class="modal-footer">
    <a href="#" class="btn secondary" data-dismiss="modal">${ _('Cancel') }</a>
    <input id="submit-btn" type="submit" class="btn btn-primary" value="${ _('Submit') }"/>
  </div>
</form>

<script type="text/javascript" charset="utf-8">
    $(document).ready(function(){
        $("#id_skip_nodes").jHueSelector({
            selectAllLabel: "${_('Select all')}",
            searchPlaceholder: "${_('Search')}",
            noChoicesFound: "${_('No successful actions found.')}",
            width:250,
            height:100
        });
    });
</script>
