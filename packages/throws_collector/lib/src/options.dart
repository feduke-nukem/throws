import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

enum OutputFormat { dart, json, yaml }

class CollectorOptions {
  final String root;
  final String outPath;
  final String mapName;
  final String? sdkRoot;
  final OutputFormat outputFormat;
  final bool showHelp;

  const CollectorOptions({
    required this.root,
    required this.outPath,
    required this.mapName,
    required this.sdkRoot,
    required this.outputFormat,
    required this.showHelp,
  });
}

CollectorOptions parseArgs(List<String> args) {
  final config = _loadConfig();
  final parser = _buildParser(config);
  final results = parser.parse(args);
  final packageRoot = _findPackageRoot(Directory.current.path);

  var root = results['root'] as String;
  var outPath = results['out'] as String;
  var sdkRoot = results['sdk-root'] as String?;

  if (results.wasParsed('root')) {
    root = _resolvePathOrSelf(packageRoot, root);
  }
  if (results.wasParsed('out')) {
    outPath = _resolvePathOrSelf(packageRoot, outPath);
  }
  if (results.wasParsed('sdk-root') && sdkRoot != null) {
    sdkRoot = _resolvePathOrSelf(packageRoot, sdkRoot);
  }
  final outputFormat = _resolveOutputFormat(
    outPath,
    _parseOutputFormat(results['format'] as String),
    results.wasParsed('format'),
  );
  final showHelp = results['help'] as bool;
  final mapName = _deriveMapName(outPath, outputFormat);

  return CollectorOptions(
    root: root,
    outPath: outPath,
    mapName: mapName,
    sdkRoot: sdkRoot,
    outputFormat: outputFormat,
    showHelp: showHelp,
  );
}

OutputFormat _parseOutputFormat(String value) => switch (value.toLowerCase()) {
  'dart' => OutputFormat.dart,
  'json' => OutputFormat.json,
  'yaml' => OutputFormat.yaml,
  _ => OutputFormat.dart,
};

OutputFormat _resolveOutputFormat(
  String outPath,
  OutputFormat configured,
  bool formatProvided,
) {
  final extension = p.extension(outPath).toLowerCase();
  if (extension.isEmpty) {
    return configured;
  }
  final inferred = _parseOutputFormatFromExtension(extension);
  if (inferred == null) {
    throw FormatException('Unsupported output file extension: $extension');
  }
  if (formatProvided) {
    return configured;
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

String usage() {
  final parser = _buildParser(const _ConfigValues());
  return [
    'throws_collector: collect throws metadata into a Dart map.',
    '',
    'Usage:',
    '  throws_collector [options]',
    '',
    'Options:',
    parser.usage,
    '',
    'Config:',
    '  Defaults can be provided by throws_collector.yaml.',
  ].join(Platform.lineTerminator);
}

ArgParser _buildParser(_ConfigValues config) {
  return ArgParser()
    ..addOption(
      'root',
      help: 'Root directory to analyze.',
      valueHelp: 'path',
      defaultsTo: config.root ?? '.',
    )
    ..addOption(
      'out',
      help: 'Output file path.',
      valueHelp: 'file',
      defaultsTo: config.outPath ?? 'throws/throws_collector_result.g.dart',
    )
    ..addOption(
      'sdk-root',
      help: 'Optional Dart SDK root for dart: URI mapping.',
      valueHelp: 'path',
      defaultsTo: config.sdkRoot,
    )
    ..addOption(
      'format',
      help: 'Output format: dart, json, yaml.',
      valueHelp: 'value',
      allowed: const ['dart', 'json', 'yaml'],
      defaultsTo: (config.outputFormat ?? OutputFormat.dart).name,
    )
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Show this help message.',
      negatable: false,
    );
}

class _ConfigValues {
  final String? root;
  final String? outPath;
  final String? sdkRoot;
  final OutputFormat? outputFormat;

  const _ConfigValues({
    this.root,
    this.outPath,
    this.sdkRoot,
    this.outputFormat,
  });
}

_ConfigValues _loadConfig() {
  try {
    final packageRoot = _findPackageRoot(Directory.current.path);
    if (packageRoot == null) {
      return const _ConfigValues();
    }
    final configFile = File(p.join(packageRoot, 'throws_collector.yaml'));
    if (!configFile.existsSync()) {
      return const _ConfigValues();
    }

    final yamlDoc = loadYaml(configFile.readAsStringSync());
    if (yamlDoc is! YamlMap) {
      return const _ConfigValues();
    }

    final root = _readString(yamlDoc['root']);
    final outPath = _readString(yamlDoc['out']);
    final sdkRoot = _readString(yamlDoc['sdk_root']);
    final formatValue = _readString(yamlDoc['format']);
    final outputFormat = formatValue == null
        ? null
        : _parseOutputFormat(formatValue);

    return _ConfigValues(
      root: _resolvePath(packageRoot, root),
      outPath: _resolvePath(packageRoot, outPath),
      sdkRoot: _resolvePath(packageRoot, sdkRoot),
      outputFormat: outputFormat,
    );
  } catch (_) {
    return const _ConfigValues();
  }
}

String _deriveMapName(String outPath, OutputFormat format) {
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

String _resolvePathOrSelf(String? base, String value) {
  if (base == null || value.isEmpty || p.isAbsolute(value)) {
    return value;
  }
  return p.normalize(p.join(base, value));
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

String? _resolvePath(String base, String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  if (p.isAbsolute(value)) {
    return value;
  }
  return p.normalize(p.join(base, value));
}
