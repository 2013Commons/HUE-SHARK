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

<%namespace name="layout" file="layout.mako" />
<%namespace name="macros" file="macros.mako" />
<%namespace name="utils" file="utils.inc.mako" />


${ commonheader(_('Search'), "search", user, "40px") | n,unicode }

<%def name="indexProperty(key)">
  %if key in solr_collection["status"][hue_collection.name]["index"]:
      ${ solr_collection["status"][hue_collection.name]["index"][key] }
    %endif
</%def>

<%def name="collectionProperty(key)">
  %if key in solr_collection["status"][hue_collection.name]:
      ${ solr_collection["status"][hue_collection.name][key] }
    %endif
</%def>

<%layout:skeleton>
  <%def name="title()">
    <h4>${_('Customize ')} ${ hue_collection.label }</h4>
  </%def>

  <%def name="navigation()">
    ${ layout.sidebar(hue_collection, 'properties') }
  </%def>

  <%def name="content()">
  <form method="POST">
    <ul class="nav nav-tabs">
      <li class="active">
        <a href="#index" data-toggle="tab">${_('Collection')}</a>
      </li>
      <li>
        <a href="#schema" data-toggle="tab">${_('Schema')}</a>
      </li>
      <li>
        <a href="#properties" data-toggle="tab">${_('Indexes')}</a>
      </li>
    </ul>
    <div class="tab-content">
      <div class="tab-pane active" id="index">
        <div class="fieldWrapper">
          ${ utils.render_field(collection_form['enabled']) }
          ${ utils.render_field(collection_form['label']) }
          ${ utils.render_field(collection_form['name']) }
        </div>

	    <div class="form-actions">
	      <button type="submit" class="btn btn-primary" id="save-sorting">${_('Save')}</button>
	    </div>
      </div>

      <div class="tab-pane" id="schema">
        <textarea id="schema_field">${_('Loading...')}</textarea>
      </div>

      <div class="tab-pane" id="properties">
        ${_('Loading...')} <img src="/static/art/spinner.gif">
      </div>
    </div>
  </form>
  </%def>

</%layout:skeleton>

<script src="/static/ext/js/codemirror-3.11.js"></script>
<link rel="stylesheet" href="/static/ext/css/codemirror.css">
<script src="/static/ext/js/codemirror-xml.js"></script>

<script type="text/javascript" charset="utf-8">
  $(document).ready(function(){
    var schemaViewer = $("#schema_field")[0];

    var codeMirror = CodeMirror(function (elt) {
      schemaViewer.parentNode.replaceChild(elt, schemaViewer);
    }, {
      value: schemaViewer.value,
      readOnly: true,
      lineNumbers: true
    });

    codeMirror.setSize("100%", $(document).height() - 150 - $(".form-actions").outerHeight());

    $.get("${ url('search:admin_collection_schema', collection_id=hue_collection.id) }", function (data) {
      codeMirror.setValue(data.solr_schema);
    });
    $.get("${ url('search:admin_collection_solr_properties', collection_id=hue_collection.id) }", function (data) {
      $("#properties").html(data.content);
    });

    // Force refresh on tab change
    $("a[data-toggle='tab']").on("shown", function (e) {
      if ($(e.target).attr("href") == "#schema") {
        codeMirror.refresh();
      }
    });
 });
</script>

${ commonfooter(messages) | n,unicode }
