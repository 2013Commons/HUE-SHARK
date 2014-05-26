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

<%namespace name="layout" file="../navigation-bar.mako" />
<%namespace name="utils" file="../utils.inc.mako" />
<%namespace name="actions" file="action_utils.mako" />
<%namespace name="controls" file="control_utils.mako" />
<%namespace name="workflows" file="workflow_utils.mako" />

${ commonheader(_("Edit Workflow"), "oozie", user, "100px") | n,unicode }
${ layout.menubar(section='workflows') }


<div id="workflow" class="container-fluid">
  <form class="form-horizontal" id="jobForm" method="POST">
  <div class="ribbon-wrapper hide">
    <div class="ribbon">${ _('Unsaved') }</div>
  </div>

  <h1 data-bind="text: '${ _('Workflow Editor : ') } ' + name()"></h1>

  <div class="row-fluid">
  <div class="span2">
    <div id="workflowControls" class="well sidebar-nav">
      <ul class="nav nav-list">
        <li class="nav-header">${ _('Properties') }</li>
        <li><a href="#properties">${ _('Edit properties') }</a></li>

        <li class="nav-header">${ _('Editor') }</li>
        <li><a href="#editWorkflow">${ _('Edit workflow') }</a></li>
        <li><a href="#importAction" title="${ _('Click to import an Oozie workflow action or Job Designer action') }" rel="tooltip" data-placement="right">${ _('Import action') }</a></li>
        % if user_can_edit_job:
          <li>
            <a data-bind="attr: {href: '/filebrowser/view' + deployment_dir() }" target="_blank" title="${ _('Upload additional files and libraries to the deployment directory') }" rel="tooltip" data-placement="right"><i class="icon-share-alt"></i> ${ _('Upload') }</a>
          </li>
        % endif

        % if user_can_edit_job:
          <li class="nav-header">${ _('History') }</li>
          <li><a href="#listHistory">${ _('Show history') }</a></li>
        % endif

        <li class="nav-header">${ _('Actions') }</li>
        % if user_can_access_job:
          <li>
            <a id="submit-btn" href="javascript:void(0)" data-submit-url="${ url('oozie:submit_workflow', workflow=workflow.id) }" title="${ _('Submit this workflow') }" rel="tooltip" data-placement="right"><i class="icon-play"></i> ${ _('Submit') }</a>
          </li>
          <li>
            <a href="${ url('oozie:schedule_workflow', workflow=workflow.id) }" title="${ _('Schedule this workflow') }" rel="tooltip" data-placement="right"><i class="icon-calendar"></i> ${ _('Schedule') }</a>
          </li>
          <li>
            <a id="clone-btn" href="#" data-clone-url="${ url('oozie:clone_workflow', workflow=workflow.id) }" title="${ _('Copy this workflow') }" rel="tooltip" data-placement="right"><i class="icon-copy"></i> ${ _('Copy') }</a>
          </li>
        % endif
      </ul>
    </div>
  </div>
  <div class="span10">
    <div id="properties" class="section hide">
      <div class="alert alert-info"><h3>${ _('Properties') }</h3></div>
      <fieldset>
        ${ utils.render_field(workflow_form['name'], extra_attrs={'data-bind': 'value: %s' % workflow_form['name'].name}) }
        ${ utils.render_field(workflow_form['description'], extra_attrs={'data-bind': 'value: %s' % workflow_form['description'].name}) }
        ${ utils.render_field(workflow_form['is_shared'], extra_attrs={'data-bind': 'checked: %s' % workflow_form['is_shared'].name}) }

      <%
      workflows.key_value_field(workflow_form['parameters'], {
      'name': 'parameters',
      'remove': '$root.removeParameter',
      'add': '$root.addParameter',
      })
      %>

      <%
      workflows.key_value_field(workflow_form['job_properties'], {
      'name': 'job_properties',
      'remove': '$root.removeJobProperty',
      'add': '$root.addJobProperty',
      })
      %>

        <div class="control-group ">
          <label class="control-label">
            <a href="#" id="advanced-btn" onclick="$('#advanced-container').toggle('hide')">
              <i class="icon-share-alt"></i> ${ _('advanced') }</a>
          </label>
          <div class="controls"></div>
        </div>

      <div id="advanced-container" class="hide">
        % if user_can_edit_job:
          ${ utils.render_field(workflow_form['deployment_dir'], extra_attrs={'data-bind': 'value: %s' % workflow_form['deployment_dir'].name}) }
        % endif

        ${ utils.render_field(workflow_form['job_xml'], extra_attrs={'data-bind': 'value: %s' % workflow_form['job_xml'].name}) }
      </div>

      </fieldset>
    </div>

    <div id="importAction" class="section hide">
      <ul class="nav nav-tabs">
        <li class="active"><a href="#importJobsub" data-toggle="tab">${ _('Job Designer') }</a></li>
        <li><a href="#importOozie" data-toggle="tab">${ _('Oozie') }</a></li>
      </ul>

      <div class="tab-content">
        <div class="tab-pane active" id="importJobsub" data-bind="with: jobsub">
          <div class="alert alert-info">
            <h3>${ _('Import Action from Job Designer') }</h3>
            <p>${_('Click on a row to import the design as an action in the workflow. The action will be added to the beginning of the flow.')}</p>
          </div>
          <table id="jobsubActionsTable" class="table">
            <thead>
              <tr>
                <th>${ _('Name') }</th>
                <th>${ _('Description') }</th>
              </tr>
            </thead>
            <tbody data-bind="visible: workflows().length > 0, foreach: workflows">
              <tr class="action-row" rel="tooltip" title="${ _('Click to import action to workflow') }">
                <td>
                  <a href="javascript:void(0);" data-bind="text: $data.name"></a>
                </td>
                <td data-bind="text: $data.description"></td>
              </tr>
            </tbody>
            <tbody data-bind="visible: workflows().length == 0">
              <tr class="action-row">
                <td>${ _('N/A') }</td><td></td><td></td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="tab-pane" id="importOozie" data-bind="with: oozie">
          <div class="alert alert-info"><h3>${ _('Import Action from Oozie') }</h3></div>
          <table id="oozieWorkflowsTable" class="table">
            <thead>
              <tr>
                <th>${ _('Name') }</th>
                <th>${ _('Description') }</th>
              </tr>
            </thead>
            <tbody data-bind="visible: workflows().length > 0, foreach: workflows">
              <tr class="action-row">
                <td>
                  <a href="javascript:void(0);" data-bind="text: $data.name"></a>
                </td>
                <td data-bind="text: $data.description"></td>
              </tr>
            </tbody>
            <tbody data-bind="visible: workflows().length == 0">
              <tr class="action-row">
                <td>${ _('N/A') }</td><td></td><td></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <div id="importOozieAction" class="section hide" data-bind="if: selected_workflow()">
      <div class="alert alert-info">
        <h3>${ _('Import Action from Workflow: ') } <span data-bind="text: selected_workflow().name"></span></h3>
        <p>${_('Click on a row to import the action.')}</p>
      </div>
      <table id="oozieActionsTable" class="table">
        <thead>
          <tr>
            <th>${ _('Name') }</th>
            <th>${ _('Description') }</th>
          </tr>
        </thead>
        <tbody data-bind="visible: nodes().length > 0, foreach: nodes">
          <tr class="action-row" rel="tooltip" title="${ _('Click to import action to workflow') }">
            <td>
              <a href="javascript:void(0);" data-bind="text: $data.name"></a>
            </td>
            <td data-bind="text: $data.description"></td>
          </tr>
        </tbody>
        <tbody data-bind="visible: nodes().length == 0">
          <tr class="action-row">
            <td>${ _('N/A') }</td><td></td><td></td>
          </tr>
        </tbody>
      </table>
    </div>

    <div id="editWorkflow" class="section hide">

      <div class="alert alert-info"><h3>${ _('Editor') }</h3></div>

      <div id="actionToolbar" class="well">
        <div class="draggable-button">
          <a data-node-type="mapreduce"
             title="${ _('Drag and drop this action on the workflow') }" class="btn new-node-link">
            <i class="icon-move"></i> MapReduce
          </a>
        </div>
        <div class="draggable-button">
          <a data-node-type="streaming"
             title="${ _('Drag and drop this action on the workflow') }" class="btn new-node-link">
            <i class="icon-move"></i> Streaming
          </a>
        </div>
        <div class="draggable-button">
          <a data-node-type="java"
             title="${ _('Drag and drop this action on the workflow') }" class="btn new-node-link">
            <i class="icon-move"></i> Java
          </a>
         </div>
        <div class="draggable-button">
          <a data-node-type="pig"
             title="${ _('Drag and drop this action on the workflow') }" class="btn new-node-link">
            <i class="icon-move"></i> Pig
          </a>
        </div>
        <div class="draggable-button">
          <a data-node-type="hive"
             title="${ _('Drag and drop this action on the workflow') }" class="btn new-node-link">
            <i class="icon-move"></i> Hive
          </a>
        </div>
        <div class="draggable-button">
          <a data-node-type="sqoop"
             title="${ _('Drag and drop this action on the workflow') }" class="btn new-node-link">
            <i class="icon-move"></i> Sqoop
          </a>
        </div>
        <div class="draggable-button">
          <a data-node-type="shell"
             title="${ _('Drag and drop this action on the workflow') }" class="btn new-node-link">
            <i class="icon-move"></i> Shell
          </a>
        </div>
        <div class="draggable-button">
          <a data-node-type="ssh"
             title="${ _('Drag and drop this action on the workflow') }" class="btn new-node-link">
            <i class="icon-move"></i> Ssh
          </a>
        </div>
        <div class="draggable-button">
          <a data-node-type="distcp"
             title="${ _('Drag and drop this action on the workflow') }" class="btn new-node-link">
            <i class="icon-move"></i> DistCp
          </a>
        </div>
        <div class="draggable-button">
          <a data-node-type="fs"
             title="${ _('Drag and drop this action on the workflow') }" class="btn new-node-link">
            <i class="icon-move"></i> Fs
          </a>
        </div>
        <div class="draggable-button">
          <a data-node-type="email"
             title="${ _('Drag and drop this action on the workflow') }" class="btn new-node-link">
            <i class="icon-move"></i> Email
          </a>
        </div>
        <div class="draggable-button">
          <a data-node-type="subworkflow"
             title="${ _('Drag and drop this action on the workflow') }" class="btn new-node-link">
            <i class="icon-move"></i> Sub-workflow
          </a>
        </div>
        <div class="draggable-button">
          <a data-node-type="generic"
             title="${ _('Drag and drop this action on the workflow') }" class="btn new-node-link">
            <i class="icon-move"></i> Generic
          </a>
        </div>
      </div>

      <div class="alert" data-bind="visible: nodes().length < 3">
        ${ _('No actions: drag some from the panel above') }
      </div>

      <div id="graph" class="row-fluid" data-bind="template: { name: function(item) { return item.view_template() }, foreach: nodes }"></div>
      <div id="new-node" class="row-fluid" data-bind="template: { name: 'nodeTemplate', 'if': new_node, data: new_node }"></div>

    </div>

    <div id="listHistory" class="section hide">
      <div class="alert alert-info"><h3>${ _('History') }</h3></div>
      % if not history:
        ${ _('N/A') }
      % else:
        <table class="table">
          <thead>
          <tr>
            <th>${ _('Date') }</th>
            <th>${ _('Id') }</th>
          </tr>
          </thead>
          <tbody>
          % for record in history:
          <tr>
            <td>
              <a href="${ url('oozie:list_history_record', record_id=record.id) }" data-row-selector="true"></a>
              ${ utils.format_date(record.submission_date) }
            </td>
            <td>${ record.oozie_job_id }</td>
          </tr>
          % endfor
          </tbody>
        </table>
      % endif
    </div>


  </div>
  </div>

  <div id="formActions" class="form-actions center">
  % if user_can_edit_job:
    <button data-bind="disable: workflow.read_only, visible: !workflow.read_only(), click: function() { workflow.loading(true); workflow.save({ success: workflow_save_success, error: workflow_save_error }) }" class="btn btn-primary" id="btn-save-wf">${ _('Save') }</button>
  % endif
    <a href="${ url('oozie:list_workflows') }" class="btn">${ _('Back') }</a>
  </div>
  </form>
