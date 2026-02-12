import 'dart:io';

import 'collector.dart';
import 'map_writer.dart';
import 'options.dart';

Future<void> run(List<String> args) async {
  final options = parseArgs(args);
  if (options.showHelp) {
    stdout.writeln(usage());
    return;
  }

  final entries = await collectThrows(options);
  await writeMap(
    entries,
    options.outPath,
    options.mapName,
    options.outputFormat,
  );
}
