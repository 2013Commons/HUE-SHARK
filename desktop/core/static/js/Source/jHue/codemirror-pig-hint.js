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

(function () {
  function forEach(arr, f) {
    for (var i = 0, e = arr.length; i < e; ++i) f(arr[i]);
  }

  function arrayContains(arr, item) {
    if (!Array.prototype.indexOf) {
      var i = arr.length;
      while (i--) {
        if (arr[i] === item) {
          return true;
        }
      }
      return false;
    }
    return arr.indexOf(item) != -1;
  }

  function scriptHint(editor, _keywords, getToken) {
    // Find the token at the cursor
    var cur = editor.getCursor(), token = getToken(editor, cur), tprop = token;
    // If it's not a 'word-style' token, ignore the token.

    if (token.string.indexOf("'") == 0){
      CodeMirror.isPath = true;
      token.string = token.string.substring(1, token.string.length);
    }
    if (token.string.indexOf("/") > -1){
      token.string = token.string.substring(token.string.lastIndexOf("/") + 1);
    }

    if (!/^[\w$_]*$/.test(token.string)) {
      token = tprop = {start: cur.ch, end: cur.ch, string: "", state: token.state,
        className: token.string == ":" ? "pig-type" : null};
    }

    if (!context) var context = [];
    context.push(tprop);

    var completionList = getCompletions(token, context);
    //prevent autocomplete for last word, instead show dropdown with one word
    if (completionList.length == 1) {
      completionList.push(" ");
    }

    return {list: completionList,
      from: CodeMirror.Pos(cur.line, token.start),
      to: CodeMirror.Pos(cur.line, token.end)};
  }

  CodeMirror.isPath = false;
  CodeMirror.currentFiles = [];

  CodeMirror.pigHint = function (editor) {
    return scriptHint(editor, pigCaseInsensitive, function (e, cur) {
      return e.getTokenAt(cur);
    });
  };

  var pigCaseInsensitive = "and any all arrange as asc bag by bytearray boolean cache cat cd chararray cogroup cp cross " +
      "datetime %declare %default define desc describe distinct double du dump e eval exec explain f filter " +
      "flatten float foreach full generate group help if illustrate import inner input int into is join kill" +
      "l left limit load long ls map matches mkdir mv not null onschema or order outer output parallel pig pwd" +
      "quit register right rm rmf run sample set ship split stderr stdin stdout store stream through tuple union using";

  var pigCaseInsensitiveU = pigCaseInsensitive.toUpperCase().split(" ");
  var pigCaseInsensitiveL = pigCaseInsensitive.toLowerCase().split(" ");

  var pigCaseSensitive = "AVG BinStorage CONCAT copyFromLocal copyToLocal COUNT DIFF MAX MIN  PigDump PigStorage SIZE SUM TextLoader TOKENIZE".split(" ");

  function getCompletions(token, context) {
    var found = [], start = token.string, extraFound = [];

    function maybeAdd(str) {
      var stripped = strip(str).replace(/(?:(?:^|\n)\s+|\s+(?:$|\n))/g,'').replace(/\s+/g,' ');
      if (stripped.toLowerCase().indexOf(start.toLowerCase()) == 0 && !arrayContains(found, str)) found.push(str);
    }

    function maybeAddToExtra(str) {
      if (str.toLowerCase().indexOf(start.toLowerCase()) == 0 && !arrayContains(found, str)) extraFound.push(str);
    }

    function strip(html){
      var tmp = document.createElement("DIV");
      tmp.innerHTML = html;
      return tmp.textContent||tmp.innerText;
    }

    function gatherCompletions(obj) {
      if (CodeMirror.isPath || obj.indexOf("'") == 0){
        forEach(CodeMirror.currentFiles, maybeAdd);
      }
      else {
        forEach(pigCaseInsensitiveU, maybeAdd);
        forEach(pigCaseInsensitiveL, maybeAdd);
        forEach(pigCaseSensitive, maybeAdd);
        forEach(CodeMirror.availableVariables, maybeAddToExtra);
      }
    }

    if (context) {
      // If this is a property, see if it belongs to some object we can
      // find in the current environment.
      var obj = context.pop(), base;
      base = obj.string;

      while (base != null && context.length)
        base = base[context.pop().string];
      if (base != null) gatherCompletions(base);
    }
    return extraFound.sort().concat(found.sort());
  }
})();