</div>

<div id="node-modal" class="modal hide" data-bind="template: $data.template"></div>

<div id="confirmation" class="modal hide fade">
  <div class="modal-header">
    <a href="#" class="close" data-dismiss="modal">&times;</a>
    <h3 class="message"></h3>
  </div>
  <div class="modal-body">
  </div>
  <div class="modal-footer">
    <a href="#" class="btn" data-dismiss="modal">${_('No')}</a>
    <a class="btn btn-primary" href="javascript:void(0);">${_('Yes')}</a>
  </div>
</div>


<div id="modal-window" class="modal hide fade"></div>

<div id="submit-wf-modal" class="modal hide"></div>


<script src="/static/ext/js/codemirror-3.11.js"></script>
<link rel="stylesheet" href="/static/ext/css/codemirror.css">
<script src="/static/ext/js/codemirror-xml.js"></script>
<script src="/static/ext/js/codemirror-closetag.js"></script>

<script src="/static/ext/js/knockout-min.js" type="text/javascript" charset="utf-8"></script>
<script src="/static/ext/js/knockout.mapping-2.3.2.js" type="text/javascript" charset="utf-8"></script>
<script src="/static/ext/js/jquery/plugins/jquery-ui-draggable-droppable-sortable-1.8.23.min.js" type="text/javascript" charset="utf-8"></script>
<script src="/static/ext/js/routie-0.3.0.min.js" type="text/javascript" charset="utf-8"></script>
<script src="/static/ext/js/datatables-paging-0.1.js" type="text/javascript" charset="utf-8"></script>

