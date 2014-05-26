## -*- coding: utf-8 -*-
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
  from oozie.utils import smart_path
%>


<%def name="render_dataset_instance(dataset)">
  % if dataset.instance_choice == 'default':
    <instance>${ '${'}coord:current(0)}</instance>
  % elif dataset.instance_choice == 'single':
    % if not dataset.is_advanced_start_instance:
      <instance>${ '${'}coord:current(${ dataset.start_instance })}</instance>
    % else:
      <instance>${ dataset.advanced_start_instance }</instance>
    % endif
  % else:
    <start-instance>
      % if not dataset.is_advanced_start_instance:
        ${ '${'}coord:current(${ dataset.start_instance })}
      % else:
        ${ dataset.advanced_start_instance }
      % endif
    </start-instance>
    <end-instance>
      % if not dataset.is_advanced_end_instance:
        ${ '${'}coord:current(${ dataset.end_instance })}
      % else:
        ${ dataset.advanced_end_instance }
      % endif
    </end-instance>
  % endif
</%def>


<coordinator-app name="${ coord.name }"
  frequency="${ coord.frequency }"
  start="${ coord.start_utc }" end="${ coord.end_utc }" timezone="${ coord.timezone }"
  xmlns="${ coord.schema_version }">
  % if coord.timeout or coord.concurrency or coord.execution or coord.throttle:
  <controls>
    % if coord.timeout:
    <timeout>${ coord.timeout }</timeout>
    % endif
    % if coord.concurrency:
    <concurrency>${ coord.concurrency }</concurrency>
    % endif
    % if coord.execution:
    <execution>${ coord.execution }</execution>
    % endif
    % if coord.throttle:
    <throttle>${ coord.throttle }</throttle>
    % endif
  </controls>
  % endif

  % if coord.dataset_set.exists():
  <datasets>
    % for dataset in coord.dataset_set.all():
    <dataset name="${ dataset.name }" frequency="${ dataset.frequency }"
             initial-instance="${ dataset.start_utc }" timezone="${ dataset.timezone }">
      <uri-template>${ smart_path(dataset.uri, mapping) }</uri-template>
      <done-flag>${ dataset.done_flag }</done-flag>
    </dataset>
    % endfor
  </datasets>
  % endif

  % if coord.datainput_set.exists():
  <input-events>
    % for input in coord.datainput_set.all():
    <data-in name="${ input.name }" dataset="${ input.dataset.name }">
      ${ render_dataset_instance(input.dataset) }
    </data-in>
    % endfor
  </input-events>
  % endif

  % if coord.dataoutput_set.exists():
  <output-events>
    % for output in coord.dataoutput_set.all():
    <data-out name="${ output.name }" dataset="${ output.dataset.name }">
      ${ render_dataset_instance(output.dataset) }
    </data-out>
    % endfor
  </output-events>
  % endif

  <action>
    <workflow>
      <app-path>${'${'}wf_application_path}</app-path>
      % if coord.datainput_set.exists() or coord.dataoutput_set.exists() or coord.get_properties():
      <configuration>
        % for input in coord.datainput_set.all():
          <property>
            <name>${ input.name }</name>
            <value>${'${'}coord:dataIn('${ input.name }')}</value>
          </property>
        % endfor
        % for output in coord.dataoutput_set.all():
        <property>
          <name>${ output.name }</name>
          <value>${'${'}coord:dataOut('${ output.name }')}</value>
        </property>
        % endfor
        % for property in coord.get_properties():
        <property>
          <name>${ property['name'] }</name>
          <value>${ property['value'] }</value>
        </property>
        % endfor
      </configuration>
      % endif
   </workflow>
  </action>
</coordinator-app>
