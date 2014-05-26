#!/usr/bin/env python
# Licensed to Cloudera, Inc. under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  Cloudera, Inc. licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

try:
    import json
except ImportError:
    import simplejson as json
import logging
import re
import time
import unittest

from django.contrib.auth.models import User
from django.core.urlresolvers import reverse
from nose.tools import assert_true, assert_false, assert_equal

from desktop.lib.django_test_util import make_logged_in_client
from desktop.lib.test_utils import grant_access
from hadoop import cluster
from hadoop.conf import YARN_CLUSTERS
from hadoop.yarn import resource_manager_api, mapreduce_api, history_server_api
from liboozie.oozie_api_test import OozieServerProvider
from oozie.models import Workflow

from jobbrowser import models, views
from jobbrowser.conf import SHARE_JOBS


LOG = logging.getLogger(__name__)
_INITIALIZED = False

def test_dots_to_camel_case():
  assert_equal("fooBar", models.dots_to_camel_case("foo.bar"))
  assert_equal("fooBarBaz", models.dots_to_camel_case("foo.bar.baz"))
  assert_equal("foo", models.dots_to_camel_case("foo"))
  assert_equal("foo.", models.dots_to_camel_case("foo."))

def test_get_path():
  assert_equal("/foo/bar", models.get_path("hdfs://host/foo/bar"))

def test_format_counter_name():
  assert_equal("Foo Bar", views.format_counter_name("fooBar"))
  assert_equal("Foo Bar Baz", views.format_counter_name("fooBarBaz"))
  assert_equal("Foo", views.format_counter_name("foo"))
  assert_equal("Foo.", views.format_counter_name("foo."))
  assert_equal("A Bbb Ccc", views.format_counter_name("A_BBB_CCC"))\

def get_hadoop_job_id(oozie_api, oozie_jobid, action_index=1, timeout=60, step=5):
  hadoop_job_id = None
  start = time.time()
  while not hadoop_job_id and time.time() - start < timeout:
    time.sleep(step)
    hadoop_job_id = oozie_api.get_job(oozie_jobid).actions[action_index].externalId
  if not hadoop_job_id:
    logs = OozieServerProvider.oozie.get_job_log(oozie_jobid)
    msg = "[%d] %s took more than %d to create a job: %s" % (time.time(), oozie_jobid, timeout, logs)
    LOG.info(msg)
    raise Exception(msg)
  return hadoop_job_id


