import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:throws_plugin/src/utils/throws_analyzer.dart';

/// Times the plugin's analysis per resolved unit, excluding resolution.
///
/// Usage: `dart run tool/benchmark.dart <directory>` (a directory of a
/// project after `pub get`; its throws.yaml applies).
Future<void> main(List<String> args) async {
  final root = Directory(args[0]).absolute.path;
  final collection = AnalysisContextCollection(includedPaths: [root]);
  final files = Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.path)
      .toList();
  final resolveWatch = Stopwatch()..start();
  final units = <String, ResolvedUnitResult>{};
  for (final path in files) {
    final result = await collection
        .contextFor(path)
        .currentSession
        .getResolvedUnit(path);
    if (result is ResolvedUnitResult) units[path] = result;
  }
  resolveWatch.stop();

  for (final round in [1, 2]) {
    final times = <(int, String)>[];
    final total = Stopwatch()..start();
    var summaries = 0;
    for (final MapEntry(:key, :value) in units.entries) {
      final watch = Stopwatch()..start();
      summaries += ThrowsAnalyzer.analyze(value.unit).summaries.length;
      times.add((watch.elapsedMicroseconds, key));
    }
    total.stop();
    times.sort((a, b) => a.$1.compareTo(b.$1));
    int p(double q) => times[((times.length - 1) * q).round()].$1;
    print(
      'round $round: ${units.length} units, $summaries summaries, '
      'total ${total.elapsedMilliseconds} ms, '
      'p50 ${p(.5) / 1000} ms, p95 ${p(.95) / 1000} ms, '
      'max ${times.last.$1 / 1000} ms (${times.last.$2.split('/').last})',
    );
  }
  print('resolution (for reference): ${resolveWatch.elapsedMilliseconds} ms');
}
