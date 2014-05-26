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

var searchRenderers = {
  'rowkey': { //class to tag selection
     select: /([^,]+\[[^\]\[]+\]|[^,]+)/g, //select the substring to process, useful as JS has no lookbehinds old: ([^,]+\[([^,]+(,|)+)+\]|[^,]+)
     tag: /.+/g, //select the matches to wrap with tags
     strip: /,(?![^\[\]\:]+[^\]\[]+\])/g, //strip delimiters and post-process string to make nice
     nested: {
       'scan': { select: /\+[0-9 ]+/g, tag: /.+/g, strip: /a^/g },
        'columns': { select: /\[.+\]/g, tag: /[^:,\[\]]+:([^,\[\]]+|)/g, strip: /[\[\]]/g }, //forced to do this select due to lack of lookbehinds
        'prefix': { select: /[^\*]+\*/g, tag: /\*/g, strip: /a^/g }
     }
  }
};

var DataTableViewModel = function(options)
{
  var self = this, _defaults = {
    name: '',
    columns: [],
    items: [],
    reload: function()
    {

    },
    el:''
  };
  options = ko.utils.extend(_defaults,options);
  ListViewModel.apply(this, [options]);

  self.name = ko.observable(options.name);
  self.searchQuery.subscribe(function(value)
  {
    self._table.fnFilter(value);
  });
  self.columns = ko.observableArray(options.columns);
  self._el = $('table[data-datasource="' + options.el + '"]');
  self._table = null;
  self._initTable = function()
  {
    if(!self._table)
    {
      self._table = self._el.dataTable({
        "aoColumnDefs": [
          { "bSortable": false, "aTargets": [ 0 ] }
        ],
      "sDom": 'tr',//this has to be in, change to sDom so you can call filter()
      'bAutoWidth':false,
      "iDisplayLength": -1});
      return self._table;
    }
  };
  self.sort = function(viewModel, event) {
      var el = $(event.currentTarget);
  };
  var _reload = self.reload;
  self.reload = function(callback)
  {
    if(self._table)
    {
      self._table.fnClearTable();
      self._table.fnDestroy();
      self._table = null;
    }
    _reload(function()
    {
      self._initTable();
      if(callback!=null)
        callback();
    });
  };
};

