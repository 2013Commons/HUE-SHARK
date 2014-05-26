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
#
# Utilities for dealing with file modes.

import os
import posixpath
import tempfile
from zipfile import ZipFile

from django.utils.translation import ugettext as _


__all__ = ['archive_factory']


class Archive(object):
  """
  Acrchive interface.
  """
  def extract(self, path):
    """
    Extract an Archive.
    Should return a directory where the extracted contents live.
    """
    raise NotImplemented(_("Must implement 'extract' method."))

class ZipArchive(Archive):
  """
  Acts on a zip file in memory or in a temporary location.
  Python's ZipFile class inherently buffers all reading.
  """
  def __init__(self, file):
    self.file = isinstance(file, basestring) and open(file) or file
    self.zfh = ZipFile(self.file)

  def extract(self):
    """
    Extracts a zip file.
    If a 'file' ends with '/', then it is a directory and we must create it.
    Else, open a file for writing and meta pipe the contents zipfile to the new file.
    """
    # Store all extracted files in a temporary directory.
    directory = tempfile.mkdtemp()

    dirs, files = self._filenames()
    self._create_dirs(directory, dirs)
    self._create_files(directory, files)

    return directory

  def _filenames(self):
    """
    List all dirs and files by reading the table of contents of the Zipfile.
    """
    dirs = []
    files = []
    for name in self.zfh.namelist():
      if name.endswith(posixpath.sep):
        dirs.append(name)
      else:
        files.append(name)
    return (dirs, files)

  def _create_dirs(self, basepath, dirs=[]):
    """
    Creates all directories passed at the given basepath.
    """
    for directory in dirs:
      directory = os.path.join(basepath, directory)
      try:
        os.makedirs(directory)
      except OSError:
        pass

  def _create_files(self, basepath, files=[]):
    """
    Extract files to their rightful place.
    Files are written to a temporary directory immediately after being decompressed.
    """
    for f in files:
      new_path = os.path.join(basepath, f)
      new_file = open(new_path, 'w')
      new_file.write(self.zfh.read(f))
      new_file.close()


def archive_factory(path, archive_type='zip'):
  return ZipArchive(path)
