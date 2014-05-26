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

<%namespace name="comps" file="beeswax_components.mako" />

${ commonheader(_('Create table from file'), 'metastore', user) | n,unicode }


<div class="container-fluid">
    <h1>${_('Create a new table from a file')}</h1>
    <div class="row-fluid">
        <div class="span3">
            <div class="well sidebar-nav">
                <ul class="nav nav-list">
                    <li class="nav-header">${_('Actions')}</li>
                    <li><a href="${ url(app_name + ':import_wizard', database=database)}">${_('Create a new table from a file')}</a></li>
                    <li><a href="${ url(app_name + ':create_table', database=database)}">${_('Create a new table manually')}</a></li>
                </ul>
            </div>
        </div>
        <div class="span9">
            <ul class="nav nav-pills">
                <li class="active"><a href="${ url(app_name + ':import_wizard', database=database) }">${_('Step 1: Choose File')}</a></li>
                <li><a id="step2" href="#">${_('Step 2: Choose Delimiter')}</a></li>
                <li><a href="#">${_('Step 3: Define Columns')}</a></li>
            </ul>
            <form action="${action}" method="POST" class="form-horizontal">
                <fieldset>
                    <div class="alert alert-info"><h3>${_('Name Your Table and Choose A File')}</h3></div>
                    <div class="control-group">
                        ${comps.bootstrapLabel(file_form["name"])}
                        <div class="controls">
                            ${comps.field(file_form["name"], placeholder=_('table_name'), show_errors=False)}
                            <span  class="help-inline">${unicode(file_form["name"].errors) | n}</span>
                        <span class="help-block">
                            ${_('Name of the new table. Table names must be globally unique. Table names tend to correspond as well to the directory where the data will be stored.')}
                        </span>
                        </div>
                    </div>
                    <div class="control-group">
                        ${comps.bootstrapLabel(file_form["comment"])}
                        <div class="controls">
                            ${comps.field(file_form["comment"],
                            placeholder=_("Optional"),
                            klass="",
                            show_errors=False
                            )}
                            <span  class="help-inline">${unicode(file_form["comment"].errors) | n}</span>
                        <span class="help-block">
                        ${_("Use a table comment to describe your table.  For example, you might note the data's provenance and any caveats users need to know.")}
                        </span>
                        </div>
                    </div>
                    <div class="control-group">
                        ${comps.bootstrapLabel(file_form["path"])}
                        <div class="controls">
                            ${comps.field(file_form["path"],
                            placeholder="/user/user_name/data_dir",
                            klass="pathChooser input-xxlarge",
                            file_chooser=True,
                            show_errors=False
                            )}
                            <span  class="help-inline">${unicode(file_form["path"].errors) | n}</span>
                        <span class="help-block">
                        ${_('The HDFS path to the file that you would like to base this new table definition on. It can be compressed (gzip) or not.')}
                        </span>
                        </div>
                    </div>
                    <div class="control-group">
                        ${comps.bootstrapLabel(file_form["do_import"])}
                        <div class="controls">
                            ${comps.field(file_form["do_import"], render_default=True)}
                            <span class="help-block">
                        ${_('Check this box if you want to import the data in this file after creating the table definition. Leave it unchecked if you want to define an empty table.')}
                        <div id="fileWillBeMoved" class="alert">
                            <strong>${_('Warning!')}</strong> ${_('The selected file is going to be moved during the import.')}
                        </div>
                        </span>
                        </div>
                    </div>
                </fieldset>
                <div class="form-actions">
                    <input type="submit" class="btn btn-primary" name="submit_file" value="${_('Next')}" />
                </div>
            </form>
        </div>
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


<style>
    #filechooser {
        min-height: 100px;
        overflow-y: scroll;
        margin-top: 10px;
    }

    #fileWillBeMoved {
        margin-top: 10px;
    }
</style>


<script type="text/javascript" charset="utf-8">
    $(document).ready(function(){
        $(".fileChooserBtn").click(function(e){
            e.preventDefault();
            var _destination = $(this).attr("data-filechooser-destination");
            $("#filechooser").jHueFileChooser({
                initialPath: $("input[name='"+_destination+"']").val(),
                onFileChoose: function(filePath){
                    $("input[name='"+_destination+"']").val(filePath);
                    $("#chooseFile").modal("hide");
                },
                createFolder: false
            });
            $("#chooseFile").modal("show");
        });
        $("#id_do_import").change(function(){
            if ($(this).is(":checked")){
                $("#fileWillBeMoved").show();
            }
            else {
                $("#fileWillBeMoved").hide();
            }
        });
        $("#step2").click(function(e){
            e.preventDefault();
            $("input[name='submit_file']").click();
        });
        $("body").keypress(function(e){
            if(e.which == 13){
                e.preventDefault();
                $("input[name='submit_file']").click();
            }
        });
    });
</script>

${ commonfooter(messages) | n,unicode }
