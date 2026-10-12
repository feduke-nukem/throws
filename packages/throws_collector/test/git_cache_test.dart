import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:throws_collector/src/git_cache.dart';

import 'helpers.dart';

Future<void> _git(List<String> args, String dir) async {
  final result = await Process.run('git', [
    '-c',
    'user.name=test',
    '-c',
    'user.email=test@example.com',
    ...args,
  ], workingDirectory: dir);
  expect(result.exitCode, 0, reason: '${result.stderr}');
}

void main() {
  group('parseGitSpec', () {
    test('tree url with ref and sub path', () {
      final spec = parseGitSpec(
        'https://github.com/flutter/flutter/tree/3.41.0/packages/flutter/lib',
      );
      expect(spec.repoUrl, 'https://github.com/flutter/flutter');
      expect(spec.ref, '3.41.0');
      expect(spec.subPath, 'packages/flutter/lib');
    });

    test('blob url with ref only', () {
      final spec = parseGitSpec('https://github.com/a/b/blob/main');
      expect(spec.repoUrl, 'https://github.com/a/b');
      expect(spec.ref, 'main');
      expect(spec.subPath, '');
    });

    test('plain url', () {
      final spec = parseGitSpec('https://github.com/a/b.git');
      expect(spec.repoUrl, 'https://github.com/a/b.git');
      expect(spec.ref, isNull);
      expect(spec.subPath, '');
    });
  });

  test('gitCacheDir sanitizes and truncates the directory name', () {
    final spec = GitSpec(
      repoUrl: 'https://github.com/${'x' * 100}',
      ref: null,
      subPath: '',
    );
    final dir = gitCacheDir('/root', spec);
    expect(
      p.dirname(dir),
      p.join('/root', '.dart_tool', 'throws_collector', 'git'),
    );
    expect(p.basename(dir), hasLength(80));
    expect(p.basename(dir), matches(RegExp(r'^[A-Za-z0-9._-]+$')));
  });

  test('ensureGitRepo clones and then updates a ref', () async {
    final root = await createTempTree({'repo/lib/a.dart': 'void a() {}'});
    final repo = p.join(root, 'repo');
    await _git(['init', '-q', '-b', 'main'], repo);
    await _git(['add', '.'], repo);
    await _git(['commit', '-q', '-m', 'first'], repo);

    final spec = GitSpec(
      repoUrl: Uri.directory(repo).toString(),
      ref: 'main',
      subPath: 'lib',
    );
    final cache = p.join(root, 'cache');
    await ensureGitRepo(spec, cache);
    expect(File(p.join(cache, 'lib', 'a.dart')).existsSync(), isTrue);

    File(p.join(repo, 'lib', 'b.dart')).writeAsStringSync('void b() {}');
    await _git(['add', '.'], repo);
    await _git(['commit', '-q', '-m', 'second'], repo);

    await ensureGitRepo(spec, cache);
    expect(File(p.join(cache, 'lib', 'b.dart')).existsSync(), isTrue);
  });
}
