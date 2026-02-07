import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:yaml/yaml.dart';

const _dartCoreUri = 'dart:core';
const _iterable = 'Iterable';
const _list = 'List';
const _string = 'String';
const _int = 'int';
const _double = 'double';
const _num = 'num';
const _dateTime = 'DateTime';
const _uri = 'Uri';

const _configFileName = 'throws.yaml';

const _stateError = 'StateError';
const _rangeError = 'RangeError';
const _formatException = 'FormatException';

const Map<String, List<String>> _sdkThrowsMap = {
  '$_dartCoreUri.$_iterable.single': [_stateError],
  '$_dartCoreUri.$_iterable.first': [_stateError],
  '$_dartCoreUri.$_iterable.last': [_stateError],
  '$_dartCoreUri.$_iterable.elementAt': [_rangeError],
  '$_dartCoreUri.$_iterable.reduce': [_stateError],
  '$_dartCoreUri.$_list.single': [_stateError],
  '$_dartCoreUri.$_list.first': [_stateError],
  '$_dartCoreUri.$_list.last': [_stateError],
  '$_dartCoreUri.$_list.elementAt': [_rangeError],
  '$_dartCoreUri.$_list.[]': [_rangeError],
  '$_dartCoreUri.$_string.substring': [_rangeError],
  '$_dartCoreUri.$_string.codeUnitAt': [_rangeError],
  '$_dartCoreUri.$_string.[]': [_rangeError],
  '$_dartCoreUri.$_int.parse': [_formatException],
  '$_dartCoreUri.$_double.parse': [_formatException],
  '$_dartCoreUri.$_num.parse': [_formatException],
  '$_dartCoreUri.$_dateTime.parse': [_formatException],
  '$_dartCoreUri.$_uri.parse': [_formatException],
};

final Map<String, Map<String, List<String>>> _userThrowsCache = {};

List<String>? sdkThrowsForElement(Element? element) {
  final executable = element is ExecutableElement ? element : null;
  if (executable == null) {
    return null;
  }

  final libraryUri = _normalizeLibraryUri(executable.library.identifier);
  if (libraryUri == null || libraryUri.isEmpty) {
    return null;
  }

  final memberName = executable.name;
  final enclosing = executable.enclosingElement?.name;
  if (memberName == null || memberName.isEmpty) {
    return null;
  }

  final key = enclosing == null
      ? '$libraryUri.$memberName'
      : '$libraryUri.$enclosing.$memberName';
  final userMap = _loadUserThrowsMap(executable);
  return userMap[key] ?? _sdkThrowsMap[key];
}

bool isSdkThrowingElement(Element? element) {
  return sdkThrowsForElement(element) != null;
}

String? _normalizeLibraryUri(String? identifier) {
  if (identifier == null) {
    return null;
  }
  return identifier == 'dart.core' ? _dartCoreUri : identifier;
}

Map<String, List<String>> _loadUserThrowsMap(ExecutableElement executable) {
  final session = executable.session;
  final root = session?.analysisContext.contextRoot.root;
  final rootPath = root?.path;
  if (rootPath == null || rootPath.isEmpty) {
    return const {};
  }

  final cached = _userThrowsCache[rootPath];
  if (cached != null) {
    return cached;
  }

  final file = File('$rootPath/$_configFileName');
  if (!file.existsSync()) {
    _userThrowsCache[rootPath] = const {};
    return const {};
  }

  try {
    final content = file.readAsStringSync();
    final map = _parseThrowsYaml(content);
    _userThrowsCache[rootPath] = map;
    return map;
  } catch (_) {
    _userThrowsCache[rootPath] = const {};
    return const {};
  }
}

Map<String, List<String>> _parseThrowsYaml(String content) {
  final doc = loadYaml(content);
  if (doc is! YamlMap) {
    return const {};
  }

  final throwsNode = doc['throws'];
  if (throwsNode is! YamlMap) {
    return const {};
  }

  final mapNode = throwsNode['map'] ?? throwsNode['sdk_throws'] ?? throwsNode;
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
