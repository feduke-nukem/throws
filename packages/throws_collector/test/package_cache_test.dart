import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:throws_collector/src/package_cache.dart';

import 'helpers.dart';

void main() {
  test('finds a package in the collector cache', () async {
    final root = await createTempTree({
      '.dart_tool/throws_collector/pub/bloc-9.2.0/pubspec.yaml': 'name: bloc',
    });
    expect(
      findCachedPackage('bloc', '9.2.0', root),
      p.join(root, '.dart_tool', 'throws_collector', 'pub', 'bloc-9.2.0'),
    );
  });

  test('returns null for a missing package', () async {
    final root = await createTempTree({});
    expect(findCachedPackage('surely_missing_pkg', '0.0.0-none', root), isNull);
  });
}
