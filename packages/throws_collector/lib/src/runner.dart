import 'dart:io';

import 'collector.dart';
import 'dependencies.dart';
import 'input_resolver.dart';
import 'map_writer.dart';
import 'options.dart';

/// Main entry point for the throws_collector package.
///
/// [workingDirectory] defaults to the current directory.
Future<void> run(List<String> args, {String? workingDirectory}) async {
  final config = parseArgs(args, workingDirectory: workingDirectory);
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
    if (input.source case DependenciesInputSource(:final exclude)) {
      await collectDependencies(config, exclude);
      continue;
    }
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
