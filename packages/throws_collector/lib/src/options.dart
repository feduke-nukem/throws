import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

enum OutputFormat { dart, json, yaml }

const _configFileName = 'throws_collector.yaml';
const outputDirName = 'throws_collector_gen';
const _configOutputDirKey = 'output_dir';
const _defaultDartSdkOutput = 'dart_sdk_errors.yaml';
const _defaultFlutterOutput = 'flutter_errors.yaml';

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
  final bool runPubGet;

  const CollectorInput({
    required this.outputFile,
    required this.source,
    required this.runPubGet,
  });
}

sealed class InputSource {
  const InputSource();
}

class LocalInputSource extends InputSource {
  final String path;

  const LocalInputSource(this.path);
}

class DartSdkInputSource extends InputSource {
  const DartSdkInputSource();
}

class FlutterSdkInputSource extends InputSource {
  const FlutterSdkInputSource();
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
  final configDoc = packageRoot == null ? null : _loadConfigDoc(packageRoot);
  final outputDir = _readOutputDir(configDoc, resolvedRoot);

  final inputs = packageRoot == null
      ? const <CollectorInput>[]
      : _loadInputs(configDoc);

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
    '  Override output_dir to change the output directory.',
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

List<CollectorInput> _loadInputs(YamlMap? yamlDoc) {
  if (yamlDoc == null) {
    return const <CollectorInput>[];
  }

  final inputNode = yamlDoc['input'];
  if (inputNode is! YamlList) {
    return const <CollectorInput>[];
  }

  final inputs = <CollectorInput>[];
  for (final item in inputNode) {
    if (item is String) {
      final shorthand = _parseShorthandInput(item);
      if (shorthand != null) {
        inputs.add(shorthand);
      }
      continue;
    }
    if (item is! YamlMap || item.length != 1) {
      continue;
    }
    final entry = item.entries.first;
    final key = entry.key is String ? entry.key as String : null;
    if (key == null || key.isEmpty) {
      continue;
    }
    if (entry.value is! YamlMap) {
      continue;
    }
    final mapValue = entry.value as YamlMap;
    if (key == 'dart_sdk') {
      final outputFile = _readString(mapValue['output']);
      if (outputFile == null || outputFile.isEmpty) {
        continue;
      }
      inputs.add(
        CollectorInput(
          outputFile: outputFile,
          source: const DartSdkInputSource(),
          runPubGet: false,
        ),
      );
      continue;
    }
    if (key == 'flutter_sdk') {
      final outputFile = _readString(mapValue['output']);
      if (outputFile == null || outputFile.isEmpty) {
        continue;
      }
      inputs.add(
        CollectorInput(
          outputFile: outputFile,
          source: const FlutterSdkInputSource(),
          runPubGet: false,
        ),
      );
      continue;
    }
    final outputFile = key;
    final source = _parseInputSource(mapValue);
    if (source == null) {
      continue;
    }
    final runPubGet = _readBool(mapValue['run_pub_get']) ?? true;
    inputs.add(
      CollectorInput(
        outputFile: outputFile,
        source: source,
        runPubGet: runPubGet,
      ),
    );
  }

  return inputs;
}

YamlMap? _loadConfigDoc(String packageRoot) {
  final configFile = File(p.join(packageRoot, _configFileName));
  if (!configFile.existsSync()) {
    return null;
  }
  final yamlDoc = loadYaml(configFile.readAsStringSync());
  if (yamlDoc is! YamlMap) {
    return null;
  }
  return yamlDoc;
}

String _readOutputDir(YamlMap? yamlDoc, String packageRoot) {
  if (yamlDoc == null) {
    return p.join(packageRoot, outputDirName);
  }
  final value = _readString(yamlDoc[_configOutputDirKey]);
  if (value == null) {
    return p.join(packageRoot, outputDirName);
  }
  return _resolvePath(packageRoot, value);
}

InputSource? _parseInputSource(YamlMap node) {
  if (_readBool(node['dart']) == true) {
    return const DartSdkInputSource();
  }
  if (_readBool(node['flutter']) == true) {
    return const FlutterSdkInputSource();
  }
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

CollectorInput? _parseShorthandInput(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final lower = trimmed.toLowerCase();
  if (lower == 'dart') {
    return const CollectorInput(
      outputFile: _defaultDartSdkOutput,
      source: DartSdkInputSource(),
      runPubGet: false,
    );
  }
  if (lower == 'flutter') {
    return const CollectorInput(
      outputFile: _defaultFlutterOutput,
      source: FlutterSdkInputSource(),
      runPubGet: false,
    );
  }
  if (lower.startsWith('dart.')) {
    final extension = lower.substring('dart'.length);
    if (_isSupportedOutputExtension(extension)) {
      return CollectorInput(
        outputFile: 'dart_sdk_errors$extension',
        source: const DartSdkInputSource(),
        runPubGet: false,
      );
    }
  }
  if (lower.startsWith('flutter.')) {
    final extension = lower.substring('flutter'.length);
    if (_isSupportedOutputExtension(extension)) {
      return CollectorInput(
        outputFile: 'flutter_errors$extension',
        source: const FlutterSdkInputSource(),
        runPubGet: false,
      );
    }
  }
  return null;
}

bool _isSupportedOutputExtension(String extension) {
  switch (extension) {
    case '.dart':
    case '.json':
    case '.yaml':
    case '.yml':
      return true;
    default:
      return false;
  }
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

bool? _readBool(Object? value) {
  if (value is bool) {
    return value;
  }
  return null;
}

String _resolvePath(String base, String value) {
  if (p.isAbsolute(value)) {
    return value;
  }
  return p.normalize(p.join(base, value));
}