//a Listview of Listviews
var SmartViewModel = function(options)
{
  var self = this;
  options = ko.utils.extend({
    name: '',
    items: [],
    reload: function()
    {

    },
    el:'',
    sortFields: {
      'Row Key': function(a, b)
      {
        return a.row.localeCompare(b.row);
      },
      'Column Count': function(a, b)
      {
        a = a.items().length;
        b = b.items().length;
        if(a > b)
          return 1;
        if(a < b)
          return -1;
        return 0;
      },
      'Row Key Length': function(a, b)
      {
        a = a.row.length;
        b = b.row.length;
        if(a > b)
          return 1;
        if(a < b)
          return -1;
        return 0;
      }
    }
  }, options);
  ListViewModel.apply(this, [options]); //items: [ListView.items[],ListView.items[]]

  self.columnFamilies = ko.observableArray();
  self.name = ko.observable(options.name);
  self.name.subscribe(function(){
    self.querySet.removeAll();
    self.querySet.push(new QuerySetPeice({
      'row_key': 'null',
      'scan_length': 10,
      'prefix': 'false'
    }));
    self._reloadcfs();
  }); //fix and decouple

  self.lastReloadTime = ko.observable(1);
  //self.columnFamilies.subscribe(function(){self.reload();});

  self.searchQuery.subscribe(function goToRow(value) //make this as nice as the renderfucnction and split into two, also fire not down on keyup events
  {
    var inputs = value.split(searchRenderers['rowkey']['select']);
    self.querySet.removeAll();
    for(var i=0;i<inputs.length;i++)
    {
      if(inputs[i].trim() != "" && inputs[i].trim() != ',')
      {
        var p = inputs[i].split('+');
        var scan = p.length > 1 ? parseInt(p[1]) : 0;
        var extract = inputs[i].match(searchRenderers['rowkey']['nested']['columns']['select']);
        var columns = extract != null ? extract[0].match(searchRenderers['rowkey']['nested']['columns']['tag']) : [];
        self.querySet.push(new QuerySetPeice({
          'row_key': p[0].replace(/\[.+\]|\*/g,'').trim(), //clean up with column regex selectors instead
          'scan_length': scan ? scan + 1 : 1,
          'columns': columns,
          'prefix': inputs[i].match(searchRenderers['rowkey']['nested']['prefix']['select']) != null
        }));
      }
    }
    routie(app.cluster() + '/' + app.views.tabledata.name() +'/query/' + value);
    self.evaluateQuery();
  });

  self._reloadcfs = function()
  {
    return API.queryTable("getColumnDescriptors").done(function(data)
    {
      self.columnFamilies.removeAll();
      var keys = Object.keys(data);
      for(var i=0;i<keys.length;i++)
      {
        self.columnFamilies.push(new ColumnFamily({name:keys[i], enabled:false}));
      }
      self.reload();
    });
  };

  self.columnQuery = ko.observable("");
  self.columnQuery.subscribe(function(query)
  {
    $(self.items()).each(function()
    {
      this.searchQuery(query);
    });
  });

  self.rows = ko.computed(function()
  {
    var a = [];
    var items = this.items();
    for(var i=0; i<items.length; i++)
    {
      a.push(items[i].row);
    }
    return a;
  }, self);

  self.querySet = ko.observableArray();
  self.validateQuery = function()
  {
    $(self.querySet()).each(function()
    {
      this.validate();
      this.editing(false);
    });
  };
  self.addQuery = function()
  {
    self.validateQuery();
    self.querySet.push(new QuerySetPeice({onValidate: function()
    {
      //self.reload();
    }}))
  };
  self.evaluateQuery = function(callback)
  {
    self.validateQuery();
    self.reload(callback);
  };
  var _reload = self.reload;
  self.reload = function(callback)
  {
    self.truncated = ko.observable(false);
    var queryStart = new Date();
    _reload(function()
    {
      self.lastReloadTime((new Date() - queryStart)/1000);
      if(callback!=null)
        callback();
      self.isLoading(false);
    });
  };

  self.truncated = ko.observable(false);
  self.truncateLimit = ko.observable(1500);
  self.truncateCount = ko.observable(0);
};

