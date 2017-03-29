# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Low-level bundling name helpers."""


def _binary_file(ctx, src, dest, executable=False):
  """Returns a bundlable file whose destination is in the binary directory.

  Args:
    ctx: The Skylark context.
    src: The `File` artifact that should be bundled.
    dest: The path within the bundle's binary directory where the file should
        be placed.
    executable: True if the file should be made executable.
  Returns:
    A bundlable file struct (see `bundling_support.bundlable_file`).
  """
  return _bundlable_file(src, _path_in_binary_dir(ctx, dest), executable)


def _bundlable_file(src, dest, executable=False):
  """Returns a value that represents a bundlable file or ZIP archive.

  A "bundlable file" is a struct that maps a file (`"src"`) to a path within a
  bundle (`"dest"`). This can be used with plain files, where `dest` denotes
  the path within the bundle where the file should be placed (including its
  filename, which allows it to be changed), or with ZIP archives, where `dest`
  denotes the location within the bundle where the ZIP's contents should be
  extracted.

  Args:
    src: The `File` artifact that should be bundled.
    dest: The path within the bundle where the file should be placed.
    executable: True if the file should be made executable.
  Returns:
    A struct with `src`, `dest`, and `executable` fields representing the
    bundlable file.
  """
  return struct(src=src, dest=dest, executable=executable)


def _bundlable_file_sources(bundlable_files):
  """Returns the source files from the given collection of bundlable files.

  This is a convenience function that allows a set of bundlable files to be
  quickly turned into a list of files that can be passed to an action's inputs,
  for example.

  Args:
    bundlable_files: A list or set of bundlable file values (as returned by
        `bundling_support.bundlable_file`).
  Returns:
    A `depset` containing the `File` artifacts from the given bundlable files.
  """
  return depset([bf.src for bf in bundlable_files])


def _bundle_name(ctx):
  """Returns the name of the bundle.

  Args:
    ctx: The Skylark context.
  Returns:
    The bundle name.
  """
  if hasattr(ctx.attr, "_bundle_name_attr"):
    bundle_name_attr = ctx.attr._bundle_name_attr
    return getattr(ctx.attr, bundle_name_attr)
  else:
    return ctx.label.name


def _bundle_name_with_extension(ctx):
  """Returns the name of the bundle with its extension.

  Args:
    ctx: The Skylark context.
  Returns:
    The bundle name with its extension.
  """
  return _bundle_name(ctx) + ctx.attr._bundle_extension


def _contents_file(ctx, src, dest, executable=False):
  """Returns a bundlable file whose destination is in the contents directory.

  Args:
    ctx: The Skylark context.
    src: The `File` artifact that should be bundled.
    dest: The path within the bundle's contents directory where the file should
        be placed.
    executable: True if the file should be made executable.
  Returns:
    A bundlable file struct (see `bundling_support.bundlable_file`).
  """
  return _bundlable_file(src, _path_in_contents_dir(ctx, dest), executable)


def _embedded_bundle(path, apple_bundle, verify_bundle_id):
  """Returns a value that represents an embedded bundle in another bundle.

  These values are used by the bundler to indicate how dependencies that are
  themselves bundles (such as extensions or frameworks) should be bundled in
  the application or target that depends on them.

  Args:
    path: The relative path within the depender's bundle where the given bundle
        should be located.
    apple_bundle: The `apple_bundle` provider of the embedded bundle.
    verify_bundle_id: If True, the bundler should verify that the bundle
        identifier of the depender is a prefix of the bundle identifier of the
        embedded bundle.
  Returns:
    A struct with `path`, `apple_bundle`, and `verify_bundle_id` fields equal
    to the values given in the arguments.
  """
  return struct(
      path=path, apple_bundle=apple_bundle, verify_bundle_id=verify_bundle_id)


