import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:throws_plugin/src/gen/dart_sdk_errors.g.dart';
import 'package:throws_plugin/src/gen/flutter_errors.g.dart';
import 'package:yaml/yaml.dart';

const _configFileName = 'throws.yaml';

/// Error type names per library URI, then per member (`Class.member`,
/// `Class.new`, `Class.named` or a top-level `member`).
typedef ErrorsMap = Map<String, Map<String, List<String>>>;

const _prebuilt = <String, ErrorsMap>{
  'dart': dartSdkErrors,
  'flutter': flutterErrors,
};

/// User configuration read from throws.yaml at the analysis context root:
///
/// ```yaml
/// throws:
///   track: [exception, error]
///   prebuilt: [dart, flutter]
///   include:
///     - throws_collector_gen/
///   members:
///     dart:core:
///       Iterable.single: [StateError]
/// ```
class ThrowsConfig {
  /// Errors from `members` and `include` files.
  final ErrorsMap members;

  /// Names of prebuilt maps to consult after [members].
  final List<String> prebuilt;

  /// Whether subtypes of [Error] are tracked.
  final bool trackErrors;

  /// Whether subtypes of [Exception] are tracked.
  final bool trackExceptions;

  const ThrowsConfig({
    this.members = const {},
    this.prebuilt = const [],
    this.trackErrors = true,
    this.trackExceptions = true,
  });

  static final _cache = Expando<ThrowsConfig>();

  /// Config for the analysis context of [session].
  ///
  /// Cached per session, so edits to throws.yaml apply once the session is
  /// replaced (on the next file change).
  static ThrowsConfig of(AnalysisSession? session) {
    if (session == null) {
      return const ThrowsConfig();
    }
    return _cache[session] ??= _load(session.analysisContext.contextRoot.root);
  }

  /// Error type names for [element] from throws.yaml or prebuilt maps.
  List<String>? errorNamesFor(ExecutableElement element) {
    final executable = element.baseElement;
    final member = _memberPath(executable);
    if (member == null) {
      return null;
    }
    final library = executable.library.uri.toString();
    for (final map in [
      members,
      for (final name in prebuilt) ?_prebuilt[name],
    ]) {
      final errors = map[library]?[member];
      if (errors != null) {
        return errors;
      }
    }
    return null;
  }

  /// Whether thrown [type] is checked under the `track` option.
  ///
  /// Types that are neither [Error] nor [Exception] are always tracked.
  bool tracks(DartType type) {
    if (type is! InterfaceType) {
      return true;
    }
    final isError = _isCoreSubtype(type, 'Error');
    final isException = _isCoreSubtype(type, 'Exception');
    if (!isError && !isException) {
      return true;
    }
    return (isError && trackErrors) || (isException && trackExceptions);
  }
}

bool _isCoreSubtype(InterfaceType type, String name) {
  bool isCore(InterfaceType t) =>
      t.element.name == name && t.element.library.isDartCore;
  return isCore(type) || type.allSupertypes.any(isCore);
}

/// `Class.member` for members, `member` for top-level functions.
String? _memberPath(ExecutableElement executable) {
  final name = executable.name;
  if (name == null || name.isEmpty) {
    return null;
  }
  final enclosing = executable.enclosingElement;
  if (enclosing is LibraryElement) {
    return name;
  }
  final enclosingName = enclosing?.name;
  if (enclosingName == null || enclosingName.isEmpty) {
    return null;
  }
  return '$enclosingName.$name';
}

ThrowsConfig _load(Folder root) {
  final file = root.getFile(_configFileName);
  if (!file.exists) {
    return const ThrowsConfig();
  }

  try {
    return _parse(file.readAsStringSync(), root);
  } catch (_) {
    return const ThrowsConfig();
  }
}

ThrowsConfig _parse(String content, Folder root) {
  final doc = loadYaml(content);
  final node = doc is YamlMap ? doc['throws'] : null;
  if (node is! YamlMap) {
    return const ThrowsConfig();
  }

  final members = <String, Map<String, List<String>>>{};
  for (final include in _strings(node['include']) ?? const <String>[]) {
    for (final file in _expandInclude(root, include)) {
      _merge(members, _readErrorsFile(file));
    }
  }
  _merge(members, _readErrorsMap(node['members']));

  final track = _strings(node['track']);
  return ThrowsConfig(
    members: members,
    prebuilt: _strings(node['prebuilt']) ?? const [],
    trackErrors: track == null || track.contains('error'),
    trackExceptions: track == null || track.contains('exception'),
  );
}

/// A string or a list of strings; null when absent.
List<String>? _strings(Object? value) {
  if (value is String) {
    return [value];
  }
  if (value is YamlList) {
    return value.whereType<String>().toList();
  }
  return null;
}

/// Reads `library: {member: [Error, ...]}`; malformed entries are skipped.
ErrorsMap _readErrorsMap(Object? node) {
  if (node is! YamlMap) {
    return const {};
  }
  final result = <String, Map<String, List<String>>>{};
  for (final library in node.entries) {
    final libraryUri = library.key;
    final libraryMembers = library.value;
    if (libraryUri is! String || libraryMembers is! YamlMap) {
      continue;
    }
    for (final member in libraryMembers.entries) {
      final errors = _strings(member.value);
      if (member.key is String && errors != null && errors.isNotEmpty) {
        (result[libraryUri] ??= {})[member.key as String] = errors;
      }
    }
  }
  return result;
}

List<File> _expandInclude(Folder root, String include) {
  final pathContext = root.provider.pathContext;
  final path = pathContext.isAbsolute(include)
      ? include
      : pathContext.join(root.path, include);
  final resource = root.provider.getResource(pathContext.normalize(path));

  if (resource is File) {
    return [resource];
  }
  if (resource is! Folder || !resource.exists) {
    return const [];
  }

  return resource
      .getChildren()
      .whereType<File>()
      .where(
        (file) => file.path.endsWith('.yaml') || file.path.endsWith('.yml'),
      )
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

ErrorsMap _readErrorsFile(File file) {
  if (!file.exists) {
    return const {};
  }
  try {
    return _readErrorsMap(loadYaml(file.readAsStringSync()));
  } catch (_) {
    return const {};
  }
}

void _merge(ErrorsMap target, ErrorsMap source) {
  for (final library in source.entries) {
    final members = target[library.key] ??= {};
    for (final member in library.value.entries) {
      members[member.key] = {
        ...?members[member.key],
        ...member.value,
      }.toList();
    }
  }
}
