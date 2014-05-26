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
  from desktop.views import commonheader, commonfooter
  from django.utils.translation import ugettext as _
%>

<%namespace name="actionbar" file="actionbar.mako" />

${ commonheader(None, "pig", user, "100px") | n,unicode }

<div class="subnav subnav-fixed">
  <div class="container-fluid">
    <ul class="nav nav nav-pills">
      <li class="active"><a href="#editor" data-bind="css: { unsaved: isDirty }">${ _('Editor') }</a></li>
      <li><a href="#scripts">${ _('Scripts') }</a></li>
      <li><a href="#dashboard">${ _('Dashboard') }</a></li>
    </ul>
  </div>
</div>


<div class="container-fluid">
  <div id="scripts" class="row-fluid mainSection hide">
    <%actionbar:render>
      <%def name="search()">
          <input id="filter" type="text" class="input-xlarge search-query" placeholder="${_('Search for script name or content')}">
      </%def>

      <%def name="actions()">
          <button class="btn fileToolbarBtn" title="${_('Run this script')}" data-bind="enable: selectedScripts().length == 1, click: listRunScript, visible: scripts().length > 0"><i class="icon-play"></i> ${_('Run')}</button>
          <button class="btn fileToolbarBtn" title="${_('Copy this script')}" data-bind="enable: selectedScripts().length == 1, click: listCopyScript, visible: scripts().length > 0"><i class="icon-copy"></i> ${_('Copy')}</button>
          <button class="btn fileToolbarBtn" title="${_('Delete this script')}" data-bind="enable: selectedScripts().length > 0, click: listConfirmDeleteScripts, visible: scripts().length > 0"><i class="icon-trash"></i> ${_('Delete')}</button>
      </%def>

      <%def name="creation()">
          <button class="btn fileToolbarBtn" title="${_('Create a new script')}" data-bind="click: confirmNewScript"><i class="icon-plus-sign"></i> ${_('New script')}</button>
      </%def>
    </%actionbar:render>
    <div class="alert alert-info" data-bind="visible: scripts().length == 0">
      ${_('There are currently no scripts defined. Please add a new script clicking on "New script"')}
    </div>

    <table class="table table-striped table-condensed tablescroller-disable" data-bind="visible: scripts().length > 0">
      <thead>
      <tr>
        <th width="1%"><div data-bind="click: selectAll, css: {hueCheckbox: true, 'icon-ok': allSelected}"></div></th>
        <th width="20%">${_('Name')}</th>
        <th width="79%">${_('Script')}</th>
      </tr>
      </thead>
      <tbody id="scriptTable" data-bind="template: {name: 'scriptTemplate', foreach: filteredScripts}">

      </tbody>
      <tfoot>
      <tr data-bind="visible: isLoading()">
        <td colspan="3" class="left">
          <img src="/static/art/spinner.gif" />
        </td>
      </tr>
      <tr data-bind="visible: filteredScripts().length == 0 && !isLoading()">
        <td colspan="3">
          <div class="alert">
              ${_('There are no scripts matching the search criteria.')}
          </div>
        </td>
      </tr>
      </tfoot>
    </table>

    <script id="scriptTemplate" type="text/html">
      <tr style="cursor: pointer" data-bind="event: { mouseover: toggleHover, mouseout: toggleHover}">
        <td class="center" data-bind="click: handleSelect" style="cursor: default">
          <div data-bind="css: {hueCheckbox: true, 'icon-ok': selected}"></div>
        </td>
        <td data-bind="click: $root.confirmViewScript">
          <strong><a href="#" data-bind="click: $root.confirmViewScript, text: name"></a></strong>
        </td>
        <td data-bind="click: $root.confirmViewScript">
          <span data-bind="text: scriptSumup"></span>
        </td>
      </tr>
    </script>
  </div>

  <div id="editor" class="row-fluid mainSection hide">
    <div class="span2">
      <div class="well sidebar-nav">
          <ul class="nav nav-list">
            <li class="nav-header">${_('Editor')}</li>
            <li data-bind="click: editScript" class="active" data-section="edit">
              <a href="#"><i class="icon-edit"></i> ${ _('Script') }</a>
            </li>
            <li data-bind="click: editScriptProperties" data-section="properties">
              <a href="#"><i class="icon-reorder"></i> ${ _('Properties') }</a>
            </li>
            <li data-bind="click: saveScript">
              <a href="#" title="${ _('Save the script') }" rel="tooltip" data-placement="right">
                <i class="icon-save"></i> ${ _('Save') }
              </a>
            </li>
            ##<li class="nav-header">${_('UDF')}</li>
            ##<li><a href="#createDataset">${ _('Python') }</a></li>
            ##<li><a href="#createDataset">${ _('Ruby') }</a></li>
            <li class="nav-header">${_('Actions')}</li>
            <li data-bind="click: runOrShowSubmissionModal, visible: !currentScript().isRunning()">
              <a href="#" title="${ _('Run the script') }" rel="tooltip" data-placement="right">
                <i class="icon-play"></i> ${ _('Run') }
              </a>
            </li>
            <li data-bind="click: showStopModal, visible: currentScript().isRunning()">
              <a href="#" title="${ _('Stop the script') }" rel="tooltip" data-placement="right" class="disabled">
                <i class="icon-ban-circle"></i> ${ _('Stop') }
              </a>
            </li>
            <li data-bind="visible: currentScript().id() != -1, click: copyScript">
              <a href="#" title="${ _('Copy the script') }" rel="tooltip" data-placement="right">
                <i class="icon-copy"></i> ${ _('Copy') }
              </a>
            </li>
            <li data-bind="visible: currentScript().id() != -1, click: confirmDeleteScript">
              <a href="#" title="${ _('Delete the script') }" rel="tooltip" data-placement="right">
                <i class="icon-trash"></i> ${ _('Delete') }
              </a>
            </li>
            <li data-bind="click: confirmNewScript">
              <a href="#" title="${ _('New script') }" rel="tooltip" data-placement="right">
                <i class="icon-plus-sign"></i> ${ _('New script') }
              </a>
            </li>
            <li class="nav-header">${_('Logs')}</li>
            <li data-bind="click: showScriptLogs" data-section="logs">
              <a href="#" title="${ _('Show Logs') }" rel="tooltip" data-placement="right">
                <i class="icon-tasks"></i> ${ _('Current Logs') }
              </a>
            </li>
            <li>
            <br/>
            <i class="icon-question-sign" id="help"></i>
            <div id="help-content" class="hide">
              <ul style="text-align: left;">
                <li>${ _("Press CTRL + Space to autocomplete") }</li>
                <li>${ _("You can execute the current script by pressing CTRL + ENTER or CTRL + . in the editor") }</li>
              </ul>
            </div>
            </li>
          </ul>
      </div>
    </div>

    <div class="span10">
      <div class="ribbon-wrapper" data-bind="visible: isDirty">
        <div class="ribbon">${ _('Unsaved') }</div>
      </div>

      <div id="edit" class="section">
        <div class="alert alert-info">
          <a class="mainAction" href="#" title="${ _('Run this script') }" data-bind="click: runOrShowSubmissionModal, visible: !currentScript().isRunning()"><i class="icon-play"></i></a>
          <a class="mainAction" href="#" title="${ _('Stop this script') }" data-bind="click: showStopModal, visible: currentScript().isRunning()"><i class="icon-stop"></i></a>
          <h3><span data-bind="text: currentScript().name"></span></h3>
        </div>
        <form id="queryForm">
          <textarea id="scriptEditor" data-bind="text:currentScript().script"></textarea>
        </form>
      </div>

      <div id="properties" class="section hide">
        <div class="alert alert-info">
          <a class="mainAction" href="#" title="${ _('Run this script') }" data-bind="click: runOrShowSubmissionModal, visible: !currentScript().isRunning()"><i class="icon-play"></i></a>
          <a class="mainAction" href="#" title="${ _('Stop this script') }" data-bind="click: showStopModal, visible: currentScript().isRunning()"><i class="icon-stop"></i></a>
          <h3><span data-bind="text: currentScript().name"></span></h3>
        </div>
        <form class="form-inline" style="padding-left: 10px">
          <label>
            ${ _('Script name') } &nbsp;
            <input type="text" id="scriptName" class="input-xlarge" data-bind="value: currentScript().name, valueUpdate:'afterkeydown'" />
          </label>

          <br/>
          <br/>

          <h4>${ _('Parameters') } &nbsp; <i id="parameters-dyk" class="icon-question-sign"></i></h4>
          <div id="parameters-dyk-content" class="hide">
            <ul style="text-align: left;">
              <li>input /user/data</li>
              <li>-param input=/user/data</li>
              <li>-optimizer_off SplitFilter</li>
              <li>-verbose</li>
            </ul>
          </div>
          <div class="parameterTableCnt">
            <table class="parameterTable" data-bind="visible: currentScript().parameters().length == 0">
              <tr>
                <td>
                  ${ _('There are currently no defined parameters.') }
                  <button class="btn" data-bind="click: currentScript().addParameter" style="margin-left: 4px">
                    <i class="icon-plus"></i> ${ _('Add') }
                  </button>
                </td>
              </tr>
            </table>
            <table data-bind="css: {'parameterTable': currentScript().parameters().length > 0}">
              <thead data-bind="visible: currentScript().parameters().length > 0">
                <tr>
                  <th>${ _('Name') }</th>
                  <th>${ _('Value') }</th>
                  <th>&nbsp;</th>
                </tr>
              </thead>
              <tbody data-bind="foreach: currentScript().parameters">
                <tr>
                  <td><input type="text" data-bind="value: name" class="input-xlarge" /></td>
                  <td>
                    <div class="input-append">
                      <input type="text" data-bind="value: value" class="input-xxlarge" />
                      <button class="btn fileChooserBtn" data-bind="click: $root.showFileChooser">..</button>
                    </div>
                  </td>
                  <td><button data-bind="click: viewModel.currentScript().removeParameter" class="btn"><i class="icon-trash"></i> ${ _('Remove') }</button></td>
                </tr>
              </tbody>
              <tfoot data-bind="visible: currentScript().parameters().length > 0">
                <tr>
                  <td colspan="3">
                    <button class="btn" data-bind="click: currentScript().addParameter"><i class="icon-plus"></i> ${ _('Add') }</button>
                  </td>
                </tr>
              </tfoot>
            </table>
          </div>

          <br/>
          <h4>${ _('Hadoop properties') } &nbsp; <i id="properties-dyk" class="icon-question-sign"></i></h4>
          <div id="properties-dyk-content" class="hide">
            <ul style="text-align: left; word-wrap:break-word">
              <li>mapred.job.queue.name production</li>
              <li>mapred.map.tasks.speculative.execution false</li>
            </ul>
          </div>
          <div class="parameterTableCnt">
            <table class="parameterTable" data-bind="visible: currentScript().hadoopProperties().length == 0">
              <tr>
                <td>
                  ${ _('There are currently no defined Hadoop properties.') }
                  <button class="btn" data-bind="click: currentScript().addHadoopProperties" style="margin-left: 4px">
                    <i class="icon-plus"></i> ${ _('Add') }
                  </button>
                </td>
              </tr>
            </table>
            <table data-bind="css: {'parameterTable': currentScript().hadoopProperties().length > 0}">
              <thead data-bind="visible: currentScript().hadoopProperties().length > 0">
                <tr>
                  <th>${ _('Name') }</th>
                  <th>${ _('Value') }</th>
                  <th>&nbsp;</th>
                </tr>
              </thead>
              <tbody data-bind="foreach: currentScript().hadoopProperties">
                <tr>
                  <td><input type="text" data-bind="value: name" class="input-xlarge" /></td>
                  <td>
                    <div class="input-append">
                      <input type="text" data-bind="value: value" class="input-xxlarge" />
                      <button class="btn fileChooserBtn" data-bind="click: $root.showFileChooser">..</button>
                    </div>
                  </td>
                  <td><button data-bind="click: viewModel.currentScript().removeHadoopProperties" class="btn"><i class="icon-trash"></i> ${ _('Remove') }</button></td>
                </tr>
              </tbody>
              <tfoot data-bind="visible: currentScript().hadoopProperties().length > 0">
                <tr>
                  <td colspan="3">
                    <button class="btn" data-bind="click: currentScript().addHadoopProperties"><i class="icon-plus"></i> ${ _('Add') }</button>
                  </td>
                </tr>
              </tfoot>
            </table>
          </div>

          <br/>

          <h4>${ _('Resources') } &nbsp; <i id="resources-dyk" class="icon-question-sign"></i></h4>
          <div id="resources-dyk-content" class="hide">
            <ul style="text-align: left;">
              <li>${ _("Path to a HDFS file or zip file to add to the workspace of the running script") }</li>
            </ul>
          </div>
          <div class="parameterTableCnt">
            <table class="parameterTable" data-bind="visible: currentScript().resources().length == 0">
              <tr>
                <td>
                  ${ _('There are currently no defined resources.') }
                  <button class="btn" data-bind="click: currentScript().addResource" style="margin-left: 4px">
                    <i class="icon-plus"></i> ${ _('Add') }
                  </button>
                </td>
              </tr>
            </table>
            <table data-bind="css: {'parameterTable': currentScript().resources().length > 0}">
              <thead data-bind="visible: currentScript().resources().length > 0">
                <tr>
                  <th>${ _('Type') }</th>
                  <th>${ _('Value') }</th>
                  <th>&nbsp;</th>
                </tr>
              </thead>
              <tbody data-bind="foreach: currentScript().resources">
                <tr>
                  <td>
                    <select type="text" data-bind="value: type" class="input-xlarge">
                      ##<option value="udf">${ _('UDF') }</option>
                      <option value="file">${ _('File') }</option>
                      <option value="archive">${ _('Archive') }</option>
                    </select>
                  </td>
                  <td>
                    <div class="input-append">
                      <input type="text" data-bind="value: value" class="input-xxlarge" />
                      <button class="btn fileChooserBtn" data-bind="click: $root.showFileChooser">..</button>
                    </div>
                  </td>
                  <td>
                    <button data-bind="click: viewModel.currentScript().removeResource" class="btn">
                    <i class="icon-trash"></i> ${ _('Remove') }</button>
                  </td>
                </tr>
              </tbody>
              <tfoot data-bind="visible: currentScript().resources().length > 0">
                <tr>
                  <td colspan="3">
                    <button class="btn" data-bind="click: currentScript().addResource"><i class="icon-plus"></i> ${ _('Add') }</button>
                  </td>
                </tr>
              </tfoot>
            </table>
          </div>
        </form>
      </div>

      <div id="logs" class="section hide">
          <div class="alert alert-info"><h3><span data-bind="text: currentScript().name"></span></h3></div>
          <div data-bind="template: {name: 'logTemplate', foreach: currentScript().actions}"></div>
          <script id="logTemplate" type="text/html">
            <div data-bind="css:{'alert-modified': name != '', 'alert': name != '', 'alert-success': status == 'SUCCEEDED' || status == 'OK', 'alert-error': status != 'RUNNING' && status != 'SUCCEEDED' && status != 'OK' && status != 'PREP' && status != 'SUSPENDED'}">
              <div class="pull-right">
                  ${ _('Status:') } <a data-bind="text: status, visible: absoluteUrl != '', attr: {'href': absoluteUrl}" target="_blank"/> <i class="icon-share-alt"></i>
              </div>
              <h4>${ _('Progress:') } <span data-bind="text: progress"></span>${ _('%') }</h4>
              <div data-bind="css: {'progress': name != '', 'progress-striped': name != '', 'active': status == 'RUNNING'}" style="margin-top:10px">
                <div data-bind="css: {'bar': name != '', 'bar-success': status == 'SUCCEEDED' || status == 'OK', 'bar-warning': status == 'RUNNING' || status == 'PREP', 'bar-danger': status != 'RUNNING' && status != 'SUCCEEDED' && status != 'OK' && status != 'PREP' && status != 'SUSPENDED'}, attr: {'style': 'width:' + progressPercent}"></div>
              </div>
            </div>
          </script>
          <pre id="withoutLogs">${ _('No available logs.') } <img src="/static/art/spinner.gif"/></pre>
          <pre id="withLogs" class="hide scroll"></pre>
        </div>

      </div>
  </div>

  <div id="dashboard" class="row-fluid mainSection hide">

    <div class="widget-box">
      <div class="widget-title">
        <span class="icon">
          <i class="icon-cogs"></i>
        </span>
        <h5>${ _('Running') }</h5>
      </div>
      <div class="widget-content">
        <div class="alert alert-info" data-bind="visible: runningScripts().length == 0" style="margin-bottom:0">
          ${_('There are currently no running scripts.')}
        </div>
        <table class="table table-striped table-condensed datatables tablescroller-disable" data-bind="visible: runningScripts().length > 0">
          <thead>
          <tr>
            <th width="20%">${_('Name')}</th>
            <th width="40%">${_('Progress')}</th>
            <th>${_('Created on')}</th>
            <th width="30">&nbsp;</th>
          </tr>
          </thead>
          <tbody data-bind="template: {name: 'runningTemplate', foreach: runningScripts}">

          </tbody>
        </table>
      </div>
    </div>

    <div class="widget-box">
      <div class="widget-title">
        <span class="icon">
          <i class="icon-th-list"></i>
        </span>
        <h5>${ _('Completed') }</h5>
      </div>
      <div class="widget-content">
        <div class="alert alert-info" data-bind="visible: completedScripts().length == 0">
          ${_('There are currently no completed scripts.')}
        </div>
        <table class="table table-striped table-condensed datatables tablescroller-disable" data-bind="visible: completedScripts().length > 0">
          <thead>
          <tr>
            <th width="20%">${_('Name')}</th>
            <th width="40%">${_('Status')}</th>
            <th>${_('Created on')}</th>
          </tr>
          </thead>
          <tbody data-bind="template: {name: 'completedTemplate', foreach: completedScripts}">

          </tbody>
        </table>
      </div>
    </div>

    <script id="runningTemplate" type="text/html">
      <tr style="cursor: pointer">
        <td data-bind="click: $root.viewSubmittedScript" title="${_('Click to edit')}">
          <strong><a data-bind="text: appName"></a></strong>
        </td>
        <td>
          <div data-bind="css: {'progress': appName != '', 'progress-striped': appName != '', 'active': status == 'RUNNING'}">
            <div data-bind="css: {'bar': appName != '', 'bar-success': status == 'SUCCEEDED' || status == 'OK', 'bar-warning': status == 'RUNNING' || status == 'PREP' || status == 'SUSPENDED', 'bar-danger': status != 'RUNNING' && status != 'SUCCEEDED' && status != 'OK' && status != 'PREP' && status != 'SUSPENDED'}, attr: {'style': 'width:' + progressPercent}"></div>
          </div>
        </td>
        <td data-bind="text: created"></td>
        <td data-bind="click: $root.showLogs"><i class="icon-tasks"></i></td>
      </tr>
    </script>

    <script id="completedTemplate" type="text/html">
      <tr style="cursor: pointer" data-bind="click: $root.viewSubmittedScript" title="${_('Click to view')}">
        <td>
          <strong><a data-bind="text: appName"></a></strong>
        </td>
        <td>
          <span data-bind="attr: {'class': statusClass}, text: status"></span>
        </td>
        <td data-bind="text: created"></td>
      </tr>
    </script>
  </div>
