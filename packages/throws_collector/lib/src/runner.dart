import 'dart:io';

import 'collector.dart';
import 'input_resolver.dart';
import 'map_writer.dart';
import 'options.dart';

/// Main entry point for the throws_collector package.
Future<void> run(List<String> args) async {
  final config = parseArgs(args);
  if (config.showHelp) {
    stdout.writeln(usage());
    return;
  }
  if (config.inputs.isEmpty) {
    stderr.writeln('No inputs configured in throws_collector.yaml.');
    stdout.writeln(usage());
    return;
  }

  Directory(config.outputDir).createSync(recursive: true);

  for (final input in config.inputs) {
    stdout.writeln('Resolving input: ${input.outputFile}');
    final resolved = await resolveInput(input, config);
    stdout.writeln('Analyzing: ${resolved.rootPath}');
    final entries = await collectThrows(
      rootPath: resolved.rootPath,
      files: resolved.files,
    );
    await writeMap(
      entries,
      resolved.outPath,
      resolved.mapName,
      resolved.outputFormat,
    );
    stdout.writeln('Wrote: ${resolved.outPath}');
  }
}
