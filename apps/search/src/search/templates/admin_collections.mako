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

<%namespace name="macros" file="macros.mako" />
<%namespace name="actionbar" file="actionbar.mako" />

${ commonheader(_('Search'), "search", user, "40px") | n,unicode }

<link rel="stylesheet" href="/search/static/css/admin.css">

<div class="search-bar" style="height: 30px">
    <div class="pull-right" style="margin-top: 4px; margin-right: 20px">
      <a href="${ url('search:index') }"><i class="icon-share-alt"></i> ${ _('Search page') }</a>
    </div>
  <h4>${_('Collection Manager')}</h4>
</div>


<div class="container-fluid">

  <%actionbar:render>
    <%def name="search()">
      <input type="text" placeholder="${_('Filter collections by name...')}" class="input-xlarge search-query" id="filterInput">
    </%def>

    <%def name="creation()">
      <button id="importBtn" type="button" class="btn"><i class="icon-plus-sign"></i> ${ _('Import') }</button>
    </%def>
  </%actionbar:render>

  <div class="row-fluid" data-bind="visible: collections().length == 0 && !isLoading()">
    <div class="span10 offset1 center">
      <i class="icon-plus-sign waiting"></i>
      <h1 class="emptyMessage">${ _('There are currently no collections defined.') }<br/>${ _('Please click on Import to add one or more.') }</h1>
    </div>
  </div>
  <div class="row-fluid" data-bind="visible: isLoading()">
    <div class="span10 offset1 center">
      <i class="icon-spinner icon-spin" style="font-size: 60px; color: #DDD"></i>
    </div>
  </div>
  <div class="row-fluid">
    <div class="span12">
      <ul id="collections" data-bind="template: {name: 'collectionTemplate', foreach: filteredCollections}">
      </ul>
    </div>
  </div>

  <script id="collectionTemplate" type="text/html">
    <li style="cursor: pointer" data-bind="click: $root.editCollection" title="${ _('Click to edit') }">
      <div class="pull-right" style="margin-top: 10px;margin-right: 10px; cursor: pointer">
        <a data-bind="click: $root.copyCollection, clickBubble: false"><i class="icon-copy"></i> ${_('Copy')}</a> &nbsp;
        <a data-bind="click: $root.markForDeletion, clickBubble: false"><i class="icon-remove"></i> ${_('Delete')}</a>
      </div>
      <h4><i class="icon-list"></i> <span data-bind="text: label"></span></h4>
    </li>
  </script>

</div>

<div id="importModal" class="modal hide fade">
  <div class="modal-header">
    <button type="button" class="close" data-dismiss="modal">&times;</button>
    <h3>${ _('Import Collections and Cores') }</h3>
  </div>
  <div class="modal-body">
    <img src="/static/art/spinner.gif" data-bind="visible: isLoadingImportables()" />
    <div data-bind="visible: !isLoadingImportables()">
      <h5>${ _('Collections') }</h5>
      <div class="alert" data-bind="visible: importableCollections().length == 0">${ _('All available collections from the Solr URL in hue.ini have been imported.') }</div>
      <table data-bind="visible: importableCollections().length > 0, template: {name: 'importableTemplate', foreach: importableCollections}"></table>

      <h5 style="margin-top: 20px">${ _('Cores') }</h5>
      <div class="alert" data-bind="visible: importableCores().length == 0">${ _('All available cores from the Solr URL in hue.ini have been imported.') }</div>
      <table data-bind="visible: importableCores().length > 0, template: {name: 'importableTemplate', foreach: importableCores}"></table>
    </div>
  </div>
  <div class="modal-footer">
    <a href="javascript:void(0)" class="btn" data-dismiss="modal">${ _('Cancel') }</a>
    <button id="importModalBtn" href="javascript:void(0)" class="btn btn-primary disable-feedback" data-bind="enable: selectedImportableCollections().length > 0 || selectedImportableCores().length > 0, click: importCollectionsAndCores">${ _('Import Selected') }</button>
  </div>