<link rel="stylesheet" href="/oozie/static/css/workflow.css">
<script type="text/javascript" src="/oozie/static/js/workflow.utils.js"></script>
<script type="text/javascript" src="/oozie/static/js/workflow.registry.js"></script>
<script type="text/javascript" src="/oozie/static/js/workflow.modal.js"></script>
<script type="text/javascript" src="/oozie/static/js/workflow.models.js"></script>
<script type="text/javascript" src="/oozie/static/js/workflow.idgen.js"></script>
<script type="text/javascript" src="/oozie/static/js/workflow.node-fields.js"></script>
<script type="text/javascript" src="/oozie/static/js/workflow.node.js"></script>
<script type="text/javascript" src="/oozie/static/js/workflow.js"></script>
<script type="text/javascript" src="/oozie/static/js/workflow.import-node.js"></script>


% for form_info in action_forms:
  ${ actions.action_form(action_form=form_info[1], node_type=form_info[0], template=True) }
% endfor

${ controls.fork_convert_form(node_type='fork', template=True, javascript_attrs={'convert': 'function(data, event) { $data.convertToDecision(); $data._workflow.rebuild(); }'}) }
${ controls.fork_edit_form(form=node_form, node_type='fork', template=True) }

${ controls.decision_form(node_form, link_form, default_link_form, 'decision', True) }