</div>


<div id="deleteModal" class="modal hide fade">
  <div class="modal-header">
    <a href="#" class="close" data-dismiss="modal">&times;</a>
    <h3>${_('Confirm Delete')}</h3>
  </div>
  <div class="modal-body">
    <p class="deleteMsg hide single">${_('Are you sure you want to delete this script?')}</p>
    <p class="deleteMsg hide multiple">${_('Are you sure you want to delete these scripts?')}</p>
  </div>
  <div class="modal-footer">
    <a class="btn" data-dismiss="modal">${_('No')}</a>
    <a class="btn btn-danger" data-bind="click: deleteScripts">${_('Yes')}</a>
  </div>
</div>

<div id="logsModal" class="modal hide fade">
  <div class="modal-header">
    <a href="#" class="close" data-dismiss="modal">&times;</a>
    <h3>${_('Logs')}</h3>
  </div>
  <div class="modal-body">
    <img src="/static/art/spinner.gif" class="hide" />
    <pre class="scroll hide"></pre>
  </div>
  <div class="modal-footer">
    <a class="btn" data-dismiss="modal">${_('Close')}</a>
  </div>
</div>

<div id="submitModal" class="modal hide fade">
  <div class="modal-header">
    <a href="#" class="close" data-dismiss="modal">&times;</a>
    <h3>${_('Run Script')} '<span data-bind="text: currentScript().name"></span>' ${_('?')}</h3>
  </div>
  <div class="modal-body" data-bind="visible: submissionVariables().length > 0">
    <legend style="color:#666">${_('Script variables')}</legend>
    <div data-bind="foreach: submissionVariables" style="margin-bottom: 20px">
      <div class="row-fluid">
        <span data-bind="text: name" class="span3"></span>
        <input type="text" data-bind="value: value" class="span9" />
      </div>
    </div>
  </div>
  <div class="modal-footer">
    <a class="btn" data-dismiss="modal">${_('No')}</a>
    <a id="runScriptBtn" class="btn btn-danger disable-feedback" data-bind="click: runScript">${_('Yes')}</a>
  </div>
