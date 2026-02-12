import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:throws_plugin/src/gen/dart_sdk_errors.g.dart';
import 'package:throws_plugin/src/gen/flutter_errors.g.dart';
import 'package:yaml/yaml.dart';

const _configFileName = 'throws.yaml';
const _configUseSdkMapKey = 'include_sdk_errors';
const _configIncludePrebuildKey = 'include_prebuilt';
const _configIncludePathsKey = 'include_paths';
const _configIncludeFilesKey = 'include';
const _configCustomErrorsKey = 'custom_errors';

final Map<String, _ThrowsConfig> _userThrowsCache = {};

List<String>? sdkThrowsForElement(Element? element) {
  final executable = element is ExecutableElement ? element.baseElement : null;
  if (executable == null) {
    return null;
  }

  final libraryUri = _normalizeLibraryUri(executable.library.identifier);
  if (libraryUri == null || libraryUri.isEmpty) {
    return null;
  }

  final memberName = executable.name;
  final enclosingName = executable.enclosingElement?.name;
  final enclosing = (enclosingName == null || enclosingName.isEmpty)
      ? null
      : enclosingName;
  if (memberName == null || memberName.isEmpty) {
    return null;
  }

  final key = enclosing == null
      ? '$libraryUri.$memberName'
      : '$libraryUri.$enclosing.$memberName';
  final config = _loadUserThrowsConfig(executable);
  if (config == null) {
    return dartSdkErrors[key];
  }
  final custom = config.map[key];
  if (custom != null) {
    return custom;
  }
  return _prebuiltThrowsForKey(key, config.includePrebuild);
}

bool isSdkThrowingElement(Element? element) {
  return sdkThrowsForElement(element) != null;
}

String? _normalizeLibraryUri(String? identifier) {
  if (identifier == null) {
    return null;
  }
  return identifier == 'dart.core' ? 'dart:core' : identifier;
}

_ThrowsConfig? _loadUserThrowsConfig(ExecutableElement executable) {
  final session = executable.session;
  final root = session?.analysisContext.contextRoot.root;
  final rootPath = root?.path;
  if (rootPath == null || rootPath.isEmpty) {
    return null;
  }

  final cached = _userThrowsCache[rootPath];
  if (cached != null) {
    return cached;
  }

  final file = File('$rootPath/$_configFileName');
  if (!file.existsSync()) {
    _userThrowsCache[rootPath] = const _ThrowsConfig();
    return _userThrowsCache[rootPath];
  }

  try {
    final content = file.readAsStringSync();
    final config = _parseThrowsYaml(content, rootPath);
    _userThrowsCache[rootPath] = config;
    return config;
  } catch (_) {
    _userThrowsCache[rootPath] = const _ThrowsConfig();
    return _userThrowsCache[rootPath];
  }
}

class _ThrowsConfig {
  final Map<String, List<String>> map;
  final List<String> includePrebuild;

  const _ThrowsConfig({
    this.map = const {},
    this.includePrebuild = const [],
  });
}

_ThrowsConfig _parseThrowsYaml(String content, String rootPath) {
  final doc = loadYaml(content);
  if (doc is! YamlMap) {
    return const _ThrowsConfig();
  }

  final throwsNode = doc['throws'];
  if (throwsNode is! YamlMap) {
    return const _ThrowsConfig();
  }

  final includeSdkErrors = _readIncludeSdkErrors(throwsNode);
  final includePrebuild = _readIncludePrebuild(throwsNode);
  if (includeSdkErrors && !includePrebuild.contains('dart')) {
    includePrebuild.add('dart');
  }
  final includeFiles = _readIncludeFiles(throwsNode);

  final result = <String, List<String>>{};
  for (final include in includeFiles) {
    final includePath = _resolveIncludePath(rootPath, include);
    for (final path in _expandIncludePaths(includePath)) {
      final includeMap = _readThrowsFile(path);
      _mergeThrowsMap(result, includeMap);
    }
  }

  final mapNode =
      throwsNode[_configCustomErrorsKey] ??
      throwsNode['map'] ??
      throwsNode['sdk_throws'] ??
      throwsNode;
  final map = _readThrowsMapNode(mapNode);
  _mergeThrowsMap(result, map);
  return _ThrowsConfig(map: result, includePrebuild: includePrebuild);
}

