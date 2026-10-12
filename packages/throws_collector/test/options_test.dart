import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:throws_collector/src/options.dart';

import 'helpers.dart';

const _pubspec = '''
name: example

dev_dependencies:
  throws_collector: any
''';

Future<CollectorConfig> _parse(
  String config, {
  List<String> args = const [],
}) async {
  final root = await createTempTree({
    'pubspec.yaml': _pubspec,
    'throws_collector.yaml': config,
  });
  return parseArgs(args, workingDirectory: root);
}

void main() {
  test('loads inputs from throws_collector.yaml', () async {
    final root = await createTempTree({
      'pubspec.yaml': _pubspec,
      'throws_collector.yaml': '''
input:
  - flutter_errors.yaml:
      path: lib
''',
      'lib/a.dart': '',
    });

    final parsed = parseArgs(const [], workingDirectory: p.join(root, 'lib'));

    expect(parsed.packageRoot, root);
    expect(parsed.outputDir, p.join(root, 'throws_collector_gen'));
    expect(parsed.inputs, hasLength(1));
    expect(parsed.inputs.first.outputFile, 'flutter_errors.yaml');
    expect(parsed.inputs.first.runPubGet, isTrue);
    final source = parsed.inputs.first.source as LocalInputSource;
    expect(source.path, 'lib');
  });

  test('parses every input type', () async {
    final parsed = await _parse('''
input:
  - dart_sdk:
      output: dart.g.dart
  - flutter_sdk:
      output: flutter.json
  - dart_flag.yaml:
      dart: true
  - flutter_flag.yaml:
      flutter: true
  - git.yaml:
      git: https://github.com/a/b/tree/main/lib
      run_pub_get: false
  - bloc.dart:
      package:
        name: bloc
        version: 9.2.0
''');
    final sources = parsed.inputs.map((input) => input.source).toList();
    expect(parsed.inputs.map((input) => input.outputFile), [
      'dart.g.dart',
      'flutter.json',
      'dart_flag.yaml',
      'flutter_flag.yaml',
      'git.yaml',
      'bloc.dart',
    ]);
    expect(sources[0], isA<DartSdkInputSource>());
    expect(sources[1], isA<FlutterSdkInputSource>());
    expect(sources[2], isA<DartSdkInputSource>());
    expect(sources[3], isA<FlutterSdkInputSource>());
    expect((sources[4] as GitInputSource).url, contains('/tree/main/lib'));
    expect(parsed.inputs[4].runPubGet, isFalse);
    final package = sources[5] as PackageInputSource;
    expect([package.name, package.version], ['bloc', '9.2.0']);
  });

  test('parses shorthand inputs', () async {
    final parsed = await _parse('''
input:
  - dart
  - flutter
  - dart.json
  - flutter.dart
  - dart.txt
  - ""
''');
    expect(parsed.inputs.map((input) => input.outputFile), [
      'dart_sdk_errors.yaml',
      'flutter_errors.yaml',
      'dart_sdk_errors.json',
      'flutter_errors.dart',
    ]);
  });

  test('parses dependencies inputs', () async {
    final parsed = await _parse('''
input:
  - dependencies
  - dependencies:
      exclude: [meta, collection]
''');
    final sources = parsed.inputs
        .map((input) => input.source as DependenciesInputSource)
        .toList();
    expect(sources.map((source) => source.exclude), [
      isEmpty,
      {'meta', 'collection'},
    ]);
  });

  test('skips malformed inputs', () async {
    final parsed = await _parse('''
input:
  - dart_sdk: {}
  - unknown.yaml:
      nothing: true
  - a.yaml: plain
  - a: 1
    b: 2
  - package.yaml:
      package:
        name: only_name
''');
    expect(parsed.inputs, isEmpty);
  });

  test('resolves output_dir relative to the package root', () async {
    final parsed = await _parse('output_dir: gen/out\n');
    expect(parsed.outputDir, p.join(parsed.packageRoot, 'gen', 'out'));
    expect(parsed.inputs, isEmpty);
  });

  test('keeps absolute output_dir', () async {
    final parsed = await _parse('output_dir: /tmp/throws_out\n');
    expect(parsed.outputDir, '/tmp/throws_out');
  });

  test('reads --help', () async {
    final parsed = await _parse('', args: ['--help']);
    expect(parsed.showHelp, isTrue);
    expect(usage(), contains('throws_collector.yaml'));
  });

  test('without a package listing throws_collector', () async {
    final root = await createTempTree({'pubspec.yaml': 'name: other\n'});
    final parsed = parseArgs(const [], workingDirectory: root);
    expect(parsed.packageRoot, root);
    expect(parsed.inputs, isEmpty);
  });

  group('resolveOutputFormat', () {
    test('infers format from extension', () {
      expect(resolveOutputFormat('a.dart'), OutputFormat.dart);
      expect(resolveOutputFormat('a.JSON'), OutputFormat.json);
      expect(resolveOutputFormat('a.yml'), OutputFormat.yaml);
      expect(resolveOutputFormat('a'), OutputFormat.yaml);
    });

    test('rejects unknown extensions', () {
      expect(() => resolveOutputFormat('a.txt'), throwsFormatException);
    });
  });

  group('deriveMapName', () {
    test('camel-cases dart map names', () {
      expect(
        deriveMapName('out/flutter_errors.g.dart', OutputFormat.dart),
        'flutterErrors',
      );
      expect(
        deriveMapName('out/dart-sdk__errors.dart', OutputFormat.dart),
        'dartSdkErrors',
      );
    });

    test('keeps non-dart names and prefixes leading digits', () {
      expect(deriveMapName('my_map.yaml', OutputFormat.yaml), 'my_map');
      expect(deriveMapName('1map.json', OutputFormat.json), '_1map');
    });
  });
}
