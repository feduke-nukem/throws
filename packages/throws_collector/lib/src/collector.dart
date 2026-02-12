import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';

import 'file_finder.dart';
import 'library_identifier.dart';
import 'sdk_library_map.dart';
import 'spinner.dart';
import 'throw_collectors.dart';

Future<Map<String, Set<String>>> collectThrows({
  required String rootPath,
  List<File>? files,
}) async {
  final root = Directory(rootPath).absolute;
  final collection = AnalysisContextCollection(includedPaths: [root.path]);
  final sdkRoot = findSdkRoot(root.path);
  final sdkLibraryMap = loadSdkLibraryMap(sdkRoot);
  final packageName = packageNameFromPubspec(root.path);

  final entries = <String, Set<String>>{};

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
        packageRoot: root.path,
      ),
      sdkLibraryMap,
    );
    final collector = DeclarationCollector(libraryIdentifier);

    resolved.unit.accept(collector);

    for (final entry in collector.entries.entries) {
      final key = entry.key;
      final errors = entry.value;
      if (errors.isEmpty) {
        continue;
      }
      entries.putIfAbsent(key, () => <String>{}).addAll(errors);
    }
  }

  spinner.done(entries.length);
  return entries;
}
