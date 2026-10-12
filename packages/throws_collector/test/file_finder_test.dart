import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:throws_collector/src/file_finder.dart';

import 'helpers.dart';

void main() {
  test('lists dart files outside excluded directories', () async {
    final root = await createTempTree({
      'lib/a.dart': '',
      'lib/src/b.dart': '',
      'lib/readme.md': '',
      'lib/test/c.dart': '',
      'test/d.dart': '',
      'example/e.dart': '',
      '.dart_tool/f.dart': '',
      'build/g.dart': '',
    });
    final files = listDartFiles(
      Directory(root),
    ).map((file) => p.relative(file.path, from: root)).toList()..sort();
    expect(files, [p.join('lib', 'a.dart'), p.join('lib', 'src', 'b.dart')]);
  });
}
