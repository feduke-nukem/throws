import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:throws_collector/src/map_writer.dart';
import 'package:throws_collector/src/options.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('writes dart format', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'throws_collector_dart_',
    );
    addTearDown(() async => tempDir.delete(recursive: true));

    final outPath = '${tempDir.path}/out.dart';
    final entries = <String, Set<String>>{
      'dart:core.Iterable.single': {'StateError'},
      'dart:core.Iterable.first': {'StateError'},
    };

    await writeMap(entries, outPath, 'dartSdkErrors', OutputFormat.dart);

    final content = File(outPath).readAsStringSync();
    expect(content, contains('const Map<String, List<String>> dartSdkErrors'));
    expect(content, contains("'dart:core.Iterable.single': ['StateError']"));
  });

  test('writes json format', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'throws_collector_json_',
    );
    addTearDown(() async => tempDir.delete(recursive: true));

    final outPath = '${tempDir.path}/out.json';
    final entries = <String, Set<String>>{
      'dart:core.Iterable.single': {'StateError'},
    };

    await writeMap(entries, outPath, '_throwsMap', OutputFormat.json);

    final content = File(outPath).readAsStringSync();
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    expect(decoded['dart:core.Iterable.single'], ['StateError']);
  });

  test('writes yaml format', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'throws_collector_yaml_',
    );
    addTearDown(() async => tempDir.delete(recursive: true));

    final outPath = '${tempDir.path}/out.yaml';
    final entries = <String, Set<String>>{
      'dart:core.Iterable.single': {'StateError'},
      'dart:core.Iterable.first': {'StateError'},
    };

    await writeMap(entries, outPath, '_throwsMap', OutputFormat.yaml);

    final content = File(outPath).readAsStringSync();
    final decoded = loadYaml(content) as YamlMap;
    expect(decoded['dart:core.Iterable.single'], ['StateError']);
    expect(decoded['dart:core.Iterable.first'], ['StateError']);
  });
}