<script type="text/html" id="emptyTemplate"></script>

<script type="text/html" id="disabledNodeTemplate">
  <div class="node node-control row-fluid">
    <div class="action span12">
      <div class="row-fluid">
        <div class="span12">
          <h4 data-bind="text: (name()) ? name() : node_type() + '-' + id()"></h4>
          <span data-bind="text: node_type" class="muted"></span>
          <div class="node-description" data-bind="text: description"></div>
        </div>
      </div>

      <div class="row-fluid node-action-bar">
        <div class="span12" style="text-align:right">
          &nbsp;
        </div>
      </div>
    </div>
  </div>

  <!-- ko if: links -->
    <div class="row-fluid" data-bind="template: { name: 'linkTemplate', foreach: links }"></div>
  <!-- /ko -->
</script>

<script type="text/html" id="nodeTemplate">
  <div class="node node-action row-fluid">
    <div class="action span12">
      <div class="row-fluid">
        <div class="span12">
          <h4 data-bind="text: (name()) ? name() : node_type() + '-' + id()"></h4>
          <span data-bind="text: node_type" class="muted"></span>
          <div class="node-description" data-bind="text: description"></div>
        </div>
      </div>

      <div class="row-fluid node-action-bar">
        <div class="span12" style="text-align:right">
          <a class="btn btn-mini edit-node-link" title="${ _('Edit') }" rel="tooltip" data-bind="attr: { 'data-node-type': node_type() }"><i class="icon-pencil"></i></a>
          <a class="btn btn-mini clone-node-btn" title="${ _('Copy') }" rel="tooltip"><i class="icon-copy"></i></a>
          <a class="btn btn-mini delete-node-btn" title="${ _('Delete') }" rel="tooltip"><i class="icon-trash"></i></a>
          &nbsp;
        </div>
      </div>
    </div>
  </div>

  <div class="row-fluid" data-bind="template: { name: 'linkTemplate', foreach: links }"></div>
</script>

<script type="text/html" id="forkTemplate">
  <div class="node node-fork row-fluid">
    <div class="action span12">
      <div class="row-fluid">
        <div class="span12 action-link" title="Edit">
          <h4 data-bind="text: (name()) ? name() : node_type() + '-' + id()"></h4>
          <span data-bind="text: node_type" class="muted"></span>
          <div class="node-description" data-bind="text: description()"></div>
        </div>
      </div>

      <div class="row-fluid node-action-bar">
        <div class="span12" style="text-align:right">
          <a class="btn btn-mini edit-node-link" title="${ _('Edit') }" rel="tooltip" data-bind="attr: { 'data-node-type': node_type() }"><i class="icon-pencil"></i></a>
          <a class="btn btn-mini convert-node-link" title="${ _('Convert to Decision') }" data-bind="attr: { 'data-node-type': node_type() }" rel="tooltip"><i class="icon-wrench"></i></a>
          &nbsp;
        </div>
      </div>
    </div>

    <div class="row-fluid node-fork-children">
      <div class="row-fluid node-fork-child" data-bind="foreach: children">
        <div data-bind="attr: {'class': 'span' + (((12 / $parent.children().length) > 4) ? (12 / $parent.children().length) : 4)}">
          <div class="row-fluid node-fork-child-link" data-bind="template: { name: 'linkTemplate', data: $parent.links()[$index()] }"></div>
          <div data-bind="template: { name: function(item) { return item.view_template() }, foreach: $data }"></div>
        </div>
      </div>
    </div>
  </div>