var SmartViewDataRow = function(options)
{
  var self = this;
  options = ko.utils.extend({
    sortFields: {
      'Column Family': function(a, b)
      {
        return a.name.localeCompare(b.name);
      },
      'Column Name': function(a, b)
      {
        return a.name.split(':')[1].localeCompare(b.name.split(':')[1]);
      },
      'Cell Value': function(a, b)
      {
        a = a.value.length;
        b = b.value.length;
        if(a > b)
          return 1;
        if(a < b)
          return -1;
        return 0;
      },
      'Timestamp': function(a, b)
      {
        a = parseInt(a.timestamp);
        b = parseInt(b.timestamp);
        if(a > b)
          return 1;
        if(a < b)
          return -1;
        return 0;
      },
      'MIME Type': function()
      {

      },
      'Column Name Length': function(a, b)
      {
        a = a.name.split(':')[1].length;
        b = b.name.split(':')[1].length;
        if(a > b)
          return 1;
        if(a < b)
          return -1;
        return 0;
      }
    }
  }, options);
  DataRow.apply(self,[options]);
  ListViewModel.apply(self,[options]);

  self.displayedItems = ko.observableArray();

  self.displayRangeStart = 0;
  self.displayRangeLength = 20;
  self.items.subscribe(function()
  {
    self.displayedItems([]);
    self.updateDisplayedItems();
  });

  self.searchQuery.subscribe(function(searchValue)
  {
    self.scrollLoadSource = ko.computed(function(){
      return self.items().filter(function(column)
      {
        return column.name.toLowerCase().indexOf(searchValue.toLowerCase()) != -1;
      });
    });
    self.displayRangeLength = 20;
    self.updateDisplayedItems();
  });

  self.scrollLoadSource = self.items;

  self.updateDisplayedItems = function()
  {
    var x = self.displayRangeStart;
    self.displayedItems(self.scrollLoadSource().slice(x, x + self.displayRangeLength));
  };

  self.resetScrollLoad = function()
  {
    self.scrollLoadSource = self.items;
    self.updateDisplayedItems();
  };

  self.toggleSelectedCollapse = function()
  {
    if(self.displayedItems().length == self.displayRangeStart + self.displayRangeLength)
    {
      self.displayedItems(self.displayedItems().filter(function(item)
      {
        return item.isSelected();
      }));
      self.scrollLoadSource = self.displayedItems;
    }
    else
    {
      self.resetScrollLoad();
    }
  };

  self.onScroll = function(target, ev)
  {
    if($(ev.target).scrollLeft() == ev.target.scrollWidth - ev.target.clientWidth && self.displayedItems().length < self.scrollLoadSource().length)
    {
      self.displayRangeLength += 15;
      self.updateDisplayedItems();
    }
  };

  self.drop = function(cont)
  {
    function doDrop()
    {
      self.isLoading(true);
      return API.queryTable('deleteAllRow', self.row, "{}").complete(function()
      {
        app.views.tabledata.items.remove(self); //decouple later
        self.isLoading(false);
      });
    }

    (cont === true) ? doDrop() : confirm("Confirm Delete", 'Delete row ' + self.row + '? (This cannot be undone)', doDrop);
  };

  self.setItems = function(cols)
  {
    var colKeys = Object.keys(cols);
    var items = [];
    for(var q=0;q<colKeys.length;q++)
    {
      items.push(new ColumnRow({name: colKeys[q],
             timestamp: cols[colKeys[q]].timestamp,
             value: cols[colKeys[q]].value,
             parent: self}));
    }
    self.items(items);
    return self.items();
  };

  self.selectAllVisible = function(){
    for(t=0;t<self.displayedItems().length;t++)
      self.displayedItems()[t].isSelected(true);
    return self;
  };

  self.toggleSelectAllVisible = function()
  {
    if(self.selected().length != self.displayedItems().length)
      return self.selectAllVisible();
    return self.deselectAll();
  };

  self.push = function(item)
  {
    var column = new ColumnRow(item);
    self.items.push(column);
  };

  var _reload = self.reload;
  self.reload = function(callback)
  {
    _reload(function()
    {
      if(callback!=null)
        callback();
      self.isLoading(false);
    });
  };
};

var ColumnRow = function(options)
{
  var self = this;
  ko.utils.extend(self,options);
  DataRow.apply(self,[options]);

  self.value = ko.observable(self.value);
  self.history = new CellHistoryPage({row: self.parent.row, column: self.name, timestamp: self.timestamp, items: []});
  self.drop = function(cont)
  {
    function doDrop()
    {
      self.parent.isLoading(true);
      return API.queryTable('deleteColumn', self.parent.row, self.name).done(function(data)
      {
        self.parent.items.remove(self);
        if(self.parent.items().length > 0)
          self.parent.reload(); //change later
        self.parent.isLoading(false);
      });
    }
    (cont === true) ? doDrop() : confirm("Confirm Delete", "Are you sure you want to drop this column?", doDrop);
  };

  self.reload = function(callback, skipPut)
  {
    self.isLoading(true);
    API.queryTable('get', self.parent.row, self.name, 'null').done(function(data)
    {
      if(data.length > 0 && !skipPut)
        self.value(data[0].value);
      callback();
      self.isLoading(false);
    });
  };

  self.value.subscribe(function(value)
  {
    //change transport prep to object wrapper
    logGA();
    API.queryTable('putColumn', self.parent.row, self.name, "hbase-post-key-" + value).done(function(data)
    {
      self.reload(function(){}, true);
    });
    self.editing(false);
  });

  self.editing = ko.observable(false);

  self.isLoading = ko.observable(false); //move to baseclass 
};

var SortDropDownView = function(options)
{
  var self = this;
  options = ko.utils.extend({
    sortFields: {},
    target: null
  }, options);
  BaseModel.apply(self,[options]);

  self.target = options.target;
  self.sortAsc = ko.observable(true);
  self.sortAsc.subscribe(function(){self.sort()});
  self.sortField = ko.observable("");
  self.sortField.subscribe(function(){self.sort()});
  self.sortFields = ko.observableArray(Object.keys(options.sortFields)); // change to ko.computed?
  self.sortFunctionHash = ko.observable(options.sortFields);
  self.toggleSortMode = function()
  {
    self.sortAsc(!self.sortAsc());
  };
  self.sort = function()
  {
    if (!self.target || !(self.sortFields().length > 0)) return;
    self.target.sort(function(a, b)
    {
      return (self.sortAsc() ? 1 : -1) * self.sortFunctionHash()[self.sortField() ? self.sortField() : self.sortFields()[0]](a,b); //all sort functions must sort by ASC for default
    });
  };
};

