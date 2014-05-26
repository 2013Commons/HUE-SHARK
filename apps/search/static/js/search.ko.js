// Licensed to Cloudera, Inc. under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  Cloudera, Inc. licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

var Importable = function (importable) {
  var self = this;
  self.type = ko.observable(importable.type);
  self.name = ko.observable(importable.name);
  self.selected = ko.observable(false);
  self.handleSelect = function (row, e) {
    this.selected(!this.selected());
  };
};

var Collection = function (coll) {
  var self = this;

  self.id = ko.observable(coll.id);
  self.name = ko.observable(coll.name);
  self.label = ko.observable(coll.label);
  self.isCoreOnly = ko.observable(coll.isCoreOnly);
  self.absoluteUrl = ko.observable(coll.absoluteUrl);
  self.selected = ko.observable(false);
  self.hovered = ko.observable(false);

  self.handleSelect = function (row, e) {
    this.selected(!this.selected());
  };
  self.toggleHover = function (row, e) {
    this.hovered(!this.hovered());
  };
}

var SearchCollectionsModel = function (props) {
  var self = this;

  self.LABELS = props.labels;

  self.LIST_COLLECTIONS_URL = props.listCollectionsUrl;
  self.LIST_IMPORTABLES_URL = props.listImportablesUrl;
  self.IMPORT_URL = props.importUrl;
  self.DELETE_URL = props.deleteUrl;
  self.COPY_URL = props.copyUrl;

  self.isLoading = ko.observable(true);
  self.isLoadingImportables = ko.observable(false);
  self.allSelected = ko.observable(false);

  self.collections = ko.observableArray([]);
  self.filteredCollections = ko.observableArray(self.collections());

  self.importableCollections = ko.observableArray([]);
  self.importableCores = ko.observableArray([]);

  self.collectionToDelete = null;

  self.selectedCollections = ko.computed(function () {
    return ko.utils.arrayFilter(self.collections(), function (coll) {
      return coll.selected();
    });
  }, self);

  self.selectedImportableCollections = ko.computed(function () {
    return ko.utils.arrayFilter(self.importableCollections(), function (imp) {
      return imp.selected();
    });
  }, self);

  self.selectedImportableCores = ko.computed(function () {
    return ko.utils.arrayFilter(self.importableCores(), function (imp) {
      return imp.selected();
    });
  }, self);

  self.selectAll = function () {
    self.allSelected(!self.allSelected());
    ko.utils.arrayForEach(self.collections(), function (coll) {
      coll.selected(self.allSelected());
    });
    return true;
  };

  self.filterCollections = function (filter) {
    self.filteredCollections(ko.utils.arrayFilter(self.collections(), function (coll) {
      return coll.name().toLowerCase().indexOf(filter.toLowerCase()) > -1
    }));
  };

  self.editCollection = function (collection) {
    self.isLoading(true);
    self.collections.removeAll();
    self.filteredCollections.removeAll();
    location.href = collection.absoluteUrl();
  };

  self.markForDeletion = function (collection) {
    self.collectionToDelete = collection;
    $(document).trigger("confirmDelete");
  };

  self.deleteCollection = function () {
    $(document).trigger("deleting");
    $.post(self.DELETE_URL,
      {
        id: self.collectionToDelete.id()
      },
      function (data) {
        self.updateCollections();
        $(document).trigger("collectionDeleted");
      }, "json");
  };

  self.copyCollection = function (collection) {
    $(document).trigger("copying");
    $.post(self.COPY_URL,
      {
        id: collection.id(),
        type: collection.isCoreOnly()?"core":"collection"
      },
      function (data) {
        self.updateCollections();
        $(document).trigger("collectionCopied");
      }, "json");
  };

  self.updateCollections = function () {
    self.isLoading(true);
    $.getJSON(self.LIST_COLLECTIONS_URL, function (data) {
      self.collections(ko.utils.arrayMap(data, function (coll) {
        return new Collection(coll);
      }));
      self.filteredCollections(self.collections());
      $(document).trigger("collectionsRefreshed");
      self.isLoading(false);
    });
  };

  self.updateImportables = function () {
    self.isLoadingImportables(true);
    $.getJSON(self.LIST_IMPORTABLES_URL, function (data) {
      self.importableCollections(ko.utils.arrayMap(data.newSolrCollections, function (coll) {
        return new Importable(coll);
      }));
      self.importableCores(ko.utils.arrayMap(data.newSolrCores, function (core) {
        return new Importable(core);
      }));
      self.isLoadingImportables(false);
    });
  };

  self.importCollectionsAndCores = function () {
    $(document).trigger("importing");
    var selected = [];
    ko.utils.arrayForEach(self.selectedImportableCollections(), function (imp) {
      selected.push({
        type: imp.type(),
        name: imp.name()
      });
    });
    ko.utils.arrayForEach(self.selectedImportableCores(), function (imp) {
      selected.push({
        type: imp.type(),
        name: imp.name()
      });
    });
    $.post(self.IMPORT_URL,
      {
        selected: ko.toJSON(selected)
      },
      function (data) {
        $(document).trigger("imported");
        self.updateCollections();
      }, "json");
  };

};