</script>

<script type="text/html" id="joinTemplate">
  <div class="row-fluid" data-bind="template: { name: 'linkTemplate', foreach: links() }"></div>
</script>

<script type="text/html" id="decisionTemplate">
  <div class="node node-decision row-fluid">
    <div class="action span12">
      <div class="row-fluid">
        <div class="span12 action-link">
          <h4 data-bind="text: (name()) ? name() : node_type() + '-' + id()"></h4>
          <span data-bind="text: node_type" class="muted"></span>
          <div class="node-description" data-bind="text: description()"></div>
        </div>
      </div>

      <div class="row-fluid node-action-bar">
        <div class="span12" style="text-align:right">
          <a class="btn btn-mini edit-node-link" title="${ _('Edit') }" data-bind="attr: { 'data-node-type': node_type() }" rel="tooltip"><i class="icon-pencil"></i></a>
          &nbsp;
        </div>
      </div>
    </div>

    <div class="row-fluid node-decision-children">
      <div class="row-fluid node-decision-child" data-bind="foreach: children">
        <div data-bind="attr: {class: 'span' + (((12 / $parent.children().length) > 4) ? (12 / $parent.children().length) : 4)}">
          <div class="row-fluid node-decision-child-link" data-bind="template: { name: 'linkTemplate', data: $parent.links()[$index()] }"></div>
          <div data-bind="template: { name: function(item) { return item.view_template() }, foreach: $data }"></div>
        </div>
      </div>
    </div>
  </div>
</script>

<script type="text/html" id="decisionEndTemplate">
  <div class="row-fluid" data-bind="template: { name: 'linkTemplate', foreach: links() }"></div>
</script>

<script type="text/html" id="linkTemplate">
  <div class="node-link">&nbsp;</div>
</script>

<script type="text/javascript">
/**
 * Component Initialization
 * Initialize the workflow, registry, modal, and import objects.
 */
 // Custom handlers for saving, loading, error checking, etc.
function import_jobsub_load_success(data) {
  if (data.status == 0) {
    import_jobsub_action.initialize(data.data);
  } else {
    $.jHueNotify.error("${ _('Received invalid response from server: ') } " + JSON.stringify(data));
  }
}

function import_workflow_load_success(data) {
  if (data.status == 0) {
    import_workflow_action.initialize(data.data);
  } else {
    $.jHueNotify.error("${ _('Received invalid response from server: ') } " + JSON.stringify(data));
  }
}

function workflow_save_success(data) {
  $.jHueNotify.info("${ _('Workflow saved') }");
  workflow.reload(data.data);
  workflow.is_dirty( false );
  workflow.loading(false);
  $("#btn-save-wf").button('reset');
}

function workflow_save_error(data) {
  $.jHueNotify.error("${ _('Could not save workflow') }");
  workflow.loading(false);
  $("#btn-save-wf").button('reset');
}

function workflow_load_success(data) {
  if (data.status == 0) {
    workflow.reload(data.data);
  } else {
    $.jHueNotify.error("${ _('Received invalid response from server: ') }" + JSON.stringify(data));
  }
  workflow.loading(false);
}

function workflow_read_only_handler() {
  $.jHueNotify.error("${ _('Workflow is in read only mode.') }");
  workflow.loading(false);
}

// Fetch all nodes from server.
var workflow_model = new WorkflowModel({
  id: ${ workflow.id },
  name: "${ workflow.name }",
  description: "${ workflow.description }",
  start: ${ workflow.start.id },
  end: ${ workflow.end.id },
  job_xml: "${ workflow.job_xml }",
  deployment_dir: "${ workflow.deployment_dir }",
  is_shared: "${ workflow.is_shared }" == "True",
  parameters: ${ workflow.parameters_escapejs | n,unicode },
  job_properties: ${ workflow.job_properties_escapejs | n,unicode }
});
var registry = new Registry();
var workflow = new Workflow({
  model: workflow_model,
  registry: registry,
  read_only: ${ str(not user_can_edit_job).lower() },
  read_only_error_handler: workflow_read_only_handler,
  el: '#editWorkflow'
});
var import_jobsub_action = new ImportJobsubAction({workflow: workflow});
var import_workflow_action = new ImportWorkflowAction({workflow: workflow});
var modal = new Modal($('#node-modal'));