</div>

<script id="importableTemplate" type="text/html">
  <tr>
    <td width="24">
      <div data-bind="click: handleSelect, css: {hueCheckbox: true, 'icon-ok': selected}"></div>
    </td>
    <td data-bind="text: name"></td>
  </tr>
</script>

<div id="deleteModal" class="modal hide fade">
  <div class="modal-header">
    <a href="#" class="close" data-dismiss="modal">&times;</a>
    <h3>${_('Confirm Delete')}</h3>
  </div>
  <div class="modal-body">
    <p>${_('Are you sure you want to delete this collection?')}</p>
  </div>
  <div class="modal-footer">
    <a class="btn" data-dismiss="modal">${_('No')}</a>
    <a id="deleteModalBtn" class="btn btn-danger disable-feedback" data-bind="click: deleteCollection">${_('Yes')}</a>
  </div>
</div>


<style type="text/css">
  #collections {
    list-style-type: none;
    margin: 0;
    padding: 0;
    width: 100%;
  }

  #collections li {
    margin-bottom: 10px;
    padding: 10px;
    border: 1px solid #E3E3E3;
    height: 40px;
  }

  .placeholder {
    height: 40px;
    background-color: #F5F5F5;
    border: 1px solid #E3E3E3;
  }
</style>

<script src="/static/ext/js/knockout-min.js" type="text/javascript" charset="utf-8"></script>
<script src="/search/static/js/search.ko.js" type="text/javascript" charset="utf-8"></script>

<script type="text/javascript">

  var appProperties = {
    labels: [],
    listCollectionsUrl: "${ url("search:admin_collections") }?format=json",
    listImportablesUrl: "${ url("search:admin_collections_import") }?format=json",
    importUrl: "${ url("search:admin_collections_import") }",
    deleteUrl: "${ url("search:admin_collection_delete") }",
    copyUrl: "${ url("search:admin_collection_copy") }"
  }

  var viewModel = new SearchCollectionsModel(appProperties);
  ko.applyBindings(viewModel);

  $(document).ready(function () {
    viewModel.updateCollections();

    var orderedCores;
    serializeList();

    function serializeList() {
      orderedCores = [];
      $("#collections li").each(function () {
        orderedCores.push($(this).data("collection"));
      });
    }

    var filter = -1;
    $("#filterInput").on("keyup", function () {
      clearTimeout(filter);
      filter = window.setTimeout(function () {
        viewModel.filterCollections($("#filterInput").val());
      }, 300);
    });

    $("#importModal").modal({
      show: false
    });

    $("#deleteModal").modal({
      show: false
    });

    % if is_redirect:
        showImportModal();
    % endif

    $("#importBtn").on("click", function () {
      showImportModal();
    });

    function showImportModal() {
      $("#importModal").modal("show");
      viewModel.updateImportables();
    }

    $(document).on("importing", function () {
      var _btn = $("#importModalBtn");
      _btn.attr("data-loading-text", _btn.text() + " ...");
      _btn.button("loading");
    });

    $(document).on("imported", function () {
      $("#importModal").modal("hide");
      $("#importModalBtn").button("reset");
      $.jHueNotify.info("${ _("Collections imported successfully.") }");
    });

    $(document).on("deleting", function () {
      var _btn = $("#deleteModalBtn");
      _btn.attr("data-loading-text", _btn.text() + " ...");
      _btn.button("loading");
    });

    $(document).on("collectionDeleted", function () {
      $("#deleteModal").modal("hide");
      $("#deleteModalBtn").button("reset");
      $.jHueNotify.info("${ _("Collection deleted successfully.") }");
    });

    $(document).on("collectionCopied", function () {
      $.jHueNotify.info("${ _("Collection copied successfully.") }");
    });

    $(document).on("confirmDelete", function () {
      $("#deleteModal").modal('show');
    });

  });
</script>

${ commonfooter(messages) | n,unicode }
