import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';

import 'file_finder.dart';
import 'library_identifier.dart';
import 'sdk_library_map.dart';
import 'spinner.dart';
import 'throw_collectors.dart';

/// Errors per library URI, then per member path.
Future<Map<String, Map<String, Set<String>>>> collectThrows({
  required String rootPath,
  List<File>? files,
}) async {
  final root = Directory(rootPath).absolute;
  final collection = AnalysisContextCollection(includedPaths: [root.path]);
  final sdkRoot = findSdkRoot(root.path);
  final sdkLibraryMap = loadSdkLibraryMap(sdkRoot);
  final packageInfo = packageInfoForPath(root.path);
  final packageName = packageInfo?.name ?? packageNameFromPubspec(root.path);
  final packageRoot = packageInfo?.root;

  final entries = <String, Map<String, Set<String>>>{};

  final resolvedFiles = files ?? listDartFiles(root).toList();
  final spinner = Spinner(total: resolvedFiles.length);

  for (var index = 0; index < resolvedFiles.length; index++) {
    final file = resolvedFiles[index];
    spinner.tick(index + 1, file.path);

    final context = collection.contextFor(file.path);
    final resolved = await context.currentSession.getResolvedUnit(file.path);
    if (resolved is! ResolvedUnitResult) {
      throw Exception('Failed to analyze ${file.path}');
    }

    final libraryIdentifier = normalizeLibraryIdentifier(
      libraryIdentifierFor(
        resolved,
        sdkLibraryMap,
        sdkRoot,
        packageName: packageName,
        packageRoot: packageRoot,
      ),
      sdkLibraryMap,
    );
    _addUnit(entries, resolved, libraryIdentifier);
  }

  spinner.done(
    entries.values.fold(0, (count, members) => count + members.length),
  );
  return entries;
}

/// Errors of [files] resolved in [context], keyed by their library URIs.
///
/// Used for dependencies, whose files resolve through the package config of
/// the project that depends on them.
Future<Map<String, Map<String, Set<String>>>> collectThrowsInContext(
  AnalysisContext context,
  List<File> files,
) async {
  final entries = <String, Map<String, Set<String>>>{};
  final spinner = Spinner(total: files.length);
  for (var index = 0; index < files.length; index++) {
    final path = files[index].absolute.path;
    spinner.tick(index + 1, path);
    final resolved = await context.currentSession.getResolvedUnit(path);
    if (resolved is! ResolvedUnitResult) {
      throw Exception('Failed to analyze $path');
    }
    _addUnit(entries, resolved, resolved.libraryElement.uri.toString());
  }
  spinner.done(
    entries.values.fold(0, (count, members) => count + members.length),
  );
  return entries;
}

void _addUnit(
  Map<String, Map<String, Set<String>>> entries,
  ResolvedUnitResult resolved,
  String libraryIdentifier,
) {
  final collector = DeclarationCollector(libraryIdentifier);
  resolved.unit.accept(collector);
  for (final entry in collector.entries.entries) {
    if (entry.value.isEmpty) {
      continue;
    }
    ((entries[libraryIdentifier] ??= {})[entry.key] ??= {}).addAll(entry.value);
  }
}