class TestJobBrowserWithHadoop(unittest.TestCase, OozieServerProvider):
  """
  Tests for JobBrowser that requires Hadoop. Use the same mini_cluster and jobsubd.
  """
  requires_hadoop = True
  user_count = 0

  @classmethod
  def setup_class(cls):
    OozieServerProvider.setup_class()
    if not cls.cluster.fs.exists("/tmp"):
      cls.cluster.fs.do_as_superuser(cls.cluster.fs.mkdir, "/tmp")
    cls.cluster.fs.do_as_superuser(cls.cluster.fs.chmod, "/tmp", 0777)



  def setUp(self):
    TestJobBrowserWithHadoop.user_count += 1
    self.username = 'test' + str(TestJobBrowserWithHadoop.user_count)
    self.home_dir = '/user/%s' % self.username

    self.cluster.fs.do_as_user(self.username, self.cluster.fs.create_home_dir, self.home_dir)
    self.cluster.fs.do_as_superuser(self.cluster.fs.chmod, self.home_dir, 0777, True)
    self.cluster.fs.do_as_superuser(self.cluster.fs.chown, self.home_dir, self.username, "test", recursive=True)

    self.client = make_logged_in_client(username=self.username, is_superuser=False, groupname='test')
    grant_access(self.username, 'test', 'jobsub')
    grant_access(self.username, 'test', 'jobbrowser')
    grant_access(self.username, 'test', 'oozie')

    # Ensure access to MR folder
    self.cluster.fs.do_as_superuser(self.cluster.fs.chmod, '/tmp', 0777, recursive=True)

    self.cluster.fs.setuser(self.username)

    self.install_examples()
    self.design = self.create_design()

  def tearDown(self):
    try:
      Workflow.objects.all().delete()
      # Remove user home directories.
      self.cluster.fs.do_as_superuser(self.cluster.fs.rmtree, self.home_dir)
    except:
      pass

  def create_design(self):
    response = self.client.post(reverse('jobsub.views.new_design',
      kwargs={'node_type': 'mapreduce'}),
      data={'name': 'sleep_job',
            'description': '',
            'node_type': 'mapreduce',
            'jar_path': '/user/hue/oozie/workspaces/lib/hadoop-examples.jar',
            'prepares': '[]',
            'files': '[]',
            'archives': '[]',
            'job_properties': '[{\"name\":\"mapred.reduce.tasks\",\"value\":\"1\"},{\"name\":\"mapred.mapper.class\",\"value\":\"org.apache.hadoop.examples.SleepJob\"},{\"name\":\"mapred.reducer.class\",\"value\":\"org.apache.hadoop.examples.SleepJob\"},{\"name\":\"mapred.mapoutput.key.class\",\"value\":\"org.apache.hadoop.io.IntWritable\"},{\"name\":\"mapred.mapoutput.value.class\",\"value\":\"org.apache.hadoop.io.NullWritable\"},{\"name\":\"mapred.output.format.class\",\"value\":\"org.apache.hadoop.mapred.lib.NullOutputFormat\"},{\"name\":\"mapred.input.format.class\",\"value\":\"org.apache.hadoop.examples.SleepJob$SleepInputFormat\"},{\"name\":\"mapred.partitioner.class\",\"value\":\"org.apache.hadoop.examples.SleepJob\"},{\"name\":\"mapred.speculative.execution\",\"value\":\"false\"},{\"name\":\"sleep.job.map.sleep.time\",\"value\":\"0\"},{\"name\":\"sleep.job.reduce.sleep.time\",\"value\":\"${REDUCER_SLEEP_TIME}\"}]'},
      HTTP_X_REQUESTED_WITH='XMLHttpRequest')
    assert_equal(response.status_code, 200)
    return Workflow.objects.all()[0]

  def install_examples(self):
    global _INITIALIZED
    if _INITIALIZED:
      return

    self.client.post(reverse('oozie:install_examples'))
    self.cluster.fs.do_as_user(self.username, self.cluster.fs.create_home_dir, self.home_dir)
    self.cluster.fs.do_as_superuser(self.cluster.fs.chmod, self.home_dir, 0777, True)
    hue = User.objects.create_user('hue', 'hue' + '@localhost', 'hue')
    Workflow.objects.update(owner=hue)

    _INITIALIZED = True

  def test_uncommon_views(self):
    """
    These views exist, but tend not to be ever called,
    because they're not in the normal UI.
    """
    # None of these should raise
    self.client.get("/jobbrowser/clusterstatus")
    self.client.get("/jobbrowser/queues")
    self.client.get("/jobbrowser/jobbrowser")

  def test_failed_jobs(self):
    """
    Test jobs with genuine failure, not just killed
    """
    # Create design that will fail because the script file isn't there
    INPUT_DIR = self.home_dir + '/input'
    OUTPUT_DIR = self.home_dir + '/output'
    try:
        self.cluster.fs.mkdir(self.home_dir + "/jt-test_failed_jobs")
        self.cluster.fs.mkdir(INPUT_DIR)
        self.cluster.fs.rmtree(OUTPUT_DIR)
    except:
        # rmtree probably failed here.
        pass
    response = self.client.post(reverse('jobsub.views.new_design', kwargs={'node_type': 'mapreduce'}), {
        'name': ['test_failed_jobs-1'],
        'description': ['description test_failed_jobs-1'],
        'args': '',
        'jar_path': '/user/hue/oozie/workspaces/lib/hadoop-examples.jar',
        'prepares': '[]',
        'archives': '[]',
        'files': '[]',
        'job_properties': ['[{"name":"mapred.input.dir","value":"%s"},\
            {"name":"mapred.output.dir","value":"%s"},\
            {"name":"mapred.mapper.class","value":"org.apache.hadoop.mapred.lib.dne"},\
            {"name":"mapred.combiner.class","value":"org.apache.hadoop.mapred.lib.dne"},\
            {"name":"mapred.reducer.class","value":"org.apache.hadoop.mapred.lib.dne"}]' % (INPUT_DIR, OUTPUT_DIR)]
        }, HTTP_X_REQUESTED_WITH='XMLHttpRequest', follow=True)

    # Submit the job
    design_dict = json.loads(response.content)
    design_id = int(design_dict['id'])
    response = self.client.post(reverse('oozie:submit_workflow',
                                args=[design_id]),
                                data={u'form-MAX_NUM_FORMS': [u''],
                                      u'form-INITIAL_FORMS': [u'1'],
                                      u'form-0-name': [u'REDUCER_SLEEP_TIME'],
                                      u'form-0-value': [u'1'],
                                      u'form-TOTAL_FORMS': [u'1']},
                                follow=True)
    oozie_jobid = response.context['oozie_workflow'].id
    job = OozieServerProvider.wait_until_completion(oozie_jobid, timeout=120, step=1)
    hadoop_job_id = get_hadoop_job_id(self.oozie, oozie_jobid, 1)
    hadoop_job_id_short = views.get_shorter_id(hadoop_job_id)

    # Select only killed jobs (should be absent)
    # Taking advantage of the fact new jobs are at the top of the list!
    response = self.client.get('/jobbrowser/jobs/?format=json&state=killed')
    assert_false(hadoop_job_id_short in response.content)

    # Select only failed jobs (should be present)
    # Map job should succeed. Reduce job should fail.
    response = self.client.get('/jobbrowser/jobs/?format=json&state=failed')
    assert_true(hadoop_job_id_short in response.content)

    # The single job view should have the failed task table
    response = self.client.get('/jobbrowser/jobs/%s' % (hadoop_job_id,))
    html = response.content.lower()
    assert_true('failed task' in html)

    # The map task should say success (empty input)
    map_task_id = hadoop_job_id.replace('job', 'task') + '_m_000000'
    response = self.client.get('/jobbrowser/jobs/%s/tasks/%s' % (hadoop_job_id, map_task_id))
    assert_true('succeed' in response.content)
    assert_true('failed' not in response.content)

    # The reduce task should say failed
    reduce_task_id = hadoop_job_id.replace('job', 'task') + '_r_000000'
    response = self.client.get('/jobbrowser/jobs/%s/tasks/%s' % (hadoop_job_id, reduce_task_id))
    assert_true('succeed' not in response.content)
    assert_true('failed' in response.content)

    # Selecting by failed state should include the failed map
    response = self.client.get('/jobbrowser/jobs/%s/tasks?taskstate=failed' % (hadoop_job_id,))
    assert_true('r_000000' in response.content)
    assert_true('m_000000' not in response.content)

  def test_kill_job(self):
    """
    Test job in kill state.
    """
    # Run the sleep example, since it doesn't require user home directory
    design_id = self.design.id
    response = self.client.post(reverse('oozie:submit_workflow',
                                args=[self.design.id]),
                                data={u'form-MAX_NUM_FORMS': [u''],
                                      u'form-INITIAL_FORMS': [u'1'],
                                      u'form-0-name': [u'REDUCER_SLEEP_TIME'],
                                      u'form-0-value': [u'1'],
                                      u'form-TOTAL_FORMS': [u'1']},
                                follow=True)
    oozie_jobid = response.context['oozie_workflow'].id

    # Wait for a job to be created and fetch job ID
    hadoop_job_id = get_hadoop_job_id(self.oozie, oozie_jobid, 1)

    client2 = make_logged_in_client('test_non_superuser', is_superuser=False, groupname='test')
    grant_access('test_non_superuser', 'test', 'jobbrowser')
    response = client2.post('/jobbrowser/jobs/%s/kill' % (hadoop_job_id,))
    assert_equal("Permission denied.  User test_non_superuser cannot delete user %s's job." % self.username, response.context["error"])

    # Make sure that the first map task succeeds before moving on
    # This will keep us from hitting timing-related failures
    first_mapper = 'm_000000'
    start = time.time()
    timeout_sec = 60
    while first_mapper not in \
        self.client.get('/jobbrowser/jobs/%s/tasks?taskstate=succeeded' % (hadoop_job_id,)).content:
      time.sleep(1)
      # If this assert fails, something has probably really failed
      assert_true(time.time() - start < timeout_sec,
          "Timed out waiting for first mapper to complete")

    # Kill task
    self.client.post('/jobbrowser/jobs/%s/kill' % (hadoop_job_id,))

    # It should say killed at some point
    response = self.client.get('/jobbrowser/jobs/%s?format=json' % (hadoop_job_id,))
    html = response.content.lower()
    i = 0
    while 'killed' not in html and i < 10:
      time.sleep(5)
      response = self.client.get('/jobbrowser/jobs/%s?format=json' % (hadoop_job_id,))
      html = response.content.lower()
      i += 1

    assert_true(views.get_shorter_id(hadoop_job_id) in html)
    assert_true('killed' in html, html)

    # Exercise select by taskstate
    self.client.get('/jobbrowser/jobs/%s/tasks?taskstate=failed' % (hadoop_job_id,))
    self.client.get('/jobbrowser/jobs/%s/tasks?taskstate=succeeded' % (hadoop_job_id,))
    self.client.get('/jobbrowser/jobs/%s/tasks?taskstate=running' % (hadoop_job_id,))
    self.client.get('/jobbrowser/jobs/%s/tasks?taskstate=killed' % (hadoop_job_id,))

    # Test single task page
    late_task_id = hadoop_job_id.replace('job', 'task') + '_r_000000'
    response = self.client.get('/jobbrowser/jobs/%s/tasks/%s' % (hadoop_job_id, late_task_id))
    assert_false('succeed' in response.content)
    assert_true('killed' in response.content)

    # The first task should've succeeded
    # We use a different method of checking success for this one
    early_task_id = hadoop_job_id.replace('job', 'task') + '_m_000000'
    response = self.client.get('/jobbrowser/jobs/%s/tasks/%s' % (hadoop_job_id, early_task_id))
    assert_true('succeed' in response.content)
    assert_false('failed' in response.content)

    # Test single attempt page
    early_task_id = hadoop_job_id.replace('job', 'task') + '_m_000000'
    attempt_id = early_task_id.replace('task', 'attempt') + '_0'
    response = self.client.get('/jobbrowser/jobs/%s/tasks/%s/attempts/%s/logs' %
                          (hadoop_job_id, early_task_id, attempt_id))
    assert_true('syslog' in response.content)

    # Test dock jobs
    response = self.client.get('/jobbrowser/dock_jobs/')
    assert_false('completed' in response.content)
    assert_false('failed' in response.content)

  def test_job(self):
    """
    Test new job views.

    The status of the jobs should be the same as the status reported back by oozie.
    In this case, all jobs should succeed.
    """
    # Run the sleep example, since it doesn't require user home directory
    design_id = self.design.id
    response = self.client.post(reverse('oozie:submit_workflow',
                                args=[design_id]),
                                data={u'form-MAX_NUM_FORMS': [u''],
                                      u'form-INITIAL_FORMS': [u'1'],
                                      u'form-0-name': [u'REDUCER_SLEEP_TIME'],
                                      u'form-0-value': [u'1'],
                                      u'form-TOTAL_FORMS': [u'1']},
                                follow=True)
    oozie_jobid = response.context['oozie_workflow'].id
    OozieServerProvider.wait_until_completion(oozie_jobid, timeout=120, step=1)
    hadoop_job_id = get_hadoop_job_id(self.oozie, oozie_jobid, 1)
    hadoop_job_id_short = views.get_shorter_id(hadoop_job_id)

    # All jobs page and fetch job ID
    # Taking advantage of the fact new jobs are at the top of the list!
    response = self.client.get('/jobbrowser/jobs/?format=json')
    assert_true(hadoop_job_id_short in response.content, response.content)

    # Make sure job succeeded
    response = self.client.get('/jobbrowser/jobs/?format=json&state=completed')
    assert_true(hadoop_job_id_short in response.content)
    response = self.client.get('/jobbrowser/jobs/?format=json&state=failed')
    assert_false(hadoop_job_id_short in response.content)
    response = self.client.get('/jobbrowser/jobs/?format=json&state=running')
    assert_false(hadoop_job_id_short in response.content)
    response = self.client.get('/jobbrowser/jobs/?format=json&state=killed')
    assert_false(hadoop_job_id_short in response.content)

    # Test tracker page
    early_task_id = hadoop_job_id.replace('job', 'task') + '_m_000000'
    response = self.client.get('/jobbrowser/jobs/%s/tasks/%s' % (hadoop_job_id, early_task_id))

    tracker_url = re.search('<a href="(/jobbrowser/trackers/.+?)"', response.content).group(1)
    response = self.client.get(tracker_url)
    assert_true('Tracker at' in response.content)

    # Check sharing permissions
    # Login as ourself
    finish = SHARE_JOBS.set_for_testing(True)
    try:
      response = self.client.get('/jobbrowser/jobs/?format=json&user=')
      assert_true(hadoop_job_id_short in response.content)
    finally:
      finish()

    finish = SHARE_JOBS.set_for_testing(False)
    try:
      response = self.client.get('/jobbrowser/jobs/?format=json&user=')
      assert_true(hadoop_job_id_short in response.content)
    finally:
      finish()

    # Login as someone else
    client_not_me = make_logged_in_client(username='not_me', is_superuser=False, groupname='test')
    grant_access("not_me", "test", "jobbrowser")

    finish = SHARE_JOBS.set_for_testing(True)
    try:
      response = client_not_me.get('/jobbrowser/jobs/?format=json&user=')
      assert_true(hadoop_job_id_short in response.content)
    finally:
      finish()

    finish = SHARE_JOBS.set_for_testing(False)
    try:
      response = client_not_me.get('/jobbrowser/jobs/?format=json&user=')
      assert_false(hadoop_job_id_short in response.content)
    finally:
      finish()

    # Single job page
    response = self.client.get('/jobbrowser/jobs/%s' % hadoop_job_id)

    # Check some counters for single job.
    counters = response.context['job'].counters
    counters_file_bytes_written = counters['org.apache.hadoop.mapreduce.FileSystemCounter']['counters']['FILE_BYTES_WRITTEN']
    assert_true(counters_file_bytes_written['map'] > 0)
    assert_true(counters_file_bytes_written['reduce'] > 0)

    # We can't just check the complete contents of the python map because the
    # SLOTS_MILLIS_* entries have a variable number of milliseconds from
    # run-to-run.
    assert_equal(response.context['job'].counters['org.apache.hadoop.mapreduce.JobCounter']['counters']['TOTAL_LAUNCHED_MAPS']['total'], 2L)
    assert_equal(response.context['job'].counters['org.apache.hadoop.mapreduce.JobCounter']['counters']['TOTAL_LAUNCHED_REDUCES']['total'], 1L)
    assert_equal(response.context['job'].counters['org.apache.hadoop.mapreduce.JobCounter']['counters']['FALLOW_SLOTS_MILLIS_MAPS']['total'], 0L)
    assert_equal(response.context['job'].counters['org.apache.hadoop.mapreduce.JobCounter']['counters']['FALLOW_SLOTS_MILLIS_REDUCES']['total'], 0L)
    assert_true(response.context['job'].counters['org.apache.hadoop.mapreduce.JobCounter']['counters']['SLOTS_MILLIS_MAPS']['total'] > 0)
    assert_true(response.context['job'].counters['org.apache.hadoop.mapreduce.JobCounter']['counters']['SLOTS_MILLIS_REDUCES']['total'] > 0)

    # There should be 4 tasks for this job: cleanup, setup, map, reduce
    response = self.client.get('/jobbrowser/jobs/%s/tasks' % (hadoop_job_id,))
    assert_true(len(response.context['page'].object_list), 4)
    # Select by tasktype
    response = self.client.get('/jobbrowser/jobs/%s/tasks?tasktype=reduce' % (hadoop_job_id,))
    assert_true(len(response.context['page'].object_list), 1)
    # Select by taskstate
    response = self.client.get('/jobbrowser/jobs/%s/tasks?taskstate=succeeded' % (hadoop_job_id,))
    assert_true(len(response.context['page'].object_list), 4)
    # Select by text
    response = self.client.get('/jobbrowser/jobs/%s/tasks?tasktext=clean' % (hadoop_job_id,))
    assert_true(len(response.context['page'].object_list), 1)

    # Test job single logs page
    response = self.client.get('/jobbrowser/jobs/%s/single_logs' % (hadoop_job_id))
    assert_true('syslog' in response.content)
    assert_true('<div class="tab-pane active" id="logsSysLog">' in response.content or
                '<div class="tab-pane active" id="logsStdErr">' in response.content or # Depending on Hadoop
                '<div class="tab-pane active" id="logsStdOut">' in response.content, # For jenkins
                response.content)


