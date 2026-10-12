import 'dart:convert';
import 'dart:io';

import 'options.dart';

/// Writes errors per library URI, then per member path, in the schema read by
/// throws_plugin (`members` in throws.yaml and `include` files).
Future<void> writeMap(
  Map<String, Map<String, Set<String>>> entries,
  String outPath,
  String mapName,
  OutputFormat format,
) async {
  final sorted = _sorted(entries);
  final content = switch (format) {
    OutputFormat.dart => _writeDart(sorted, mapName),
    OutputFormat.json => const JsonEncoder.withIndent('  ').convert(sorted),
    OutputFormat.yaml => _writeYaml(sorted),
  };

  final outFile = File(outPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(content);
}

Map<String, Map<String, List<String>>> _sorted(
  Map<String, Map<String, Set<String>>> entries,
) {
  return {
    for (final library in entries.keys.toList()..sort())
      library: {
        for (final member in entries[library]!.keys.toList()..sort())
          member: entries[library]![member]!.toList()..sort(),
      },
  };
}

String _writeDart(Map<String, Map<String, List<String>>> map, String mapName) {
  final buffer = StringBuffer()
    ..writeln('const Map<String, Map<String, List<String>>> $mapName = {');
  for (final library in map.entries) {
    buffer.writeln('  ${_dartString(library.key)}: {');
    for (final member in library.value.entries) {
      final errors = member.value.map(_dartString).join(', ');
      buffer.writeln('    ${_dartString(member.key)}: [$errors],');
    }
    buffer.writeln('  },');
  }
  buffer.writeln('};');
  return buffer.toString();
}

String _dartString(String value) =>
    "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";

String _writeYaml(Map<String, Map<String, List<String>>> map) {
  final buffer = StringBuffer();
  for (final library in map.entries) {
    buffer.writeln('${_yamlQuote(library.key)}:');
    for (final member in library.value.entries) {
      final errors = member.value.map(_yamlQuote).join(', ');
      buffer.writeln('  ${_yamlQuote(member.key)}: [$errors]');
    }
  }
  return buffer.toString();
}

String _yamlQuote(String value) => "'${value.replaceAll("'", "''")}'";