var TableDataRow = function(options)
{
  var self = this;
  options = ko.utils.extend({
    name:"",
    enabled:true
  }, options);
  DataRow.apply(self,[options]);

  self.name = options['name'];
  self.enabled = ko.observable(options['enabled']);
  self.toggle = function(viewModel,event){
    var action = ['enable','disable'][self.enabled() << 0], el = $(event.currentTarget);
    confirm("Confirm "+action, "Are you sure you want to " + action + " this table?", function() //gotta i18n this!
    {
      el.showIndicator();
      return self[action](el).complete(function()
      {
        el.hideIndicator();
      });
    });
  };
  self.enable = function(el)
  {
    return API.queryCluster('enableTable',self.name).complete(function()
    {
      self.enabled(true);
    });
  };
  self.disable = function(el)
  {
    return API.queryCluster('disableTable',self.name).complete(function()
    {
      self.enabled(false);
    });
  };
  self.drop = function(el)
  {
    return API.queryCluster('deleteTable',self.name);
  };
};

var QuerySetPeice = function(options)
{
  var self = this;
  options = ko.utils.extend({
    row_key: "null",
    scan_length: 1,
    prefix: false,
    columns: [],
    onValidate: function(){}
  }, options);
  BaseModel.apply(self,[options]);

  self.row_key = ko.observable(options.row_key);
  self.scan_length = ko.observable(options.scan_length);
  self.columns = ko.observableArray(options.columns);
  self.prefix = ko.observable(options.prefix);
  self.editing = ko.observable(true);

  self.validate = function()
  {
    if(self.scan_length() <= 0 || self.row_key() == "")
      return app.views.tabledata.querySet.remove(self); //change later
    return options.onValidate();
  };
  self.row_key.subscribe(self.validate.bind());
  self.scan_length.subscribe(self.validate.bind());
};

var ColumnFamily = function(options)
{
  this.name = options.name;
  this.enabled = ko.observable(options.enabled);
  this.toggle = function()
  {
    this.enabled(!this.enabled());
    app.views.tabledata.reload();
  };
}