class TestMapReduce2:

  def setUp(self):
    # Beware: Monkey patching
    if not hasattr(resource_manager_api, 'old_get_resource_manager_api'):
      resource_manager_api.old_get_resource_manager = resource_manager_api.get_resource_manager
    if not hasattr(resource_manager_api, 'old_get_mapreduce_api'):
      mapreduce_api.old_get_mapreduce_api = mapreduce_api.get_mapreduce_api
    if not hasattr(history_server_api, 'old_get_history_server_api'):
      history_server_api.old_get_history_server_api = history_server_api.get_history_server_api

    resource_manager_api.get_resource_manager = lambda: MockResourceManagerApi()
    mapreduce_api.get_mapreduce_api = lambda: MockMapreduceApi()
    history_server_api.get_history_server_api = lambda: HistoryServerApi()


    self.c = make_logged_in_client(is_superuser=False)
    grant_access("test", "test", "jobbrowser")

    self.finish = YARN_CLUSTERS['default'].SUBMIT_TO.set_for_testing(True)
    assert_true(cluster.is_yarn())

  def tearDown(self):
    resource_manager_api.get_resource_manager = getattr(resource_manager_api, 'old_get_resource_manager')
    mapreduce_api.get_mapreduce_api = getattr(mapreduce_api, 'old_get_mapreduce_api')
    history_server_api.get_history_server_api = getattr(history_server_api, 'old_get_history_server_api')

    self.finish()


  def test_jobs(self):
    response = self.c.get('/jobbrowser/?format=json')
    assert_equal(len(json.loads(response.content)), 2)

    # state=running comes from the API and so can't be mocked

    response = self.c.get('/jobbrowser/jobs/?format=json&text=W=MapReduce-copy2')
    assert_equal(len(json.loads(response.content)), 1)

  def test_running_job(self):
    response = self.c.get('/jobbrowser/jobs/application_1356251510842_0054')
    assert_equal(response.context['job'].jobId, 'job_1356251510842_0054')

    response = self.c.get('/jobbrowser/jobs/job_1356251510842_0054')
    assert_false('job' in response.context)

  def test_finished_job(self):
    response = self.c.get('/jobbrowser/jobs/application_1356251510842_0009')
    assert_equal(response.context['job'].jobId, 'job_1356251510842_0009')

    response = self.c.get('/jobbrowser/jobs/job_1356251510842_0009')
    assert_equal(response.context['job'].jobId, 'job_1356251510842_0009')


