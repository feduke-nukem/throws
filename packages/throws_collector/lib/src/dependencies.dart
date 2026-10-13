import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'collector.dart';
import 'file_finder.dart';
import 'map_writer.dart';
import 'options.dart';

/// Writes `<package>.yaml` to [CollectorConfig.outputDir] for every package
/// in pubspec.lock, except SDK packages and [exclude].
///
/// Files resolve through the project's package config, so dependencies need
/// no `pub get` of their own. A package whose locked version matches the
/// stamp in its output is skipped; path packages are always collected.
Future<void> collectDependencies(
  CollectorConfig config,
  Set<String> exclude,
) async {
  final root = config.packageRoot;
  final packageDirs = _packageDirs(root);
  // Created on first use: nothing to analyze when every output is current.
  late final context = AnalysisContextCollection(
    includedPaths: [root],
  ).contextFor(p.join(root, 'pubspec.yaml'));

  for (final package in _lockedPackages(root)) {
    if (package.source == 'sdk' || exclude.contains(package.name)) {
      continue;
    }
    final dir = packageDirs[package.name];
    if (dir == null) {
      throw Exception(
        '${package.name} is missing from .dart_tool/package_config.json. '
        'Run pub get.',
      );
    }
    final outPath = p.join(config.outputDir, '${package.name}.yaml');
    final stamp = '# ${package.name} ${package.version}';
    if (package.source != 'path' && _firstLine(outPath) == stamp) {
      stdout.writeln('Up to date: ${package.name}');
      continue;
    }

    final lib = Directory(p.join(dir, 'lib'));
    stdout.writeln('Analyzing: ${package.name} ${package.version}');
    final entries = lib.existsSync()
        ? await collectThrowsInContext(context, listDartFiles(lib).toList())
        : <String, Map<String, Set<String>>>{};
    await writeMap(
      entries,
      outPath,
      package.name,
      OutputFormat.yaml,
      yamlHeader: stamp,
    );
    stdout.writeln('Wrote: $outPath');
  }
}

class _LockedPackage {
  final String name;
  final String source;

  /// Version, plus the commit for git packages.
  final String version;

  const _LockedPackage(this.name, this.source, this.version);
}

List<_LockedPackage> _lockedPackages(String root) {
  final file = File(p.join(root, 'pubspec.lock'));
  if (!file.existsSync()) {
    throw Exception('pubspec.lock not found in $root. Run pub get.');
  }
  final packages = (loadYaml(file.readAsStringSync()) as YamlMap)['packages'];
  if (packages is! YamlMap) {
    return const [];
  }
  return [
    for (final MapEntry(:key, :value) in packages.entries)
      if (key is String && value is YamlMap)
        _LockedPackage(
          key,
          '${value['source']}',
          [
            '${value['version']}',
            if (value['description'] case {'resolved-ref': final String ref})
              ref,
          ].join(' '),
        ),
  ];
}

/// Package roots from .dart_tool/package_config.json.
Map<String, String> _packageDirs(String root) {
  final file = File(p.join(root, '.dart_tool', 'package_config.json'));
  if (!file.existsSync()) {
    throw Exception('${file.path} not found. Run pub get.');
  }
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return {
    for (final package in (json['packages'] as List).cast<Map>())
      package['name'] as String: p.normalize(
        file.parent.uri.resolve(package['rootUri'] as String).toFilePath(),
      ),
  };
}

String? _firstLine(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  return const LineSplitter().convert(file.readAsStringSync()).firstOrNull;
}
