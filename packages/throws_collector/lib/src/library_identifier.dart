import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

String normalizeLibraryIdentifier(
  String identifier,
  Map<String, String> sdkLibraryMap,
) {
  if (identifier.startsWith('dart:')) {
    return identifier;
  }
  final uri = Uri.tryParse(identifier);
  if (uri != null && uri.scheme == 'file') {
    final path = p.normalize(uri.toFilePath());
    final sdkUri = sdkLibraryMap[path];
    if (sdkUri != null) {
      return sdkUri;
    }
  }
  return identifier;
}

String libraryIdentifierFor(
  ResolvedUnitResult result,
  Map<String, String> sdkLibraryMap,
  String? sdkRoot, {
  String? packageName,
  String? packageRoot,
}) {
  var resolvedPackageName = packageName;
  var resolvedPackageRoot = packageRoot;
  if (resolvedPackageName == null || resolvedPackageRoot == null) {
    final info = packageInfoForPath(result.path);
    resolvedPackageName ??= info?.name;
    resolvedPackageRoot ??= info?.root;
  }
  final partOf = _partOfDirective(result.unit);
  if (partOf != null) {
    final partOfUri = partOf.uri?.stringValue;
    if (partOfUri != null && partOfUri.isNotEmpty) {
      if (partOfUri.startsWith('dart:')) {
        return partOfUri;
      }
      final partPath = result.path;
      final baseDir = p.dirname(partPath);
      final libraryPath = p.normalize(p.join(baseDir, partOfUri));
      if (resolvedPackageName != null && resolvedPackageRoot != null) {
        final packageUri = _packageUriForPath(
          libraryPath,
          resolvedPackageRoot,
          resolvedPackageName,
        );
        if (packageUri != null) {
          return packageUri;
        }
      }
      final sdkUri = sdkLibraryMap[libraryPath];
      if (sdkUri != null) {
        return sdkUri;
      }
      if (resolvedPackageName != null && !partOfUri.contains(':')) {
        return _packageUriFromRelativePath(resolvedPackageName, partOfUri);
      }
      return partOfUri;
    }

    final libraryName = partOf.libraryName?.toSource();
    if (libraryName != null && libraryName.isNotEmpty) {
      if (resolvedPackageName != null && resolvedPackageRoot != null) {
        final packageUri = _packageUriForPath(
          result.path,
          resolvedPackageRoot,
          resolvedPackageName,
        );
        if (packageUri != null) {
          return packageUri;
        }
      }
      return _normalizeLibraryName(
        libraryName,
        packageName: resolvedPackageName,
      );
    }
  }

  final library = _libraryDirective(result.unit);
  if (library != null && _isSdkFile(result.path, sdkRoot)) {
    final libraryName = library.name?.toSource();
    if (libraryName != null && libraryName.isNotEmpty) {
      if (resolvedPackageName != null && resolvedPackageRoot != null) {
        final packageUri = _packageUriForPath(
          result.path,
          resolvedPackageRoot,
          resolvedPackageName,
        );
        if (packageUri != null) {
          return packageUri;
        }
      }
      return _normalizeLibraryName(
        libraryName,
        packageName: resolvedPackageName,
      );
    }
  }

  final uri = result.libraryElement.uri.toString();
  if (uri.isNotEmpty) {
    if (resolvedPackageName != null && uri.startsWith('file://')) {
      final mapped = _packageUriForFile(
        uri,
        resolvedPackageRoot,
        resolvedPackageName,
      );
      if (mapped != null) {
        return mapped;
      }
    }
    return uri;
  }
  return result.libraryElement.identifier;
}

String? packageNameFromPubspec(String rootPath) {
  final pubspec = File(p.join(rootPath, 'pubspec.yaml'));
  if (!pubspec.existsSync()) {
    return null;
  }
  try {
    final doc = loadYaml(pubspec.readAsStringSync());
    if (doc is YamlMap) {
      final name = doc['name'];
      if (name is String && name.isNotEmpty) {
        return name;
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

PackageInfo? packageInfoForPath(String filePath) {
  var current = p.normalize(p.dirname(filePath));
  while (true) {
    final pubspec = File(p.join(current, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      try {
        final doc = loadYaml(pubspec.readAsStringSync());
        if (doc is YamlMap) {
          final name = doc['name'];
          if (name is String && name.isNotEmpty) {
            return PackageInfo(name: name, root: current);
          }
        }
      } catch (_) {
        return null;
      }
      return null;
    }
    final parent = p.dirname(current);
    if (parent == current) {
      return null;
    }
    current = parent;
  }
}

class PackageInfo {
  final String name;
  final String root;

  const PackageInfo({required this.name, required this.root});
}

PartOfDirective? _partOfDirective(CompilationUnit unit) {
  for (final directive in unit.directives) {
    if (directive is PartOfDirective) {
      return directive;
    }
  }
  return null;
}

LibraryDirective? _libraryDirective(CompilationUnit unit) {
  for (final directive in unit.directives) {
    if (directive is LibraryDirective) {
      return directive;
    }
  }
  return null;
}

bool _isSdkFile(String path, String? sdkRoot) {
  if (sdkRoot == null || sdkRoot.isEmpty) {
    return false;
  }
  return p.isWithin(p.normalize(sdkRoot), p.normalize(path));
}

String? _packageUriForFile(
  String fileUri,
  String? packageRoot,
  String packageName,
) {
  if (packageRoot == null || packageRoot.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(fileUri);
  if (uri == null || uri.scheme != 'file') {
    return null;
  }
  final filePath = p.normalize(uri.toFilePath());
  return _packageUriForPath(filePath, packageRoot, packageName);
}

String _normalizeLibraryName(String libraryName, {String? packageName}) {
  if (libraryName.startsWith('dart.dom.')) {
    return 'dart:${libraryName.substring('dart.dom.'.length)}';
  }
  if (libraryName.startsWith('dart.')) {
    return 'dart:${libraryName.substring('dart.'.length)}';
  }
  if (libraryName.startsWith('dart:')) {
    return libraryName;
  }
  if (packageName != null && !libraryName.contains(':')) {
    final suffix = libraryName.endsWith('.dart')
        ? libraryName
        : '$libraryName.dart';
    return 'package:$packageName/$suffix';
  }
  return libraryName;
}

String _packageUriFromRelativePath(String packageName, String path) {
  final normalized = p.normalize(path).replaceAll(p.separator, '/');
  return 'package:$packageName/$normalized';
}

String? _packageUriForPath(
  String filePath,
  String packageRoot,
  String packageName,
) {
  final libRoot = p.normalize(p.join(packageRoot, 'lib'));
  final normalizedPath = p.normalize(filePath);
  if (!p.isWithin(libRoot, normalizedPath) && normalizedPath != libRoot) {
    return null;
  }
  final relPath = p.relative(normalizedPath, from: libRoot);
  return 'package:$packageName/$relPath';
}