</div>

<div id="stopModal" class="modal hide fade">
  <div class="modal-header">
    <a href="#" class="close" data-dismiss="modal">&times;</a>
    <h3>${_('Stop Script')} '<span data-bind="text: currentScript().name"></span>' ${_('?')}</h3>
  </div>
  <div class="modal-footer">
    <a class="btn" data-dismiss="modal">${_('No')}</a>
    <a id="stopScriptBtn" class="btn btn-danger disable-feedback" data-bind="click: stopScript">${_('Yes')}</a>
  </div>
</div>

<div id="chooseFile" class="modal hide fade">
    <div class="modal-header">
        <a href="#" class="close" data-dismiss="modal">&times;</a>
        <h3>${_('Choose a file')}</h3>
    </div>
    <div class="modal-body">
        <div id="filechooser">
        </div>
    </div>
    <div class="modal-footer">
    </div>
</div>

<div id="confirmModal" class="modal hide fade">
  <div class="modal-header">
    <a href="#" class="close" data-dismiss="modal">&times;</a>
    <h3>${_('Are you sure?')}</h3>
  </div>
  <div class="modal-body">
    <p>
      ${_('The current script has unsaved changes. Are you sure you want to discard the changes?')}
    </p>
  </div>
  <div class="modal-footer">
    <a class="btn" data-dismiss="modal">${_('No')}</a>
    <a class="btn btn-danger disable-feedback" data-bind="click: confirmScript">${_('Yes')}</a>
  </div>