class MockResourceManagerApi:
  APPS = {
    'application_1356251510842_0054': {u'finishedTime': 1356961070119, u'name': u'oozie:launcher:T=map-reduce:W=MapReduce-copy:A=Sleep:ID=0000004-121223003201296-oozie-oozi-W',
    u'amContainerLogs': u'http://runreal:8042/node/containerlogs/container_1356251510842_0054_01_000001/romain', u'clusterId': 1356251510842,
    u'trackingUrl': u'http://localhost:8088/proxy/application_1356251510842_0054/jobhistory/job/job_1356251510842_0054', u'amHostHttpAddress': u'runreal:8042',
    u'startedTime': 1356961057225, u'queue': u'default', u'state': u'RUNNING', u'elapsedTime': 12894, u'finalStatus': u'UNDEFINED', u'diagnostics': u'',
    u'progress': 100.0, u'trackingUI': u'History', u'id': u'application_1356251510842_0054', u'user': u'romain'},
  'application_1356251510842_0009': {u'finishedTime': 1356467118570, u'name': u'oozie:action:T=map-reduce:W=MapReduce-copy2:A=Sleep:ID=0000002-121223003201296-oozie-oozi-W',
    u'amContainerLogs': u'http://runreal:8042/node/containerlogs/container_1356251510842_0009_01_000001/romain', u'clusterId': 1356251510842,
    u'trackingUrl': u'http://localhost:8088/proxy/application_1356251510842_0009/jobhistory/job/job_1356251510842_0009', u'amHostHttpAddress': u'runreal:8042',
    u'startedTime': 1356467081121, u'queue': u'default', u'state': u'FINISHED', u'elapsedTime': 37449, u'finalStatus': u'SUCCEEDED', u'diagnostics': u'',
    u'progress': 100.0, u'trackingUI': u'History', u'id': u'application_1356251510842_0009', u'user': u'romain'}
  }

  def __init__(self, oozie_url=None): pass

  def apps(self, **kwargs):
    return {
     'apps': {
       'app': [
         # RUNNING
         MockResourceManagerApi.APPS['application_1356251510842_0054'],
         # FINISHED
         MockResourceManagerApi.APPS['application_1356251510842_0009'],
        ]
      }
    }

  def app(self, job_id):
    return {
      u'app': MockResourceManagerApi.APPS[job_id]
    }


