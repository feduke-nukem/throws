import 'dart:convert';
import 'dart:io';

import 'options.dart';

Future<void> writeMap(
  Map<String, Set<String>> entries,
  String outPath,
  String mapName,
  OutputFormat format,
) async {
  final sortedKeys = entries.keys.toList()..sort();
  final content = switch (format) {
    OutputFormat.dart => _writeDart(sortedKeys, entries, mapName),
    OutputFormat.json => _writeJson(sortedKeys, entries),
    OutputFormat.yaml => _writeYaml(sortedKeys, entries),
  };

  final outFile = File(outPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(content);
}

String _writeDart(
  List<String> sortedKeys,
  Map<String, Set<String>> entries,
  String mapName,
) {
  final buffer = StringBuffer();
  buffer.writeln('const Map<String, List<String>> $mapName = {');
  for (final key in sortedKeys) {
    final errors = entries[key]!.toList()..sort();
    buffer.write("  '");
    buffer.write(key);
    buffer.write("': [");
    for (var i = 0; i < errors.length; i++) {
      if (i != 0) {
        buffer.write(', ');
      }
      buffer.write("'");
      buffer.write(errors[i]);
      buffer.write("'");
    }
    buffer.writeln('],');
  }
  buffer.writeln('};');
  return buffer.toString();
}

String _writeJson(List<String> sortedKeys, Map<String, Set<String>> entries) {
  final map = <String, List<String>>{};
  for (final key in sortedKeys) {
    map[key] = entries[key]!.toList()..sort();
  }
  return const JsonEncoder.withIndent('  ').convert(map);
}

String _writeYaml(List<String> sortedKeys, Map<String, Set<String>> entries) {
  final buffer = StringBuffer();
  for (final key in sortedKeys) {
    buffer.writeln('${_yamlQuote(key)}:');
    final errors = entries[key]!.toList()..sort();
    for (final error in errors) {
      buffer.writeln('  - ${_yamlQuote(error)}');
    }
  }
  return buffer.toString();
}

String _yamlQuote(String value) {
  final escaped = value.replaceAll("'", "''");
  return "'$escaped'";
}