</div>

<div id="nameModal" class="modal hide fade">
  <div class="modal-header">
    <a href="#" class="close" data-dismiss="modal">&times;</a>
    <h3>${_('Save script')}</h3>
  </div>
  <div class="modal-body">
    <p>
      ${_('Please give a meaningful name to this script.')}<br/><br/>
      <label>
        ${ _('Script name') } &nbsp;
        <input type="text" class="input-xlarge" data-bind="value: currentScript().name, valueUpdate:'afterkeydown'" />
      </label>
    </p>
  </div>
  <div class="modal-footer">
    <a class="btn" data-dismiss="modal">${_('Cancel')}</a>
    <button class="btn btn-primary disable-feedback" data-bind="click: saveScript, enable: currentScript().name() != '' && currentScript().name() != $root.LABELS.NEW_SCRIPT_NAME">${_('Save')}</button>
  </div>
</div>


<div class="bottomAlert alert"></div>

<script src="/static/ext/js/knockout-min.js" type="text/javascript" charset="utf-8"></script>
<script src="/pig/static/js/utils.js" type="text/javascript" charset="utf-8"></script>
<script src="/pig/static/js/pig.ko.js" type="text/javascript" charset="utf-8"></script>
<script src="/static/ext/js/routie-0.3.0.min.js" type="text/javascript" charset="utf-8"></script>
<link rel="stylesheet" href="/pig/static/css/pig.css">
<script src="/static/ext/js/codemirror-3.11.js"></script>
<link rel="stylesheet" href="/static/ext/css/codemirror.css">
<script src="/static/ext/js/codemirror-pig.js"></script>
<script src="/static/js/Source/jHue/codemirror-show-hint.js"></script>
<script src="/static/js/Source/jHue/codemirror-pig-hint.js"></script>
<link rel="stylesheet" href="/static/ext/css/codemirror-show-hint.css">

