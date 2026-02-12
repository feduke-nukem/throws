import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

enum OutputFormat { dart, json, yaml }

const _configFileName = 'throws_collector.yaml';
const outputDirName = 'throws_collector_gen';

class CollectorConfig {
  final String packageRoot;
  final String outputDir;
  final List<CollectorInput> inputs;
  final bool showHelp;

  const CollectorConfig({
    required this.packageRoot,
    required this.outputDir,
    required this.inputs,
    required this.showHelp,
  });
}

class CollectorInput {
  final String outputFile;
  final InputSource source;

  const CollectorInput({required this.outputFile, required this.source});
}

sealed class InputSource {
  const InputSource();
}

class LocalInputSource extends InputSource {
  final String path;

  const LocalInputSource(this.path);
}

class GitInputSource extends InputSource {
  final String url;

  const GitInputSource(this.url);
}

class PackageInputSource extends InputSource {
  final String name;
  final String version;

  const PackageInputSource({required this.name, required this.version});
}

CollectorConfig parseArgs(List<String> args) {
  final parser = _buildParser();
  final results = parser.parse(args);
  final showHelp = results['help'] as bool;

  final packageRoot = _findPackageRoot(Directory.current.path);
  final resolvedRoot = packageRoot ?? Directory.current.path;
  final outputDir = p.join(resolvedRoot, outputDirName);

  final inputs = packageRoot == null
      ? const <CollectorInput>[]
      : _loadInputs(packageRoot);

  return CollectorConfig(
    packageRoot: resolvedRoot,
    outputDir: outputDir,
    inputs: inputs,
    showHelp: showHelp,
  );
}

String usage() {
  final parser = _buildParser();
  return [
    'throws_collector: collect throws metadata into map files.',
    '',
    'Usage:',
    '  throws_collector [--help]',
    '',
    'Options:',
    parser.usage,
    '',
    'Config:',
    '  Place throws_collector.yaml at the package root.',
    '  Output is written to $outputDirName/.',
  ].join(Platform.lineTerminator);
}

ArgParser _buildParser() {
  return ArgParser()..addFlag(
    'help',
    abbr: 'h',
    help: 'Show this help message.',
    negatable: false,
  );
}

OutputFormat resolveOutputFormat(String outPath) {
  final extension = p.extension(outPath).toLowerCase();
  if (extension.isEmpty) {
    return OutputFormat.yaml;
  }
  final inferred = _parseOutputFormatFromExtension(extension);
  if (inferred == null) {
    throw FormatException('Unsupported output file extension: $extension');
  }
  return inferred;
}

OutputFormat? _parseOutputFormatFromExtension(String extension) {
  switch (extension) {
    case '.dart':
      return OutputFormat.dart;
    case '.json':
      return OutputFormat.json;
    case '.yaml':
    case '.yml':
      return OutputFormat.yaml;
    default:
      return null;
  }
}

String deriveMapName(String outPath, OutputFormat format) {
  var baseName = p.basename(outPath);
  if (baseName.endsWith('.g.dart')) {
    baseName = baseName.substring(0, baseName.length - '.g.dart'.length);
  } else {
    baseName = p.basenameWithoutExtension(outPath);
  }
  if (baseName.isEmpty) {
    return '_throwsMap';
  }
  final sanitized = baseName.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
  if (sanitized.isEmpty) {
    return '_throwsMap';
  }
  final normalized = format == OutputFormat.dart
      ? _toLowerCamelCase(sanitized)
      : sanitized;
  if (RegExp(r'^[0-9]').hasMatch(normalized)) {
    return '_$normalized';
  }
  return normalized;
}

String _toLowerCamelCase(String value) {
  final parts = value.split(RegExp(r'_+')).where((part) => part.isNotEmpty);
  if (parts.isEmpty) {
    return value;
  }
  final iterator = parts.iterator;
  iterator.moveNext();
  final buffer = StringBuffer()
    ..write(iterator.current.substring(0, 1).toLowerCase())
    ..write(iterator.current.substring(1));
  while (iterator.moveNext()) {
    final part = iterator.current;
    buffer.write(part.substring(0, 1).toUpperCase());
    buffer.write(part.substring(1));
  }
  return buffer.toString();
}

List<CollectorInput> _loadInputs(String packageRoot) {
  final configFile = File(p.join(packageRoot, _configFileName));
  if (!configFile.existsSync()) {
    return const <CollectorInput>[];
  }

  final yamlDoc = loadYaml(configFile.readAsStringSync());
  if (yamlDoc is! YamlMap) {
    return const <CollectorInput>[];
  }

  final inputNode = yamlDoc['input'];
  if (inputNode is! YamlList) {
    return const <CollectorInput>[];
  }

  final inputs = <CollectorInput>[];
  for (final item in inputNode) {
    if (item is! YamlMap || item.length != 1) {
      continue;
    }
    final entry = item.entries.first;
    final outputFile = entry.key is String ? entry.key as String : null;
    if (outputFile == null || outputFile.isEmpty) {
      continue;
    }
    if (entry.value is! YamlMap) {
      continue;
    }
    final source = _parseInputSource(entry.value as YamlMap);
    if (source == null) {
      continue;
    }
    inputs.add(CollectorInput(outputFile: outputFile, source: source));
  }

  return inputs;
}

InputSource? _parseInputSource(YamlMap node) {
  final pathValue = _readString(node['path']);
  if (pathValue != null) {
    return LocalInputSource(pathValue);
  }
  final gitValue = _readString(node['git']);
  if (gitValue != null) {
    return GitInputSource(gitValue);
  }
  final packageNode = node['package'];
  if (packageNode is YamlMap) {
    final name = _readString(packageNode['name']);
    final version = _readString(packageNode['version']);
    if (name != null && version != null) {
      return PackageInputSource(name: name, version: version);
    }
  }
  return null;
}

String? _findPackageRoot(String startPath) {
  var current = p.normalize(startPath);
  while (true) {
    final pubspecPath = p.join(current, 'pubspec.yaml');
    final pubspecFile = File(pubspecPath);
    if (pubspecFile.existsSync()) {
      final yamlDoc = loadYaml(pubspecFile.readAsStringSync());
      if (yamlDoc is YamlMap) {
        final deps = yamlDoc['dev_dependencies'] ?? yamlDoc['dependencies'];
        if (deps is YamlMap && deps.containsKey('throws_collector')) {
          return current;
        }
      }
    }
    final parent = p.dirname(current);
    if (parent == current) {
      return null;
    }
    current = parent;
  }
}

String? _readString(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}
