import 'dart:io';

import 'package:path/path.dart' as p;

const _defaultExcluded = <String>{
  '.dart_tool',
  'build',
  '.git',
  'example',
  'test',
  'benchmark',
  'docs',
  'tool',
};

Iterable<File> listDartFiles(Directory root) sync* {
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    if (!entity.path.endsWith('.dart')) {
      continue;
    }
    final parts = p.split(p.relative(entity.path, from: root.path));
    if (parts.isNotEmpty && _defaultExcluded.contains(parts.first)) {
      continue;
    }
    if (parts.any(_defaultExcluded.contains)) {
      continue;
    }
    yield entity;
  }
}
