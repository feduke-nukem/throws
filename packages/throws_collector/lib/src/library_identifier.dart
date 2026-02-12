import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

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
  String? sdkRoot,
) {
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
      final sdkUri = sdkLibraryMap[libraryPath];
      if (sdkUri != null) {
        return sdkUri;
      }
      return partOfUri;
    }

    final libraryName = partOf.libraryName?.toSource();
    if (libraryName != null && libraryName.isNotEmpty) {
      return _normalizeLibraryName(libraryName);
    }
  }

  final library = _libraryDirective(result.unit);
  if (library != null && _isSdkFile(result.path, sdkRoot)) {
    final libraryName = library.name?.toSource();
    if (libraryName != null && libraryName.isNotEmpty) {
      return _normalizeLibraryName(libraryName);
    }
  }

  final uri = result.libraryElement.uri.toString();
  if (uri.isNotEmpty) {
    return uri;
  }
  return result.libraryElement.identifier;
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

String _normalizeLibraryName(String libraryName) {
  if (libraryName.startsWith('dart.dom.')) {
    return 'dart:${libraryName.substring('dart.dom.'.length)}';
  }
  if (libraryName.startsWith('dart.')) {
    return 'dart:${libraryName.substring('dart.'.length)}';
  }
  if (libraryName.startsWith('dart:')) {
    return libraryName;
  }
  return libraryName;
}
