import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'git_cache.dart';
import 'options.dart';
import 'package_cache.dart';

class ResolvedInput {
  final String rootPath;
  final List<File>? files;
  final String outPath;
  final OutputFormat outputFormat;
  final String mapName;

  const ResolvedInput({
    required this.rootPath,
    required this.files,
    required this.outPath,
    required this.outputFormat,
    required this.mapName,
  });
}

Future<ResolvedInput> resolveInput(
  CollectorInput input,
  CollectorConfig config,
) async {
  final outputDir = config.outputDir;
  final outPath = p.normalize(p.join(outputDir, input.outputFile));
  final outputFormat = resolveOutputFormat(outPath);
  final mapName = deriveMapName(outPath, outputFormat);

  final resolved = await _resolveSource(
    input.source,
    packageRoot: config.packageRoot,
    runPubGet: input.runPubGet,
  );

  return ResolvedInput(
    rootPath: resolved.rootPath,
    files: resolved.files,
    outPath: outPath,
    outputFormat: outputFormat,
    mapName: mapName,
  );
}

class _ResolvedSource {
  final String rootPath;
  final List<File>? files;

  const _ResolvedSource({required this.rootPath, required this.files});
}

Future<_ResolvedSource> _resolveSource(
  InputSource source, {
  required String packageRoot,
  required bool runPubGet,
}) async {
  return switch (source) {
    LocalInputSource(:final path) => _resolveLocalPath(path, packageRoot),
    DartSdkInputSource() => _resolveDartSdkPath(),
    FlutterSdkInputSource() => _resolveFlutterSdkPath(),
    GitInputSource(:final url) => _resolveGitPath(
      url,
      packageRoot,
      runPubGet: runPubGet,
    ),
    PackageInputSource(:final name, :final version) => _resolvePackagePath(
      name,
      version,
      packageRoot,
      runPubGet: runPubGet,
    ),
  };
}

_ResolvedSource _resolveLocalPath(String path, String packageRoot) {
  final resolved = _resolvePath(packageRoot, path);
  return _resolvePathToSource(resolved);
}

Future<_ResolvedSource> _resolveGitPath(
  String url,
  String packageRoot, {
  required bool runPubGet,
}) async {
  final spec = parseGitSpec(url);
  final repoDir = gitCacheDir(packageRoot, spec);
  await ensureGitRepo(spec, repoDir);

  final targetPath = spec.subPath.isEmpty
      ? repoDir
      : p.normalize(p.join(repoDir, spec.subPath));
  if (runPubGet) {
    await _ensurePackageConfig(targetPath);
  }
  return _resolvePathToSource(targetPath);
}

Future<_ResolvedSource> _resolvePackagePath(
  String name,
  String version,
  String packageRoot, {
  required bool runPubGet,
}) async {
  await ensurePackageAvailable(name, version, packageRoot);
  final packagePath = findCachedPackage(name, version, packageRoot);
  if (packagePath == null) {
    throw Exception('Package $name@$version not found in cache.');
  }
  return _resolvePathToSource(packagePath);
}

_ResolvedSource _resolvePathToSource(String path) {
  final type = FileSystemEntity.typeSync(path);
  if (type == FileSystemEntityType.notFound) {
    throw Exception('Input path not found: $path');
  }
  if (type == FileSystemEntityType.file) {
    final file = File(path);
    final root = p.dirname(path);
    return _ResolvedSource(rootPath: root, files: [file]);
  }
  if (type == FileSystemEntityType.directory) {
    return _ResolvedSource(rootPath: path, files: null);
  }
  throw Exception('Unsupported input path: $path');
}

Future<_ResolvedSource> _resolveDartSdkPath() async {
  final sdkRoot = _dartSdkRootFromExecutable();
  final sdkLib = p.join(sdkRoot, 'lib');
  return _resolvePathToSource(sdkLib);
}

Future<_ResolvedSource> _resolveFlutterSdkPath() async {
  final flutterRoot = await _resolveFlutterRoot();
  final flutterLib = p.join(flutterRoot, 'packages', 'flutter', 'lib', 'src');
  return _resolvePathToSource(flutterLib);
}

String _resolvePath(String base, String value) {
  if (p.isAbsolute(value)) {
    return value;
  }
  return p.normalize(p.join(base, value));
}