class MockMapreduce2Api(object):
  """
  MockMapreduceApi and HistoryServerApi are very similar and inherit from it.
  """

  def __init__(self, oozie_url=None): pass

  def tasks(self, job_id):
    return {u'tasks': {u'task': [{u'finishTime': 1357153330271, u'successfulAttempt': u'attempt_1356251510842_0062_m_000000_0', u'elapsedTime': 1901, u'state': u'SUCCEEDED',
                                  u'startTime': 1357153328370, u'progress': 100.0, u'type': u'MAP', u'id': u'task_1356251510842_0062_m_000000'},
                                 {u'finishTime': 0, u'successfulAttempt': u'', u'elapsedTime': 0, u'state': u'SCHEDULED', u'startTime': 1357153326322, u'progress': 0.0,
                                  u'type': u'REDUCE', u'id': u'task_1356251510842_0062_r_000000'}]}}
  def conf(self, job_id):
    return {
      "conf" : {
        "path" : "hdfs://host.domain.com:9000/user/user1/.staging/job_1326232085508_0004/job.xml",
        "property" : [
           {
              "value" : "/home/hadoop/hdfs/data",
              "name" : "dfs.datanode.data.dir"
           },]
         }
    }

  def job_attempts(self, job_id):
    return {
       "jobAttempts" : {
          "jobAttempt" : [
             {
                "nodeId" : "host.domain.com:8041",
                "nodeHttpAddress" : "host.domain.com:8042",
                "startTime" : 1326238773493,
                "id" : 1,
                "logsLink" : "http://host.domain.com:8042/node/containerlogs/container_1326232085508_0004_01_000001",
                "containerId" : "container_1326232085508_0004_01_000001"
             }
          ]
       }
    }

  def task_attempts(self, job_id, task_id):
    return {
       "taskAttempts" : {
          "taskAttempt" : [
             {
                "elapsedMergeTime" : 47,
                "shuffleFinishTime" : 1326238780052,
                "assignedContainerId" : "container_1326232085508_0004_01_000003",
                "progress" : 100,
                "elapsedTime" : 0,
                "state" : "RUNNING",
                "elapsedShuffleTime" : 2592,
                "mergeFinishTime" : 1326238780099,
                "rack" : "/98.139.92.0",
                "elapsedReduceTime" : 0,
                "nodeHttpAddress" : "host.domain.com:8042",
                "type" : "REDUCE",
                "startTime" : 1326238777460,
                "id" : "attempt_1326232085508_4_4_r_0_0",
                "finishTime" : 0
             }
          ]
       }
    }

  def counters(self, job_id):
    return {
       "jobCounters" : {
          "id" : "job_1326232085508_4_4",
          "counterGroup" : [
             {
                "counterGroupName" : "org.apache.hadoop.mapreduce.lib.input.FileInputFormatCounter",
                "counter" : [
                   {
                      "reduceCounterValue" : 0,
                      "mapCounterValue" : 0,
                      "totalCounterValue" : 0,
                      "name" : "BYTES_READ"
                   }
                ]
             },
             {
                "counterGroupName" : "org.apache.hadoop.mapreduce.lib.output.FileOutputFormatCounter",
                "counter" : [
                   {
                      "reduceCounterValue" : 0,
                      "mapCounterValue" : 0,
                      "totalCounterValue" : 0,
                      "name" : "BYTES_WRITTEN"
                   }
                ]
             }
          ]
       }
    }