// Load data.
import_jobsub_action.fetchWorkflows({ success: import_jobsub_load_success });
import_workflow_action.fetchWorkflows({ success: import_workflow_load_success });
{
  var spinner = $('<img src="/static/art/spinner.gif" />');
  workflow.loading.subscribe(function(value) {
    if (value) {
      $('#graph').append(spinner);
    } else {
      spinner.remove();
    }
  });
  workflow.loading(true);
  workflow.load({ success: workflow_load_success });
}

/**
 * Modals
 */
// open a modal window for editing a node
function edit_node_modal(node, save, cancel, template) {
  var backup = ko.mapping.toJS(node);
  normalize_model_fields(backup);

  modal.hide();
  modal.setTemplate(template || node.edit_template);
  modal.show({node: node, read_only: workflow.read_only()});
  modal.recenter(280, 250);
  modal.addDecorations();

  var cancel_edit = cancel || function() {
    ko.mapping.fromJS(backup, node);
    modal.hide();

    // Prevent event propagation
    return false;
  };

  var try_save = save || function() {
    if (node.validate()) {
      workflow.is_dirty( true );
      modal.hide();
    }
  };

  $('.modal-backdrop').on('click', cancel_edit);
  modal.el.on('click', '.close', cancel_edit);
  modal.el.on('click', '.cancelButton', cancel_edit);
  modal.el.on('click', '.doneButton', try_save);

  modal.el.on('click', '.edit-node-link', function() {
    var link = ko.contextFor(this).$data;
    var parent = ko.contextFor(this).$parent;
    var node = parent.registry.get(link.child());

    cancel_edit();

    edit_node_modal(node);
  });
}

// Drag a new node onto the canvas
workflow.el.on('mousedown', '.new-node-link', function(e) {
  e.preventDefault();

  // Node starts off graph, then is validated/dropped onto graph, after being dragged onto graph.
  var node_type = $(this).attr('data-node-type');
  var NodeModel = nodeModelChooser(node_type);
  var model = new NodeModel({
    id: IdGeneratorTable[node_type].nextId(),
    node_type: node_type
  });
  var node = new Node(workflow, model, registry);
  workflow.registry.add(model.id, node);

  // Add to new node location, then drag and drop.
  workflow.new_node( node );
  workflow.draggables();

  // Reposition node to mouse pointer.
  var el = $("#new-node .node-action");
  var old_position = el.offset();

  // Trigger fake mousedown event to start dragging node.
  var is_dirty = workflow.is_dirty();
  el.offset({ top: e.pageY - el.height()/10, left: e.pageX - el.width()/10 });
  el.trigger($.Event("mousedown", {pageX: e.pageX, pageY: e.pageY, target: el[0], which: 1}));

  var cancel_edit = function(e) {
    // Didn't save, erase node.
    node.detach();
    node.erase();
    modal.hide();
    workflow.is_dirty( is_dirty );
    workflow.el.trigger('workflow:rebuild');
  };

  var try_save = function(e) {
    if (node.validate()) {
      workflow.is_dirty( true );
      modal.hide();
      node.addChild(workflow.kill);
      workflow.el.trigger('workflow:rebuild');
    }
  };

  // Remember to cleanup after.
  el.one('dragstop', function(e) {
    workflow.new_node(null);
    el.offset(old_position);
    if (node.findChildren().length > 0 || node.findParents().length > 1) {
      edit_node_modal(node, try_save, cancel_edit);
    } else {
      node.erase();
    }
  });
});

// Modal for editing a node
workflow.el.on('click', '.edit-node-link', function(e) {
  var node = ko.contextFor(this).$data;
  edit_node_modal(node);
});

// Modal for converting to a decision node
workflow.el.on('click', '.convert-node-link', function(e) {
  var node = ko.contextFor(this).$data;
  edit_node_modal(node, null, null, 'forkConvertTemplate');
});