String _dartSdkRootFromExecutable() {
  final executable = Platform.resolvedExecutable;
  final binDir = p.dirname(executable);
  final sdkRoot = p.dirname(binDir);
  if (!Directory(p.join(sdkRoot, 'lib')).existsSync()) {
    throw Exception('Unable to locate Dart SDK lib directory at $sdkRoot.');
  }
  return sdkRoot;
}

Future<String> _resolveFlutterRoot() async {
  final envRoot = Platform.environment['FLUTTER_ROOT'];
  if (envRoot != null && envRoot.isNotEmpty) {
    return _normalizeFlutterRoot(envRoot);
  }
  final result = await Process.run('flutter', ['--version', '--machine']);
  if (result.exitCode != 0) {
    throw Exception('Failed to run flutter --version --machine.');
  }
  final stdoutText = result.stdout is String ? result.stdout as String : '';
  final data = jsonDecode(stdoutText);
  if (data is Map && data['flutterRoot'] is String) {
    return _normalizeFlutterRoot(data['flutterRoot'] as String);
  }
  throw Exception('Unable to resolve Flutter root from flutter tool output.');
}

String _normalizeFlutterRoot(String root) {
  var normalized = p.normalize(root);
  if (p.basename(normalized) == 'bin') {
    normalized = p.dirname(normalized);
  }
  return normalized;
}

Future<void> _ensurePackageConfig(String path) async {
  final packageRoot = _findPubspecRoot(path);
  if (packageRoot == null) {
    return;
  }
  final packageConfig = File(
    p.join(packageRoot, '.dart_tool', 'package_config.json'),
  );
  if (packageConfig.existsSync()) {
    return;
  }

  final pubspecPath = p.join(packageRoot, 'pubspec.yaml');
  final preferFlutter =
      _usesFlutterPub(pubspecPath) || _hasFlutterSdkMarker(packageRoot);
  var command = preferFlutter ? 'flutter' : 'dart';
  var result = await _runPubGet(command, packageRoot);
  if (result.exitCode != 0) {
    final details = _formatPubGetFailure(result);
    if (!preferFlutter && _isFlutterSdkError(details)) {
      command = 'flutter';
      result = await _runPubGet(command, packageRoot);
      if (result.exitCode == 0) {
        return;
      }
      throw Exception(_formatPubGetFailure(result));
    }
    throw Exception(
      details.isEmpty
          ? 'Failed to run $command pub get in $packageRoot.'
          : details,
    );
  }
}

String? _findPubspecRoot(String path) {
  var current = p.normalize(
    FileSystemEntity.isDirectorySync(path) ? path : p.dirname(path),
  );
  while (true) {
    final pubspecPath = p.join(current, 'pubspec.yaml');
    if (File(pubspecPath).existsSync()) {
      return current;
    }
    final parent = p.dirname(current);
    if (parent == current) {
      return null;
    }
    current = parent;
  }
}

bool _usesFlutterPub(String pubspecPath) {
  try {
    final doc = loadYaml(File(pubspecPath).readAsStringSync());
    if (doc is! YamlMap) {
      return false;
    }
    final deps = [doc['dependencies'], doc['dev_dependencies']];
    for (final node in deps) {
      if (node is YamlMap && node.containsKey('flutter')) {
        return true;
      }
    }
  } catch (_) {
    return false;
  }
  return false;
}

Future<ProcessResult> _runPubGet(String command, String packageRoot) {
  return Process.run(command, const [
    'pub',
    'get',
  ], workingDirectory: packageRoot);
}

String _formatPubGetFailure(ProcessResult result) {
  final stderrOutput = result.stderr is String ? result.stderr as String : '';
  final stdoutOutput = result.stdout is String ? result.stdout as String : '';
  return [
    stderrOutput,
    stdoutOutput,
  ].where((text) => text.trim().isNotEmpty).join('\n');
}

bool _isFlutterSdkError(String details) {
  return details.contains('Flutter users should use `flutter pub`') ||
      details.contains('requires the Flutter SDK');
}

bool _hasFlutterSdkMarker(String packageRoot) {
  return File(p.join(packageRoot, 'bin', 'flutter')).existsSync() ||
      File(p.join(packageRoot, '.metadata')).existsSync();
}
