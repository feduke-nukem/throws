import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:throws_collector/src/map_writer.dart';
import 'package:throws_collector/src/options.dart';
import 'package:yaml/yaml.dart';

import 'helpers.dart';

const _entries = <String, Map<String, Set<String>>>{
  'dart:core': {
    'Iterable.single': {'StateError'},
    'Iterable.first': {'StateError'},
  },
  "package:a/it's.dart": {
    r'A.$new': {'Z', 'A'},
  },
};

Future<String> _write(OutputFormat format, String fileName) async {
  final root = await createTempTree({});
  final outPath = p.join(root, 'nested', fileName);
  await writeMap(_entries, outPath, 'errorsMap', format);
  return File(outPath).readAsStringSync();
}

void main() {
  test('writes dart format with sorted, escaped entries', () async {
    final content = await _write(OutputFormat.dart, 'out.dart');
    expect(content, r'''
const Map<String, Map<String, List<String>>> errorsMap = {
  'dart:core': {
    'Iterable.first': ['StateError'],
    'Iterable.single': ['StateError'],
  },
  'package:a/it\'s.dart': {
    'A.\$new': ['A', 'Z'],
  },
};
''');
  });

  test('writes json format', () async {
    final decoded = jsonDecode(await _write(OutputFormat.json, 'out.json'));
    expect(decoded, {
      'dart:core': {
        'Iterable.first': ['StateError'],
        'Iterable.single': ['StateError'],
      },
      "package:a/it's.dart": {
        r'A.$new': ['A', 'Z'],
      },
    });
  });

  test('writes yaml format', () async {
    final decoded = loadYaml(await _write(OutputFormat.yaml, 'out.yaml'));
    expect(decoded, {
      'dart:core': {
        'Iterable.first': ['StateError'],
        'Iterable.single': ['StateError'],
      },
      "package:a/it's.dart": {
        r'A.$new': ['A', 'Z'],
      },
    });
  });
}