// Modal for cloning a node
workflow.el.on('click', '.clone-node-btn', function(e) {
  var node = ko.contextFor(this).$data;
  var model = node.model.copy();
  model.id = IdGeneratorTable[model.node_type].nextId();
  model.name += '-copy';
  model.child_links = [];
  var new_node = new Node(workflow, model, workflow.registry);
  workflow.registry.add(new_node.id(), new_node);

  var cancel_edit = function(e) {
    // Didn't save, erase node.
    new_node.erase();
    modal.hide();
  };

  var try_save = function(e) {
    if (node.validate()) {
      workflow.is_dirty( true );
      modal.hide();
      // save, add kill, add node to workflow.
      new_node.addChild(workflow.kill);
      node.append(new_node);
      workflow.el.trigger('workflow:rebuild');
    }
  };

  edit_node_modal(new_node, try_save, cancel_edit);
});

// Modal for deleting a node
workflow.el.on('click', '.delete-node-btn', function(e) {
  var node = ko.contextFor(this).$data;
  $('#confirmation').find('h3').text('${ _('Confirm Delete') }');
  $('#confirmation').find('.modal-body').html('${ _('Are you sure you want to delete ') }<strong>' + node.name() + '</strong>?');
  $('#confirmation').find('.btn-primary').removeClass('btn-primary').addClass('btn-danger');
  $('#confirmation').find('.btn-danger').on('click', function () {
    node.detach();
    node.erase();
    workflow.rebuild();
    workflow.is_dirty(true);
    $('#confirmation').modal('hide');
    $('#confirmation').find('h3').text('');
    $('#confirmation').find('.modal-body').text('');
    $('#confirmation').find('.btn-danger').removeClass('btn-danger').addClass('btn-primary');
  });
  $('#confirmation').modal('show');
});

//// Import actions
var import_view_model = {
  jobsub: ko.observable(import_jobsub_action),
  oozie: ko.observable(import_workflow_action),
};

function importAction(workflow, model) {
  model.id = IdGeneratorTable[model.node_type].nextId();
  var node = new Node(workflow, model, workflow.registry);
  workflow.registry.add(model.id, node);

  // Add kill, add node to workflow as child of start.
  workflow.is_dirty( true );
  node.addChild(workflow.kill);
  workflow.registry.get(workflow.start()).append(node);
}

// Step 1 - Jobsub
// Select and import action
$('#importJobsub').on('click', '.action-row', function(e) {
  // Check ID to make sure we are not hitting N/A
  if ('id' in ko.contextFor($(this)[0]).$data) {
    // Select workflow, then fetch jobsub workflow.
    // Current KO context for clicked element should be the workflow.
    import_view_model.jobsub().selected_workflow(ko.contextFor($(this)[0]).$data);
    // Should only have 1 node since jobsub workflows are single node workflows.
    import_view_model.jobsub().fetchNodes({
      success: function(data) {
        if (data.status == 0) {
          import_view_model.jobsub().initialize({nodes: data.data.actions});

          // Remember, jobsub guarantees exactly one node.
          importAction(workflow, import_view_model.jobsub().nodes()[0]);

          workflow.el.trigger('workflow:rebuild');
          routie('editWorkflow');
          $.jHueNotify.success("${ _('Action imported at the top of the workflow.') } ");
        } else {
          $.jHueNotify.error("${ _('Received invalid response from server: ') } " + JSON.stringify(data));
        }
      }
    });
  }
});


// Step 1 - Oozie
// Select workflow
$('#importOozie').on('click', '.action-row', function(e) {
  // Check ID to make sure we are not hitting N/A
  if ('id' in ko.contextFor($(this)[0]).$data) {
    // Select workflow, then fetch oozie workflow.
    // Current KO context for clicked element should be the workflow.
    import_view_model.oozie().selected_workflow(ko.contextFor($(this)[0]).$data);
    import_view_model.oozie().fetchNodes({
      success: function(data) {
        if (data.status == 0) {
          import_view_model.oozie().initialize({nodes: data.data.actions});
          routie('importAction/oozie');
        } else {
          $.jHueNotify.error("${ _('Received invalid response from server: ') } " + JSON.stringify(data));
        }
      }
    });
  }
});

// Step 2 - Oozie
// Select and import action
$('#importOozieAction').on('click', '.action-row', function(e) {
  // Check ID to make sure we are not hitting N/A
  if ('id'  in ko.contextFor($(this)[0]).$data) {
    // Current KO context for clicked element should be the action
    importAction(workflow, ko.contextFor($(this)[0]).$data);

    workflow.el.trigger('workflow:rebuild');
    routie('editWorkflow');
    $.jHueNotify.success("${ _('Action imported at the top of the workflow.') } ");
  }
});

