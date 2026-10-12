import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:throws_collector/throws_collector.dart';
import 'package:yaml/yaml.dart';

import 'helpers.dart';

void main() {
  test('collects a local input into the configured output', () async {
    final root = await createTempTree({
      'pubspec.yaml': '''
name: demo

dev_dependencies:
  throws_collector: any
''',
      'throws_collector.yaml': '''
output_dir: out
input:
  - errors.yaml:
      path: lib
''',
      'lib/a.dart': '''
void a() {
  throw StateError('x');
}
''',
    });

    await run(const [], workingDirectory: root);

    final output = File(p.join(root, 'out', 'errors.yaml'));
    final map = loadYaml(output.readAsStringSync()) as YamlMap;
    expect(map['package:demo/a.dart']['a'], ['StateError']);
  });

  test('does nothing without inputs', () async {
    final root = await createTempTree({
      'pubspec.yaml':
          'name: demo\ndev_dependencies:\n  throws_collector: any\n',
    });
    await run(const [], workingDirectory: root);
    expect(
      Directory(p.join(root, 'throws_collector_gen')).existsSync(),
      isFalse,
    );
  });
}