def _force_settings_bundle_prefix(bundle_file):
  """Forces a file's destination to start with "Settings.bundle/".

  If the given file's destination path contains a directory named "*.bundle",
  everything up to that point in the path is removed and replaced with
  "Settings.bundle". Otherwise, "Settings.bundle/" is prepended to the path.

  Args:
    bundle_file: A value from an objc provider's bundle_file field; in other
        words, a struct with file and bundle_path fields.
  Returns:
    A bundlable file struct with the same File object, but whose path has been
    transformed to start with "Settings.bundle/".
  """
  _, _, path_inside_bundle = bundle_file.bundle_path.rpartition(".bundle/")
  new_path = "Settings.bundle/" + path_inside_bundle
  return struct(file=bundle_file.file, bundle_path=new_path)


def _header_prefix(input_file):
  """Sets a file's bundle destination to a "Headers/" subdirectory.

  Args:
    input_file: The File to be bundled
  Returns:
    A bundlable file struct with the same File object, but whose path has been
    transformed to start with "Headers/".
  """
  new_path = "Headers/" + input_file.basename
  return struct(file=input_file, bundle_path=new_path)


def _path_in_binary_dir(ctx, path):
  """Makes a path relative to where the bundle's binary is stored.

  On iOS/watchOS/tvOS, the binary is placed directly in the bundle's contents
  directory (which itself is actually the bundle root). On macOS, the binary is
  in a MacOS directory that is inside the bundle's Contents directory.

  Args:
    ctx: The Skylark context.
    path: The path to make relative to where the bundle's binary is stored.
  Returns:
    The path, made relative to where the bundle's binary is stored.
  """
  return _path_in_contents_dir(
      ctx, ctx.attr._bundle_binary_path_format % (path or ""))


def _path_in_contents_dir(ctx, path):
  """Makes a path relative to where the bundle's contents are stored.

  Contents include files such as:
  * A directory of resources (which itself might be flattened into contents)
  * A directory for the binary (which might be flattened)
  * Directories for Frameworks and PlugIns (extensions)
  * The bundle's Info.plist and PkgInfo
  * The code signature

  Args:
    ctx: The Skylark context.
    path: The path to make relative to where the bundle's contents are stored.
  Returns:
    The path, made relative to where the bundle's contents are stored.
  """
  return ctx.attr._bundle_contents_path_format % (path or "")


def _path_in_resources_dir(ctx, path):
  """Makes a path relative to where the bundle's resources are stored.

  On iOS/watchOS/tvOS, resources are placed directly in the bundle's contents
  directory (which itself is actually the bundle root). On macOS, resources are
  in a Resources directory that is inside the bundle's Contents directory.

  Args:
    ctx: The Skylark context.
    path: The path to make relative to where the bundle's resources are stored.
  Returns:
    The path, made relative to where the bundle's resources are stored.
  """
  return _path_in_contents_dir(
      ctx, ctx.attr._bundle_resources_path_format % (path or ""))


def _resource_file(ctx, src, dest, executable=False):
  """Returns a bundlable file whose destination is in the resources directory.

  Args:
    ctx: The Skylark context.
    src: The `File` artifact that should be bundled.
    dest: The path within the bundle's resources directory where the file
        should be placed.
    executable: True if the file should be made executable.
  Returns:
    A bundlable file struct (see `bundling_support.bundlable_file`).
  """
  return _bundlable_file(src, _path_in_resources_dir(ctx, dest), executable)


# Define the loadable module that lists the exported symbols in this file.
bundling_support = struct(
    binary_file=_binary_file,
    bundlable_file=_bundlable_file,
    bundlable_file_sources=_bundlable_file_sources,
    bundle_name=_bundle_name,
    bundle_name_with_extension=_bundle_name_with_extension,
    contents_file=_contents_file,
    embedded_bundle=_embedded_bundle,
    header_prefix=_header_prefix,
    force_settings_bundle_prefix=_force_settings_bundle_prefix,
    path_in_binary_dir=_path_in_binary_dir,
    path_in_contents_dir=_path_in_contents_dir,
    path_in_resources_dir=_path_in_resources_dir,
    resource_file=_resource_file,
)
