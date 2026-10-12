import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:throws_collector/src/input_resolver.dart';
import 'package:throws_collector/src/options.dart';

import 'helpers.dart';

CollectorConfig _config(String root) => CollectorConfig(
  packageRoot: root,
  outputDir: p.join(root, 'gen'),
  inputs: const [],
  showHelp: false,
);

void main() {
  test('resolves a local directory', () async {
    final root = await createTempTree({'lib/a.dart': ''});
    final resolved = await resolveInput(
      const CollectorInput(
        outputFile: 'my_errors.g.dart',
        source: LocalInputSource('lib'),
        runPubGet: false,
      ),
      _config(root),
    );
    expect(resolved.rootPath, p.join(root, 'lib'));
    expect(resolved.files, isNull);
    expect(resolved.outPath, p.join(root, 'gen', 'my_errors.g.dart'));
    expect(resolved.outputFormat, OutputFormat.dart);
    expect(resolved.mapName, 'myErrors');
  });

  test('resolves a single local file', () async {
    final root = await createTempTree({'lib/a.dart': ''});
    final resolved = await resolveInput(
      CollectorInput(
        outputFile: 'a.json',
        source: LocalInputSource(p.join(root, 'lib', 'a.dart')),
        runPubGet: false,
      ),
      _config(root),
    );
    expect(resolved.rootPath, p.join(root, 'lib'));
    expect(resolved.files!.single.path, p.join(root, 'lib', 'a.dart'));
    expect(resolved.outputFormat, OutputFormat.json);
  });

  test('fails for a missing path', () async {
    final root = await createTempTree({});
    expect(
      resolveInput(
        const CollectorInput(
          outputFile: 'a.yaml',
          source: LocalInputSource('missing'),
          runPubGet: false,
        ),
        _config(root),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('resolves the running Dart SDK', () async {
    final root = await createTempTree({});
    final resolved = await resolveInput(
      const CollectorInput(
        outputFile: 'sdk.yaml',
        source: DartSdkInputSource(),
        runPubGet: false,
      ),
      _config(root),
    );
    expect(p.basename(resolved.rootPath), 'lib');
    expect(resolved.files, isNull);
  });
}
