import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:throws_collector/src/library_identifier.dart';

import 'helpers.dart';

void main() {
  group('normalizeLibraryIdentifier', () {
    test('keeps dart: and package: uris', () {
      expect(normalizeLibraryIdentifier('dart:core', const {}), 'dart:core');
      expect(
        normalizeLibraryIdentifier('package:a/a.dart', const {}),
        'package:a/a.dart',
      );
    });

    test('maps SDK file uris through the library map', () {
      final path = p.normalize('/sdk/lib/core/core.dart');
      expect(
        normalizeLibraryIdentifier(Uri.file(path).toString(), {
          path: 'dart:core',
        }),
        'dart:core',
      );
    });
  });

  test('packageNameFromPubspec', () async {
    final root = await createTempTree({'pubspec.yaml': 'name: demo\n'});
    expect(packageNameFromPubspec(root), 'demo');
    final empty = await createTempTree({'pubspec.yaml': '- not a map'});
    expect(packageNameFromPubspec(empty), isNull);
    expect(packageNameFromPubspec(p.join(root, 'missing')), isNull);
  });

  test('packageInfoForPath finds the nearest pubspec', () async {
    final root = await createPackage({'src/a.dart': ''});
    final info = packageInfoForPath(p.join(root, 'lib', 'src', 'a.dart'))!;
    expect(info.name, 'demo');
    expect(info.root, root);
  });

  test('packageInfoForPath uses packages/<name>/lib layout', () {
    final info = packageInfoForPath(
      p.join('/nowhere', 'packages', 'flutter', 'lib', 'src', 'a.dart'),
    )!;
    expect(info.name, 'flutter');
    expect(info.root, p.join('/nowhere', 'packages', 'flutter'));
  });
}