//tagsearch
var tagsearch = function()
{
  var self = this;
  self.tags = ko.observableArray();
  self.mode = ko.observable('idle');
  self.cur_input = ko.observable('');
  self.hints = ko.observableArray([
    {
      hint: 'End Query',
      shortcut: ',',
      mode: ['rowkey', 'prefix', 'scan'],
      selected: false
    },
    {
      hint: 'Mark Row Prefix',
      shortcut: '*',
      mode: ['rowkey'],
      selected: false
    },
    {
      hint: 'Start Scan',
      shortcut: '+',
      mode: ['rowkey', 'prefix'],
      selected: false
    },
    {
      hint: 'Start Select Columns',
      shortcut: '[',
      mode: ['rowkey', 'prefix'],
      selected: false
    },
    {
      hint: 'End Column/Family',
      shortcut: ',',
      mode: ['columns'],
      selected: false
    },
    {
      hint: 'End Select Columns',
      shortcut: ']',
      mode: ['columns'],
      selected: false
    }
  ]);
  self.activeHints = ko.computed(function()
  {
    var ret = [];
    $(self.hints()).each(function(i, hint)
    {
      if (hint.mode.indexOf(self.mode()) > -1)
        ret.push(hint);
    });
    return ret;
  });
  self.activeHint = ko.observable(-1);
  self.modes =
  {
    'rowkey': {
      hint: 'Row Key Value',
      type: 'String'
    },
    'scan': {
      hint: 'Length of Scan or Row Key',
      type: 'Integer'
    },
    'columns': {
      hint: 'Column Family: Column Name',
      type: 'String'
    },
    'prefix': {
      hint: 'Rows starting with',
      type: 'String'
    }
  }

  self.modeQueue = ['idle'];
  self.focused = ko.observable(false);

  self.insertTag = function(tag)
  {
    var mode = tag.indexOf('+') != -1 ? 'scan' : 'rowkey';
    var tag = {value: tag, tag: mode} //parse mode
    self.tags.push(tag);
  }

  self.render = function(input, renderers)
  {
    var keys = Object.keys(renderers);
    for(var i=0; i<keys.length; i++)
    {
      input = input.replace(renderers[keys[i]].select, function(selected)
      {
        var hasMatched = false;
        var processed = selected.replace(renderers[keys[i]].tag, function(tagged)
        {
          hasMatched = true;
          return " <span class='" + keys[i] + " tagsearchTag' title='" + keys[i] + "' data-toggle='tooltip'>" + ('nested' in renderers[keys[i]] ? self.render(tagged, renderers[keys[i]].nested) : tagged).trim() + "</span> ";
        });
        if(hasMatched)
          processed = processed.replace(renderers[keys[i]].strip, '');
        return processed;
      });
    }
    return input;
  };


  self.updateMode = function(value)
  {
    var selection = value.slice(0, self.selectionEnd());
    var endindex = selection.slice(selection.lastIndexOf(',')).indexOf(',');
    if(endindex == -1) endindex = selection.length;
    var lastbit = value.substring(selection.lastIndexOf(','), endindex).trim();
    if(lastbit == "," || lastbit == "")
    {
      self.mode('idle');
      return;
    }
    var tokens = "[]+,-";
    var m = 'rowkey';
    for(var i=selection.length - 1; i>=0; i--)
    {
      if(tokens.indexOf(selection[i]) != -1)
      {
        if(selection[i] == '[')
          m = 'columns';
        else if(selection[i] == ']')
          m = 'rowkey';
        else if(selection[i] == '+')
          m = 'scan';
        else if(selection[i] == '-')
          m = 'prefix';
        break;
      }
    }
    self.mode(m.trim());
  };

  self.selectionStart = ko.observable(0);
  self.selectionEnd = ko.observable(0);

  self.renderedValue = ko.computed(function()
  {
    var pre = self.cur_input();
    var s = self.selectionStart(), e = self.selectionEnd();
    var indicator = (self.focused()) ? '<i class="tagIndicator">|</i>' : '';
    self.updateMode(self.cur_input());
    return self.render(pre.slice(0, e) + indicator + pre.slice(e), searchRenderers);
  });

  self.hintText = ko.computed(function()
  {
    var value = self.cur_input();
    var selection = value.slice(0, self.selectionEnd());
    var index = selection.lastIndexOf(',') + 1;
    var endindex = value.slice(index).indexOf(',');
    endindex = endindex == -1 ? value.length : endindex;
    var pre = value.substring(index, index + endindex);
    var s = self.selectionStart() - index, e = self.selectionEnd() - index;
    if(s == e)
      e += 1;
    s = s < 0 ? 0 : s;
    e = e > pre.length ? pre.length : e;
    return pre.slice(0, s) + "<span class='selection'>" + pre.slice(s, e) + "</span>" + pre.slice(e);
  });

  self.onKeyDown = function(target, ev)
  {
    self.selectionStart($('#tag-input')[0].selectionStart);
    self.selectionEnd($('#tag-input')[0].selectionEnd);
    if(ev.keyCode == 13 && self.cur_input().slice(self.cur_input().lastIndexOf(',')).trim() != ",")
    {
        self.evaluate();
    }
    return true;
  }

  self.evaluate = function()
  {
    app.views.tabledata.searchQuery(self.cur_input());
  }
};

var CellHistoryPage = function(options)
{
  var self = this;

  self.items = ko.observableArray(options.items);
  self.loading = ko.observable(false);

  self.reload = function(timestamp, append)
  {
    if(!timestamp)
      timestamp = options.timestamp
    API.queryTable("getVerTs", options.row, options.column, timestamp, 10, 'null').done(function(res)
    {
      self.loading = ko.observable(true);
      if(!append)
        self.items(res);
      else
        self.items(self.items() + res);
      self.loading = ko.observable(false);
    });
  };
};