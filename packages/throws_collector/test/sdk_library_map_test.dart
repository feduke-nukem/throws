import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:throws_collector/src/sdk_library_map.dart';

import 'helpers.dart';

void main() {
  test('findSdkRoot walks up to lib/libraries.json', () async {
    final root = await createTempTree({
      'lib/libraries.json': '{}',
      'lib/core/core.dart': '',
    });
    expect(findSdkRoot(p.join(root, 'lib', 'core')), root);
  });

  test('findSdkRoot returns null outside an SDK', () async {
    final root = await createTempTree({'a.dart': ''});
    expect(findSdkRoot(root), isNull);
  });

  test('loadSdkLibraryMap maps library and patch files', () async {
    final root = await createTempTree({
      'lib/libraries.json': jsonEncode({
        'vm': {
          'libraries': {
            'core': {
              'uri': 'core/core.dart',
              'patches': ['_internal/core_patch.dart'],
            },
            'io': {'uri': 'io/io.dart', 'patches': 'io_patch.dart'},
            'broken': {'patches': 'x.dart'},
          },
        },
        'comment': 'not a target',
      }),
    });
    final map = loadSdkLibraryMap(root);
    String lib(String path) => p.join(root, 'lib', path);
    expect(map, {
      lib('core/core.dart'): 'dart:core',
      lib('_internal/core_patch.dart'): 'dart:core',
      lib('io/io.dart'): 'dart:io',
      lib('io_patch.dart'): 'dart:io',
    });
  });

  test('loadSdkLibraryMap tolerates missing or invalid files', () async {
    expect(loadSdkLibraryMap(null), isEmpty);
    final root = await createTempTree({'lib/libraries.json': 'not json'});
    expect(loadSdkLibraryMap(root), isEmpty);
  });
}
