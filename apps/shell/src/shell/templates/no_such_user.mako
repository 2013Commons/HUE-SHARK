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

${ commonheader(_("Error"), "shell", user) | n,unicode }
<div class="container-fluid">
<div>
    <h3>${_('The Shell application requires a Unix user account for every user of Hue on the remote web server.')}</h3>
    <br/>
    ${_('Ask your administrator to create a user account for you on the remote web server as described in the Shell documentation.')}

</div>
</div>
${ commonfooter(messages) | n,unicode }
