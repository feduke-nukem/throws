import 'dart:io';

import 'package:git/git.dart';
import 'package:path/path.dart' as p;

class GitSpec {
  final String repoUrl;
  final String? ref;
  final String subPath;

  const GitSpec({
    required this.repoUrl,
    required this.ref,
    required this.subPath,
  });
}

GitSpec parseGitSpec(String url) {
  final treeIndex = url.indexOf('/tree/');
  final blobIndex = url.indexOf('/blob/');
  if (treeIndex != -1 || blobIndex != -1) {
    final index = treeIndex != -1 ? treeIndex : blobIndex;
    final base = url.substring(0, index);
    final rest = url.substring(index + '/tree/'.length);
    if (rest.isEmpty) {
      return GitSpec(repoUrl: base, ref: null, subPath: '');
    }
    final parts = rest.split('/');
    final ref = parts.first;
    final subPath = parts.length > 1 ? parts.sublist(1).join('/') : '';
    return GitSpec(repoUrl: base, ref: ref, subPath: subPath);
  }
  return GitSpec(repoUrl: url, ref: null, subPath: '');
}

String gitCacheDir(String packageRoot, GitSpec spec) {
  final cacheRoot = p.join(
    packageRoot,
    '.dart_tool',
    'throws_collector',
    'git',
  );
  final dirName = _sanitizeDirName('${spec.repoUrl}@${spec.ref ?? 'HEAD'}');
  return p.join(cacheRoot, dirName);
}

Future<void> ensureGitRepo(GitSpec spec, String repoDir) async {
  final directory = Directory(repoDir);
  if (!directory.existsSync()) {
    await _cloneRepo(spec, repoDir);
    return;
  }

  if (spec.ref != null && spec.ref!.isNotEmpty) {
    try {
      _logStatus('Fetching ${spec.repoUrl} (${spec.ref})');
      await runGit(
        ['fetch', '--depth', '1', 'origin', spec.ref!],
        processWorkingDir: repoDir,
        echoOutput: true,
      );
      _logStatus('Checking out ${spec.ref}');
      await runGit(
        ['checkout', '--detach', '-q', 'FETCH_HEAD'],
        processWorkingDir: repoDir,
        echoOutput: true,
      );
    } catch (_) {
      _logStatus('Resetting cache and re-cloning ${spec.repoUrl}');
      await directory.delete(recursive: true);
      await _cloneRepo(spec, repoDir);
    }
  }
}

Future<void> _cloneRepo(GitSpec spec, String repoDir) async {
  Directory(repoDir).parent.createSync(recursive: true);
  _logStatus('Cloning ${spec.repoUrl}');
  final args = ['clone', '--depth', '1'];
  if (spec.ref != null && spec.ref!.isNotEmpty) {
    args.addAll(['--branch', spec.ref!]);
  }
  args.addAll([spec.repoUrl, repoDir]);
  await runGit(args, echoOutput: true);
}

void _logStatus(String message) {
  if (stdout.hasTerminal) {
    stdout.writeln(message);
  }
}

String _sanitizeDirName(String input) {
  final sanitized = input.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  if (sanitized.length <= 80) {
    return sanitized;
  }
  return sanitized.substring(0, 80);
}
