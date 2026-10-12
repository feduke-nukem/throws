import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Creates a temporary directory with [files] (relative path to content),
/// deleted after the test.
Future<String> createTempTree(Map<String, String> files) async {
  final dir = await Directory.systemTemp.createTemp('throws_collector_test_');
  addTearDown(() => dir.delete(recursive: true));
  for (final entry in files.entries) {
    final file = File(p.join(dir.path, entry.key));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(entry.value);
  }
  return dir.resolveSymbolicLinksSync();
}

/// A package named [name] with [libFiles] under lib/.
Future<String> createPackage(
  Map<String, String> libFiles, {
  String name = 'demo',
}) {
  return createTempTree({
    'pubspec.yaml': 'name: $name\nenvironment:\n  sdk: ^3.0.0\n',
    for (final entry in libFiles.entries) 'lib/${entry.key}': entry.value,
  });
}