List<String> _readIncludePrebuild(YamlMap throwsNode) {
  final value = throwsNode[_configIncludePrebuildKey];
  if (value is String && value.isNotEmpty) {
    return [value.toLowerCase()];
  }
  if (value is YamlList) {
    return value
        .whereType<String>()
        .map((item) => item.toLowerCase())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return <String>[];
}

List<String> _readIncludeFiles(YamlMap throwsNode) {
  final value =
      throwsNode[_configIncludePathsKey] ?? throwsNode[_configIncludeFilesKey];
  if (value is String && value.isNotEmpty) {
    return [value];
  }
  if (value is YamlList) {
    return value.whereType<String>().where((item) => item.isNotEmpty).toList();
  }
  return const [];
}

String _resolveIncludePath(String rootPath, String includePath) {
  if (includePath.isEmpty) {
    return includePath;
  }
  if (includePath.startsWith('/')) {
    return includePath;
  }
  return '$rootPath/$includePath';
}

List<String> _expandIncludePaths(String path) {
  final directory = Directory(path);
  if (!directory.existsSync()) {
    return [path];
  }

  final entries = directory.listSync();
  final yamlFiles = <String>[];
  for (final entry in entries) {
    if (entry is! File) {
      continue;
    }
    final filePath = entry.path;
    if (filePath.endsWith('.yaml') || filePath.endsWith('.yml')) {
      yamlFiles.add(filePath);
    }
  }
  yamlFiles.sort();
  return yamlFiles;
}

Map<String, List<String>> _readThrowsFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return const {};
  }
  try {
    final doc = loadYaml(file.readAsStringSync());
    if (doc is! YamlMap) {
      return const {};
    }
    final throwsNode = doc['throws'];
    final mapNode = throwsNode is YamlMap
        ? (throwsNode['map'] ?? throwsNode['sdk_throws'] ?? throwsNode)
        : doc;
    return _readThrowsMapNode(mapNode);
  } catch (_) {
    return const {};
  }
}

Map<String, List<String>> _readThrowsMapNode(Object? mapNode) {
  if (mapNode is! YamlMap) {
    return const {};
  }

  final result = <String, List<String>>{};
  for (final entry in mapNode.entries) {
    final key = entry.key;
    if (key is! String) {
      continue;
    }
    final value = entry.value;
    if (value is YamlList) {
      final list = <String>[];
      for (final item in value) {
        if (item is String) {
          list.add(item);
        }
      }
      if (list.isNotEmpty) {
        result[key] = list;
      }
    } else if (value is String) {
      result[key] = [value];
    }
  }
  return result;
}

void _mergeThrowsMap(
  Map<String, List<String>> target,
  Map<String, List<String>> source,
) {
  for (final entry in source.entries) {
    final existing = target[entry.key];
    if (existing == null) {
      target[entry.key] = entry.value.toList();
      continue;
    }
    final merged = {...existing, ...entry.value}.toList();
    target[entry.key] = merged;
  }
}

bool _readIncludeSdkErrors(YamlMap throwsNode) {
  final value = throwsNode[_configUseSdkMapKey];
  if (value is bool) {
    return value;
  }
  return false;
}

List<String>? _prebuiltThrowsForKey(String key, List<String> includePrebuild) {
  for (final entry in includePrebuild) {
    final map = _prebuiltMap(entry);
    if (map == null) {
      continue;
    }
    final value = map[key];
    if (value != null) {
      return value;
    }
  }
  return null;
}

Map<String, List<String>>? _prebuiltMap(String name) {
  switch (name) {
    case 'dart':
      return dartSdkErrors;
    case 'flutter':
      return flutterErrors;
    default:
      return null;
  }
}