class MockMapreduceApi(MockMapreduce2Api):
  def job(self, user, job_id):
    if '1356251510842_0009' not in job_id:
      job = {u'job': {u'reducesCompleted': 0, u'mapsRunning': 1, u'id': u'job_1356251510842_0054', u'successfulReduceAttempts': 0, u'successfulMapAttempts': 0,
                      u'uberized': False, u'reducesTotal': 1, u'elapsedTime': 3426, u'mapsPending': 0, u'state': u'RUNNING', u'failedReduceAttempts': 0,
                      u'mapsCompleted': 0, u'killedMapAttempts': 0, u'killedReduceAttempts': 0, u'runningReduceAttempts': 0, u'failedMapAttempts': 0, u'mapsTotal': 1,
                      u'user': u'romain', u'startTime': 1357152972886, u'reducesPending': 1, u'reduceProgress': 0.0, u'finishTime': 0,
                      u'name': u'select avg(salary) from sample_07(Stage-1)', u'reducesRunning': 0, u'newMapAttempts': 0, u'diagnostics': u'', u'mapProgress': 0.0,
                      u'runningMapAttempts': 1, u'newReduceAttempts': 1}}
      job['job']['id'] = job_id
      return job


class HistoryServerApi(MockMapreduce2Api):

  def __init__(self, oozie_url=None): pass

  def job(self, user, job_id):
    if '1356251510842_0054' not in job_id:
      return {u'job': {u'reducesCompleted': 1, u'avgMapTime': 1798, u'avgMergeTime': 1479, u'id': u'job_1356251510842_0009', u'successfulReduceAttempts': 1,
                     u'successfulMapAttempts': 2, u'uberized': False, u'reducesTotal': 1, u'state': u'SUCCEEDED', u'failedReduceAttempts': 0, u'mapsCompleted': 2,
                     u'killedMapAttempts': 0, u'diagnostics': u'', u'mapsTotal': 2, u'user': u'romain', u'startTime': 1357151916268, u'avgReduceTime': 137,
                     u'finishTime': 1357151923925, u'name': u'oozie:action:T=map-reduce:W=MapReduce-copy:A=Sleep:ID=0000004-121223003201296-oozie-oozi-W',
                     u'avgShuffleTime': 1421, u'queue': u'default', u'killedReduceAttempts': 0, u'failedMapAttempts': 0}}
