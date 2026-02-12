import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:throws_collector/src/options.dart';

void main() {
  test('loads config from throws_collector.yaml', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'throws_collector_options_',
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
root: lib
out: build/throws_map.json
sdk_root: /tmp/sdk
format: json
''');

    Directory('${tempDir.path}/lib').createSync(recursive: true);
    Directory.current = tempDir.path;

    final options = parseArgs(const []);

    expect(
      _stripPrivatePrefix(p.normalize(options.root)),
      _stripPrivatePrefix(p.normalize('${tempDir.path}/lib')),
    );
    expect(
      _stripPrivatePrefix(p.normalize(options.outPath)),
      _stripPrivatePrefix(p.normalize('${tempDir.path}/build/throws_map.json')),
    );
    expect(options.mapName, 'throws_map');
    expect(options.sdkRoot, '/tmp/sdk');
    expect(options.outputFormat, OutputFormat.json);
  });

  test('uses defaults when config is missing', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'throws_collector_defaults_',
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

    Directory.current = tempDir.path;

    final options = parseArgs(const []);

    expect(options.root, '.');
    expect(options.outPath, 'throws/throws_collector_result.g.dart');
    expect(options.mapName, 'throwsCollectorResult');
    expect(options.sdkRoot, isNull);
    expect(options.outputFormat, OutputFormat.dart);
    expect(options.showHelp, isFalse);
  });

  test('args override yaml config', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'throws_collector_override_',
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
root: lib
out: build/throws_map.json
format: json
''');

    Directory('${tempDir.path}/lib').createSync(recursive: true);
    Directory.current = tempDir.path;

    final options = parseArgs([
      '--root',
      'src',
      '--out',
      'out/overrides.dart',
      '--format',
      'dart',
    ]);

    expect(
      _stripPrivatePrefix(p.normalize(options.root)),
      _stripPrivatePrefix(p.normalize('${tempDir.path}/src')),
    );
    expect(
      _stripPrivatePrefix(p.normalize(options.outPath)),
      _stripPrivatePrefix(p.normalize('${tempDir.path}/out/overrides.dart')),
    );
    expect(options.mapName, 'overrides');
    expect(options.outputFormat, OutputFormat.dart);
  });

  test('infers output format from outPath when format not provided', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'throws_collector_infer_',
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

    Directory.current = tempDir.path;

    final options = parseArgs(['--out', 'out/throws.yaml']);

    expect(options.outputFormat, OutputFormat.yaml);
    expect(options.mapName, 'throws');
  });

  test('throws on unsupported outPath extension', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'throws_collector_extension_',
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

    Directory.current = tempDir.path;

    expect(() => parseArgs(['--out', 'out/throws.txt']), throwsFormatException);
  });
}

String _stripPrivatePrefix(String path) {
  const prefix = '/private';
  if (path.startsWith(prefix)) {
    return path.substring(prefix.length);
  }
  return path;
}
