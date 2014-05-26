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
%>
${ commonheader("Hue Help", "help", user, "100px") | n,unicode }

<style type="text/css">
  .nav-pills li a {
    font-size: 13px;
  }
</style>

	<div class="subnav subnav-fixed">
		<div class="container-fluid">
		<ul class="nav nav-pills">
			% for app in apps:
				<li><a href="${url("help.views.view", app=app.name, path="/")}">${app.nice_name}</a></li>
			% endfor
		</ul>
		</div>
	</div>
	<div class="container-fluid">
		${content|n}
	</div>

  <script>
    $(document).ready(function () {
      $.jHueScrollUp();

      resizeSubnav();

      var resizeTimeout = -1;
      var winWidth = $(window).width();
      var winHeight = $(window).height();

      $(window).on("resize", function () {
        window.clearTimeout(resizeTimeout);
        resizeTimeout = window.setTimeout(function () {
          // prevents endless loop in IE8
          if (winWidth != $(window).width() || winHeight != $(window).height()) {
            resizeSubnav();
            winWidth = $(window).width();
            winHeight = $(window).height();
          }
        }, 200);
      });

      function resizeSubnav(){
        $(".subnav").height($(".nav-pills").outerHeight());
      }
    });
  </script>

${ commonfooter(messages) | n,unicode }
