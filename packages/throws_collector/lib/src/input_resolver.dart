import 'dart:io';

import 'package:path/path.dart' as p;

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
}) async {
  return switch (source) {
    LocalInputSource(:final path) => _resolveLocalPath(path, packageRoot),
    GitInputSource(:final url) => _resolveGitPath(url, packageRoot),
    PackageInputSource(:final name, :final version) => _resolvePackagePath(
      name,
      version,
      packageRoot,
    ),
  };
}

_ResolvedSource _resolveLocalPath(String path, String packageRoot) {
  final resolved = _resolvePath(packageRoot, path);
  return _resolvePathToSource(resolved);
}

Future<_ResolvedSource> _resolveGitPath(String url, String packageRoot) async {
  final spec = parseGitSpec(url);
  final repoDir = gitCacheDir(packageRoot, spec);
  await ensureGitRepo(spec, repoDir);

  final targetPath = spec.subPath.isEmpty
      ? repoDir
      : p.normalize(p.join(repoDir, spec.subPath));
  return _resolvePathToSource(targetPath);
}

Future<_ResolvedSource> _resolvePackagePath(
  String name,
  String version,
  String packageRoot,
) async {
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

String _resolvePath(String base, String value) {
  if (p.isAbsolute(value)) {
    return value;
  }
  return p.normalize(p.join(base, value));
}
