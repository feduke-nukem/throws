import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

String? findSdkRoot(String startPath) {
  var current = p.normalize(startPath);
  while (true) {
    final candidate = p.join(current, 'lib', 'libraries.json');
    if (File(candidate).existsSync()) {
      return current;
    }
    final parent = p.dirname(current);
    if (parent == current) {
      return null;
    }
    current = parent;
  }
}

Map<String, String> loadSdkLibraryMap(String? sdkRootPath) {
  if (sdkRootPath == null || sdkRootPath.isEmpty) {
    return const {};
  }
  final file = File(p.join(sdkRootPath, 'lib', 'libraries.json'));
  if (!file.existsSync()) {
    return const {};
  }
  try {
    final content = file.readAsStringSync();
    final json = jsonDecode(content);
    if (json is! Map<String, dynamic>) {
      return const {};
    }
    final result = <String, String>{};
    for (final targetEntry in json.entries) {
      final target = targetEntry.value;
      if (target is! Map<String, dynamic>) {
        continue;
      }
      final libs = target['libraries'];
      if (libs is! Map<String, dynamic>) {
        continue;
      }
      for (final entry in libs.entries) {
        final libName = entry.key;
        final data = entry.value;
        if (data is! Map<String, dynamic>) {
          continue;
        }
        final uri = data['uri'];
        final patches = data['patches'];
        if (uri is! String) {
          continue;
        }
        final fullPath = p.normalize(p.join(sdkRootPath, 'lib', uri));
        result[fullPath] = 'dart:$libName';
        if (patches is String) {
          final patchPath = p.normalize(p.join(sdkRootPath, 'lib', patches));
          result[patchPath] = 'dart:$libName';
        } else if (patches is List) {
          for (final patch in patches) {
            if (patch is! String) {
              continue;
            }
            final patchPath = p.normalize(p.join(sdkRootPath, 'lib', patch));
            result[patchPath] = 'dart:$libName';
          }
        }
      }
    }
    return result;
  } catch (_) {
    return const {};
  }
}