<style>
  .fileChooserBtn {
    border-radius: 0 3px 3px 0;
  }
</style>

<script type="text/javascript" charset="utf-8">
  var LABELS = {
    KILL_ERROR: "${ _('The pig job could not be killed.') }",
    TOOLTIP_PLAY: "${ _('Run this pig script') }",
    TOOLTIP_STOP: "${ _('Stop the execution') }",
    SAVED: "${ _('Saved') }",
    NEW_SCRIPT_NAME: "${ _('Unsaved script') }",
    NEW_SCRIPT_CONTENT: "ie. A = LOAD '/user/${ user }/data';",
    NEW_SCRIPT_PARAMETERS: [],
    NEW_SCRIPT_RESOURCES: [],
    NEW_SCRIPT_HADOOP_PROPERTIES: []
  };

  var appProperties = {
    labels: LABELS,
    listScripts: "${ url('pig:scripts') }",
    saveUrl: "${ url('pig:save') }",
    runUrl: "${ url('pig:run') }",
    stopUrl: "${ url('pig:stop') }",
    copyUrl: "${ url('pig:copy') }",
    deleteUrl: "${ url('pig:delete') }"
  }

  var viewModel = new PigViewModel(appProperties);
  ko.applyBindings(viewModel);

  $(document).ready(function () {
    viewModel.updateScripts();

    var USER_HOME = "/user/${ user }/";

    var scriptEditor = $("#scriptEditor")[0];

    var logsAtEnd = true;
    var forceLogsAtEnd = false;

    function storeVariables() {
      CodeMirror.availableVariables = [];
      var _val = codeMirror.getValue();
      var _groups = _val.replace(/==/gi, "").split("=");
      $.each(_groups, function (cnt, item) {
        if (cnt < _groups.length - 1) {
          var _blocks = $.trim(item).replace(/\n/gi, " ").split(" ");
          CodeMirror.availableVariables.push(_blocks[_blocks.length - 1]);
        }
        if (item.toLowerCase().indexOf("split") > -1 && item.toLowerCase().indexOf("into") > -1) {
          try {
            var _split = item.substring(item.toLowerCase().indexOf("into"));
            var _possibleVariables = $.trim(_split.substring(4, _split.indexOf(";"))).split(",");
            $.each(_possibleVariables, function (icnt, iitem) {
              if (iitem.toLowerCase().indexOf("if") > -1) {
                CodeMirror.availableVariables.push($.trim(iitem).split(" ")[0]);
              }
            });
          }
          catch (e) {
          }
        }
      });
    }

    CodeMirror.commands.autocomplete = function (cm) {
      storeVariables();
      var _line = codeMirror.getLine(codeMirror.getCursor().line);
      var _partial = _line.substring(0, codeMirror.getCursor().ch);
      if (_partial.indexOf("'") > -1 && _partial.indexOf("'") == _partial.lastIndexOf("'") && (_partial.toLowerCase().indexOf("load") > -1
          || _partial.toLowerCase().indexOf("into") > -1)) {
        var _path = _partial.substring(_partial.lastIndexOf("'") + 1);
        var _autocompleteUrl = "/filebrowser/view";
        if (_path.indexOf("/") == 0) {
          _autocompleteUrl += _path.substr(0, _path.lastIndexOf("/"));
        }
        else if (_path.indexOf("/") > 0) {
          _autocompleteUrl += USER_HOME + _path.substr(0, _path.lastIndexOf("/"));
        }
        else {
          _autocompleteUrl += USER_HOME;
        }
        showHdfsAutocomplete(_autocompleteUrl + "?format=json");
      }
      else {
        CodeMirror.isPath = false;
        CodeMirror.showHint(cm, CodeMirror.pigHint);
      }
    }
    var codeMirror = CodeMirror(function (elt) {
      scriptEditor.parentNode.replaceChild(elt, scriptEditor);
    }, {
      value: scriptEditor.value,
      readOnly: false,
      lineNumbers: true,
      mode: "text/x-pig",
      extraKeys: {
        "Ctrl-Space": "autocomplete",
        "Ctrl-Enter": function () {
          if (!viewModel.currentScript().isRunning()) {
            viewModel.runOrShowSubmissionModal();
          }
        },
        "Ctrl-.": function () {
          if (!viewModel.currentScript().isRunning()) {
            viewModel.runOrShowSubmissionModal();
          }
        }
      },
      onKeyEvent: function (e, s) {
        if (s.type == "keyup") {
          if (s.keyCode == 191) {
            var _line = codeMirror.getLine(codeMirror.getCursor().line);
            var _partial = _line.substring(0, codeMirror.getCursor().ch);
            var _path = _partial.substring(_partial.lastIndexOf("'") + 1);
            if (_path[0] == "/") {
              if (_path.lastIndexOf("/") != 0) {
                showHdfsAutocomplete("/filebrowser/view" + _partial.substring(_partial.lastIndexOf("'") + 1) + "?format=json");
              }
            }
            else {
              showHdfsAutocomplete("/filebrowser/view" + USER_HOME + _partial.substring(_partial.lastIndexOf("'") + 1) + "?format=json");
            }
          }
        }
      }
    });

    function showHdfsAutocomplete(path) {
      $.getJSON(path, function (data) {
        CodeMirror.currentFiles = [];
        if (data.error != null) {
          $.jHueNotify.error(data.error);
        }
        else {
          $(data.files).each(function (cnt, item) {
            if (item.name != ".") {
              var _ico = "icon-file-alt";
              if (item.type == "dir") {
                _ico = "icon-folder-close";
              }
              CodeMirror.currentFiles.push('<i class="' + _ico + '"></i> ' + item.name);
            }
          });
          CodeMirror.isPath = true;
          window.setTimeout(function () {
            CodeMirror.showHint(codeMirror, CodeMirror.pigHint);
          }, 100);  // timeout for IE8
        }
      });
    }

    codeMirror.on("focus", function () {
      if (codeMirror.getValue() == LABELS.NEW_SCRIPT_CONTENT) {
        codeMirror.setValue("");
      }
    });

    codeMirror.on("change", function () {
      if (viewModel.currentScript().script() != codeMirror.getValue()) {
        viewModel.currentScript().script(codeMirror.getValue());
        viewModel.isDirty(true);
      }
    });

    showMainSection("editor");

    $(document).on("loadEditor", function () {
      codeMirror.setValue(viewModel.currentScript().script());
    });

    $(document).on("showEditor", function () {
      if (viewModel.currentScript().id() != -1) {
        routie("edit/" + viewModel.currentScript().id());
      }
      else {
        routie("edit");
      }
    });

    $(document).on("showProperties", function () {
      if (viewModel.currentScript().id() != -1) {
        routie("properties/" + viewModel.currentScript().id());
      }
      else {
        routie("properties");
      }
    });

    $(document).on("showLogs", function () {
      if (viewModel.currentScript().id() != -1) {
        routie("logs/" + viewModel.currentScript().id());
      }
      else {
        routie("logs");
      }
    });

    $(document).on("updateTooltips", function () {
      $("a[rel=tooltip]").tooltip("destroy");
      $("a[rel=tooltip]").tooltip();
    });

    $(document).on("saving", function () {
      showAlert("${_('Saving')} <b>" + viewModel.currentScript().name() + "</b>...");
    });

    $(document).on("running", function () {
      $("#runScriptBtn").button("loading");
      $("#withoutLogs").removeClass("hide");
      $("#withLogs").addClass("hide").text("");
      showAlert("${_('Running')} <b>" + viewModel.currentScript().name() + "</b>...", "info");
    });

    $(document).on("saved", function () {
      showAlert("<b>" + viewModel.currentScript().name() + "</b> ${_('has been saved correctly.')}", "success");
    });

    $(document).on("error", function () {
      showAlert("<b>${_('There was an error with your request!')}</b>", "error");
    });

    $(document).on("refreshDashboard", function () {
      refreshDashboard();
    });

    $(document).on("showDashboard", function () {
      routie("dashboard");
    });

    $(document).on("showScripts", function () {
      routie("scripts");
    });

    $(document).on("scriptsRefreshed", function () {
      $("#filter").val("");
    });

    var logsRefreshInterval;
    $(document).on("startLogsRefresh", function () {
      logsAtEnd = true;
      window.clearInterval(logsRefreshInterval);
      $("#withLogs").text("");
      refreshLogs();
      logsRefreshInterval = window.setInterval(function () {
        refreshLogs();
      }, 1000);
    });

    $(document).on("stopLogsRefresh", function () {
      window.clearInterval(logsRefreshInterval);
    });

    $(document).on("clearLogs", function () {
      $("#withoutLogs").removeClass("hide");
      $("#withLogs").text("").addClass("hide");
      logsAtEnd = true;
      forceLogsAtEnd = true;
    });

    var _resizeTimeout = -1;
    $(window).on("resize", function () {
      window.clearTimeout(_resizeTimeout);
      _resizeTimeout = window.setTimeout(function () {
        codeMirror.setSize("100%", $(window).height() - 190);
      }, 100);
    });

    var _filterTimeout = -1;
    $("#filter").on("keyup", function () {
      window.clearTimeout(_filterTimeout);
      _filterTimeout = window.setTimeout(function () {
        viewModel.filterScripts($("#filter").val());
      }, 350);
    });

    viewModel.filterScripts("");

    refreshDashboard();

    var dashboardRefreshInterval = window.setInterval(function () {
      if (viewModel.runningScripts().length > 0) {
        refreshDashboard();
      }
    }, 3000);

    function refreshDashboard() {
      $.getJSON("${ url('pig:dashboard') }", function (data) {
        viewModel.updateDashboard(data);
      });
    }

    function refreshLogs() {
      if (viewModel.currentScript().watchUrl() != "") {
        $.getJSON(viewModel.currentScript().watchUrl(), function (data) {
          if (data.logs.pig) {
            if ($("#withLogs").is(":hidden")) {
              $("#withoutLogs").addClass("hide");
              $("#withLogs").removeClass("hide");
              resizeLogs();
            }
            var _logsEl = $("#withLogs");
            var newLines = data.logs.pig.split("\n").slice(_logsEl.html().split("<br>").length);
            if (newLines.length > 0){
              _logsEl.html(_logsEl.html() + newLines.join("<br>") + "<br>");
            }
            window.setTimeout(function () {
              resizeLogs();
              if (logsAtEnd || forceLogsAtEnd) {
                _logsEl.scrollTop(_logsEl[0].scrollHeight - _logsEl.height());
                forceLogsAtEnd = false;
              }
            }, 100);
          }
          if (data.workflow && data.workflow.isRunning) {
            viewModel.currentScript().actions(data.workflow.actions);
          }
          else {
            viewModel.currentScript().actions(data.workflow.actions);
            viewModel.currentScript().isRunning(false);
            $(document).trigger("stopLogsRefresh");
          }
        });
      }
      else {
        $(document).trigger("stopLogsRefresh");
      }
    }

    $("#withLogs").scroll(function () {
      logsAtEnd = $(this).scrollTop() + $(this).height() + 20 >= $(this)[0].scrollHeight;
    });

    function resizeLogs() {
      $("#withLogs").css("overflow", "auto").height($(window).height() - $("#withLogs").offset().top - 50);
    }

    $(window).resize(function () {
      resizeLogs();
    });

    function showMainSection(mainSection, includeGA) {
      window.setTimeout(function () {
        codeMirror.refresh();
        codeMirror.setSize("100%", $(window).height() - 190);
      }, 100);

      if ($("#" + mainSection).is(":hidden")) {
        $(".mainSection").hide();
        $("#" + mainSection).show();
        highlightMainMenu(mainSection);
      }
      if (typeof trackOnGA == 'function' && includeGA == undefined){
        trackOnGA(mainSection);
      }
    }

    function showSection(mainSection, section) {
      showMainSection(mainSection, false);
      if ($("#" + section).is(":hidden")) {
        $(".section").hide();
        $("#" + section).show();
        highlightMenu(section);
      }

      if (typeof trackOnGA == 'function'){
        trackOnGA(mainSection + "/" + section);
      }
    }

    function highlightMainMenu(mainSection) {
      $(".nav-pills li").removeClass("active");
      $("a[href='#" + mainSection + "']").parent().addClass("active");
    }

    function highlightMenu(section) {
      $(".nav-list li").removeClass("active");
      $("li[data-section='" + section + "']").addClass("active");
    }

    var dashboardLoadedInterval = -1;

    routie({
      "editor": function () {
        showMainSection("editor");
      },
      "scripts": function () {
        showMainSection("scripts");
      },
      "dashboard": function () {
        showMainSection("dashboard");
      },

      "edit": function () {
        showSection("editor", "edit");
      },
      "edit/:scriptId": function (scriptId) {
        if (scriptId !== "undefined" && scriptId != viewModel.currentScript().id()) {
          dashboardLoadedInterval = window.setInterval(function () {
            if (viewModel.isDashboardLoaded) {
              window.clearInterval(dashboardLoadedInterval);
              viewModel.loadScript(scriptId);
              if (viewModel.currentScript().id() == -1) {
                viewModel.confirmNewScript();
              }
              $(document).trigger("loadEditor");
            }
          }, 200);
        }
        showSection("editor", "edit");
      },
      "properties": function () {
        showSection("editor", "properties");
      },
      "properties/:scriptId": function (scriptId) {
        if (scriptId !== "undefined" && scriptId != viewModel.currentScript().id()) {
          dashboardLoadedInterval = window.setInterval(function () {
            if (viewModel.isDashboardLoaded) {
              window.clearInterval(dashboardLoadedInterval);
              viewModel.loadScript(scriptId);
              if (viewModel.currentScript().id() == -1) {
                viewModel.confirmNewScript();
              }
              $(document).trigger("loadEditor");
            }
          }, 200);
        }
        showSection("editor", "properties");
      },
      "logs": function () {
        showSection("editor", "logs");
      },
      "logs/:scriptId": function (scriptId) {
        if (scriptId !== "undefined" && scriptId != viewModel.currentScript().id()) {
          dashboardLoadedInterval = window.setInterval(function () {
            if (viewModel.isDashboardLoaded) {
              window.clearInterval(dashboardLoadedInterval);
              viewModel.loadScript(scriptId);
              $(document).trigger("loadEditor");
              if (viewModel.currentScript().id() == -1) {
                viewModel.confirmNewScript();
              }
              else {
                viewModel.currentScript().isRunning(true);
                var _foundLastRun = null;
                $.each(viewModel.completedScripts(), function (cnt, pastScript) {
                  if (pastScript.scriptId == scriptId && _foundLastRun == null) {
                    _foundLastRun = pastScript;
                  }
                });
                viewModel.currentScript().watchUrl(_foundLastRun.watchUrl);
                $(document).trigger("startLogsRefresh");
                showSection("editor", "logs");
              }
            }
          }, 200)
        }
        showSection("editor", "logs");
      }
    });

    $("#help").popover({
      'title': "${_('Did you know?')}",
      'content': $("#help-content").html(),
      'trigger': 'hover',
      'html': true
    });

    $("#parameters-dyk").popover({
      'title': "${_('Names and values of Pig parameters and options, e.g.')}",
      'content': $("#parameters-dyk-content").html(),
      'trigger': 'hover',
      'html': true
    });

    $("#properties-dyk").popover({
      'title': "${_('Names and values of Hadoop properties, e.g.')}",
      'content': $("#properties-dyk-content").html(),
      'trigger': 'hover',
      'html': true
    });

    $("#resources-dyk").popover({
      'title': "${_('Include files or compressed files')}",
      'content': $("#resources-dyk-content").html(),
      'trigger': 'hover',
      'html': true
    });
  });

  window.onbeforeunload = function (e) {
    if (viewModel.isDirty()) {
      var message = "${ _('You have unsaved changes in this pig script.') }";

      if (!e) e = window.event;
      e.cancelBubble = true;
      e.returnValue = message;

      if (e.stopPropagation) {
        e.stopPropagation();
        e.preventDefault();
      }
      return message;
    }
  };

  var _bottomAlertFade = -1;
  function showAlert(msg, extraClass) {
    var klass = "alert ";
    if (extraClass != null && extraClass != undefined) {
      klass += "alert-" + extraClass;
    }
    $(".bottomAlert").attr("class", "bottomAlert " + klass).html(msg).show();
    window.clearTimeout(_bottomAlertFade);
    _bottomAlertFade = window.setTimeout(function () {
      $(".bottomAlert").fadeOut();
    }, 3000);
  }
</script>

${ commonfooter(messages) | n,unicode }
