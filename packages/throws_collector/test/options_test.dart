import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:throws_collector/src/options.dart';

void main() {
  test('loads inputs from throws_collector.yaml', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'throws_collector_inputs_',
    );
    final originalCwd = Directory.current;
    addTearDown(() async {
      Directory.current = originalCwd;
      await tempDir.delete(recursive: true);
    });

    final pubspec = File('${tempDir.path}/pubspec.yaml');
    pubspec.writeAsStringSync('''
name: example

dev_dependencies:
  throws_collector: any
''');

    final config = File('${tempDir.path}/throws_collector.yaml');
    config.writeAsStringSync('''
input:
  - flutter_errors.yaml:
      path: lib
''');

    Directory('${tempDir.path}/lib').createSync(recursive: true);
    Directory.current = tempDir.path;

    final parsed = parseArgs(const []);

    expect(
      _stripPrivatePrefix(p.normalize(parsed.packageRoot)),
      _stripPrivatePrefix(p.normalize(tempDir.path)),
    );
    expect(
      _stripPrivatePrefix(p.normalize(parsed.outputDir)),
      _stripPrivatePrefix(p.normalize('${tempDir.path}/throws_collector_gen')),
    );
    expect(parsed.inputs, hasLength(1));
    expect(parsed.inputs.first.outputFile, 'flutter_errors.yaml');
    expect(parsed.inputs.first.source, isA<LocalInputSource>());
  });
}

String _stripPrivatePrefix(String path) {
  const prefix = '/private';
  if (path.startsWith(prefix)) {
    return path.substring(prefix.length);
  }
  return path;
}
