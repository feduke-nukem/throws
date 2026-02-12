import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

Future<void> ensurePackageAvailable(
  String name,
  String version,
  String packageRoot,
) async {
  _logStatus('Resolving package $name@$version');
  await _ensurePubPackage(name, version);
  if (findCachedPackage(name, version, packageRoot) != null) {
    return;
  }
  _logStatus('Downloading $name@$version from pub.dev');
  await _downloadPackageToCache(name, version, packageRoot);
}

String? findCachedPackage(String name, String version, String packageRoot) {
  final collectorCache = _collectorPubCacheRoot(packageRoot);
  final localCandidate = p.join(collectorCache, '$name-$version');
  if (Directory(localCandidate).existsSync()) {
    return localCandidate;
  }
  final pubCache = _pubCacheRoot();
  final hostedDirs = [
    p.join(pubCache, 'hosted', 'pub.dev'),
    p.join(pubCache, 'hosted', 'pub.dartlang.org'),
  ];
  final dirName = '$name-$version';
  for (final hosted in hostedDirs) {
    final candidate = p.join(hosted, dirName);
    if (Directory(candidate).existsSync()) {
      return candidate;
    }
  }
  return null;
}

Future<void> _ensurePubPackage(String name, String version) async {
  _logStatus('Checking pub cache for $name@$version');
  await _runProcess('dart', [
    'pub',
    'cache',
    'add',
    name,
    '--version',
    version,
  ], 'Failed to download $name@$version');
}

void _logStatus(String message) {
  if (stdout.hasTerminal) {
    stdout.writeln(message);
  }
}

String _collectorPubCacheRoot(String packageRoot) {
  return p.join(packageRoot, '.dart_tool', 'throws_collector', 'pub');
}

String _pubCacheRoot() {
  final env = Platform.environment['PUB_CACHE'];
  if (env != null && env.isNotEmpty) {
    return env;
  }
  final home = Platform.environment['HOME'] ?? '';
  return p.join(home, '.pub-cache');
}

Future<void> _downloadPackageToCache(
  String name,
  String version,
  String packageRoot,
) async {
  final targetRoot = _collectorPubCacheRoot(packageRoot);
  final targetDir = Directory(p.join(targetRoot, '$name-$version'));
  if (targetDir.existsSync()) {
    return;
  }

  final apiUrl = Uri.parse(
    'https://pub.dev/api/packages/$name/versions/$version',
  );
  final apiResponse = await http.get(apiUrl);
  if (apiResponse.statusCode != 200) {
    throw Exception('Failed to fetch package metadata for $name@$version.');
  }

  final archiveUrl = _extractArchiveUrl(apiResponse.body);
  if (archiveUrl == null) {
    throw Exception('Missing archive URL for $name@$version.');
  }

  final archiveResponse = await http.get(Uri.parse(archiveUrl));
  if (archiveResponse.statusCode != 200) {
    throw Exception('Failed to download $name@$version archive.');
  }

  final tempDir = await Directory.systemTemp.createTemp(
    'throws_collector_pkg_',
  );
  try {
    final archive = _decodeTarGzip(archiveResponse.bodyBytes);
    extractArchiveToDisk(archive, tempDir.path);

    final packageDir = Directory(p.join(tempDir.path, 'package'));
    if (packageDir.existsSync()) {
      targetDir.parent.createSync(recursive: true);
      await packageDir.rename(targetDir.path);
      return;
    }

    targetDir.createSync(recursive: true);
    _copyDirectory(tempDir, targetDir);
  } finally {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  }
}

Archive _decodeTarGzip(List<int> bytes) {
  return TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
}

String? _extractArchiveUrl(String body) {
  final archiveUrlMatch = RegExp(
    r'"archive_url"\s*:\s*"([^"]+)"',
  ).firstMatch(body);
  return archiveUrlMatch?.group(1);
}

void _copyDirectory(Directory source, Directory destination) {
  for (final entity in source.listSync(recursive: false)) {
    final name = p.basename(entity.path);
    if (entity is Directory) {
      final targetDir = Directory(p.join(destination.path, name));
      targetDir.createSync(recursive: true);
      _copyDirectory(entity, targetDir);
    } else if (entity is File) {
      entity.copySync(p.join(destination.path, name));
    }
  }
}

Future<void> _runProcess(
  String command,
  List<String> args,
  String errorMessage,
) async {
  final result = await Process.run(command, args);
  if (result.exitCode != 0) {
    final stderrOutput = result.stderr is String ? result.stderr as String : '';
    final stdoutOutput = result.stdout is String ? result.stdout as String : '';
    final details = [
      stderrOutput,
      stdoutOutput,
    ].where((text) => text.trim().isNotEmpty).join('\n');
    throw Exception(details.isEmpty ? errorMessage : '$errorMessage\n$details');
  }
}
