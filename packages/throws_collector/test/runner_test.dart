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

  group('dependencies', () {
    /// A project depending on `dep` (path), `errs` (hosted) and `flutter`
    /// (sdk), with a package config as written by pub get.
    Future<String> createProject({String config = '  - dependencies\n'}) {
      return createTempTree({
        'app/pubspec.yaml':
            'name: app\ndev_dependencies:\n'
            '  throws_collector: any\n',
        'app/throws_collector.yaml': 'output_dir: out\ninput:\n$config',
        'app/pubspec.lock': '''
packages:
  dep:
    dependency: "direct main"
    description:
      path: "../dep"
      relative: true
    source: path
    version: "0.1.0"
  errs:
    dependency: transitive
    description:
      name: errs
      url: "https://pub.dev"
    source: hosted
    version: "2.0.0"
  flutter:
    dependency: "direct main"
    description: flutter
    source: sdk
    version: "0.0.0"
  gitdep:
    dependency: transitive
    description:
      path: "."
      ref: main
      resolved-ref: abc123
      url: "https://example.com/gitdep.git"
    source: git
    version: "1.0.0"
  nolib:
    dependency: transitive
    description:
      name: nolib
      url: "https://pub.dev"
    source: hosted
    version: "1.0.0"
''',
        'app/.dart_tool/package_config.json': '''
{
  "configVersion": 2,
  "packages": [
    {"name": "dep", "rootUri": "../../dep", "packageUri": "lib/"},
    {"name": "errs", "rootUri": "../../errs", "packageUri": "lib/"},
    {"name": "gitdep", "rootUri": "../../gitdep", "packageUri": "lib/"},
    {"name": "nolib", "rootUri": "../../nolib", "packageUri": "lib/"},
    {"name": "app", "rootUri": "../", "packageUri": "lib/"}
  ]
}
''',
        'dep/pubspec.yaml': 'name: dep\n',
        'dep/lib/dep.dart': '''
import 'package:errs/errs.dart';

void fail() {
  throw makeError();
}
''',
        'errs/pubspec.yaml': 'name: errs\n',
        'gitdep/pubspec.yaml': 'name: gitdep\n',
        'gitdep/lib/gitdep.dart': 'void ok() {}\n',
        'nolib/pubspec.yaml': 'name: nolib\n',
        'errs/lib/errs.dart': '''
class ErrsException implements Exception {}

ErrsException makeError() => ErrsException();

void check() {
  throw ErrsException();
}
''',
      }).then((root) => p.join(root, 'app'));
    }

    String read(String app, String name) =>
        File(p.join(app, 'out', '$name.yaml')).readAsStringSync();

    test('collects every locked package with resolved types', () async {
      final app = await createProject();

      await run(const [], workingDirectory: app);

      final dep = read(app, 'dep');
      expect(dep, startsWith('# dep 0.1.0\n'));
      expect(loadYaml(dep), {
        'package:dep/dep.dart': {
          'fail': ['ErrsException'],
        },
      });
      expect(read(app, 'errs'), startsWith('# errs 2.0.0\n'));
      expect(read(app, 'gitdep'), startsWith('# gitdep 1.0.0 abc123\n'));
      expect(read(app, 'nolib'), '# nolib 1.0.0\n');
      expect(File(p.join(app, 'out', 'flutter.yaml')).existsSync(), isFalse);
    });

    test('skips excluded packages', () async {
      final app = await createProject(
        config: '  - dependencies:\n      exclude: [errs]\n',
      );

      await run(const [], workingDirectory: app);

      expect(File(p.join(app, 'out', 'dep.yaml')).existsSync(), isTrue);
      expect(File(p.join(app, 'out', 'errs.yaml')).existsSync(), isFalse);
    });

    test('skips up-to-date hosted packages, not path ones', () async {
      final app = await createProject();
      File(p.join(app, 'out', 'errs.yaml'))
        ..createSync(recursive: true)
        ..writeAsStringSync('# errs 2.0.0\nstale: true\n');
      File(
        p.join(app, 'out', 'dep.yaml'),
      ).writeAsStringSync('# dep 0.1.0\nstale: true\n');
      File(
        p.join(app, 'out', 'gitdep.yaml'),
      ).writeAsStringSync('# gitdep 1.0.0 old\nstale: true\n');

      await run(const [], workingDirectory: app);

      expect(read(app, 'errs'), '# errs 2.0.0\nstale: true\n');
      expect(read(app, 'dep'), isNot(contains('stale')));
      expect(read(app, 'gitdep'), isNot(contains('stale')));
    });

    test('requires every locked package in the package config', () async {
      final app = await createProject();
      final config = File(p.join(app, '.dart_tool', 'package_config.json'));
      config.writeAsStringSync(
        config.readAsStringSync().replaceFirst('"name": "errs"', '"name": "x"'),
      );

      await expectLater(
        run(const [], workingDirectory: app),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            contains('errs is missing'),
          ),
        ),
      );
    });

    test('requires pub get', () async {
      final app = await createProject();
      File(p.join(app, '.dart_tool', 'package_config.json')).deleteSync();

      await expectLater(
        run(const [], workingDirectory: app),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            contains('Run pub get'),
          ),
        ),
      );
    });
  });
}