// Bindings
ko.bindingHandlers.fileChooser = {
  init: function(element, valueAccessor, allBindings, model) {
    var self = $(element);
    self.after(getFileBrowseButton(self, true));
  }
};

ko.applyBindings(workflow, workflow.el[0]);
ko.applyBindings(workflow, $('#formActions')[0]);
ko.applyBindings(workflow, $('#properties')[0]);
ko.applyBindings(workflow, $('#workflowControls')[0]);
ko.applyBindings(import_view_model, $('#importAction')[0]);
ko.applyBindings(import_view_model.oozie(), $('#importOozieAction')[0]);

window.onbeforeunload = function (e) {
  if (workflow.is_dirty()) {
    var message = "${ _('You have unsaved changes in this workflow.') }";

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

window.onresize = function () {
  if (modal) {
    modal.recenter(280, 250);
  }
};

var AUTOCOMPLETE_PROPERTIES;

$(document).ready(function () {

  routie('editWorkflow');

  var actionToolbarProperties = {
    docked: false,
    detachPosition: 0,
    initialWidth: 0
  }

  $(window).scroll(function () {
    if (!actionToolbarProperties.docked && ($('#actionToolbar').offset().top - 82 - $(window).scrollTop() < 0)) {
      $('#actionToolbar').addClass('shadowed');
      $('#actionToolbar').css('position', 'fixed');
      $('#actionToolbar').css('top', '82px');
      $('#graph').css('marginTop', ($('#actionToolbar').outerHeight() + 38) + 'px');
      $('#actionToolbar').width(actionToolbarProperties.initialWidth);
      actionToolbarProperties.detachPosition = $(window).scrollTop();
      actionToolbarProperties.docked = true;
    }
    else if (actionToolbarProperties.docked && $(window).scrollTop() < actionToolbarProperties.detachPosition) {
      $('#actionToolbar').removeClass('shadowed');
      $('#actionToolbar').css('position', '');
      $('#graph').css('marginTop', '');
      actionToolbarProperties.docked = false;
    }
    else {
      if (actionToolbarProperties.initialWidth == 0) {
        actionToolbarProperties.initialWidth = $('#actionToolbar').width();
      }
    }
  });

  window.setInterval(checkModelDirtiness, 500);
  $('#clone-btn').on('click', function () {
    var _url = $(this).data('clone-url');
    $.post(_url, function (data) {
      window.location = data.url;
    });
  });
  $('#submit-btn').on('click', function () {
    var _url = $(this).data('submit-url');
    $.get(_url, function (response) {
        $('#submit-wf-modal').html(response);
        $('#submit-wf-modal').modal('show');
      }
    );
  });

  routie({
    'properties':function () {
      showSection('properties');
    },
    'importAction':function() {
      $("#importAction *[rel=tooltip]").tooltip();
      showSection('importAction');
    },
    'importAction/oozie':function() {
      $("#importOozieAction *[rel=tooltip]").tooltip();
      showSection('importOozieAction');
    },
    'editWorkflow':function() {
      showSection('editWorkflow');
    },
    'listHistory':function () {
      showSection('listHistory');
    }
  });

  function highlightMenu(section) {
    $('.nav-list li').removeClass('active');
    if (section == 'importOozieAction') {
      section = 'importAction';
    }
    $('a[href="#' + section + '"]:first').parent().addClass('active');
  }

  function showSection(section) {
    $('.section').hide();
    $('#' + section).show();
    highlightMenu(section);
    $(window).scrollTop(0);
    if (section == 'editWorkflow') {
      $('#actionToolbar').removeClass('shadowed');
      $('#actionToolbar').css('position', '');
      $('#graph').css('marginTop', '');
      actionToolbarProperties.docked = false;
      if (actionToolbarProperties.initialWidth == 0) {
        actionToolbarProperties.initialWidth = $('#actionToolbar').width();
      }
    }
  }

  // load the autocomplete properties
  $.getJSON("${ url('oozie:autocomplete_properties') }", function (properties) {
    AUTOCOMPLETE_PROPERTIES = properties;
  });
});

function checkModelDirtiness() {
  if (workflow.is_dirty()) {
    $('.ribbon-wrapper').fadeIn();
  } else {
    $('.ribbon-wrapper').hide();
  }
}

</script>

${ utils.path_chooser_libs(True) }

<script>
  $(document).ready(function(){
    $("input[name='job_xml']").next().remove();
    $("input[name='job_xml']").after(getFileBrowseButton($("input[name='job_xml']"), false));
  });
</script>

${ commonfooter(messages) | n,unicode }
