import 'package:test/test.dart';
import 'package:throws_collector/src/collector.dart';
import 'package:throws_collector/src/options.dart';

void main() {
  test('collects thrown errors from fixture project', () async {
    final root = 'test/fixtures/simple_project';
    final options = CollectorOptions(
      root: root,
      outPath: 'build/out.dart',
      mapName: '_throwsMap',
      sdkRoot: null,
      outputFormat: OutputFormat.dart,
      showHelp: false,
    );

    final entries = await collectThrows(options);

    final methodKey = entries.keys.firstWhere(
      (key) => key.endsWith('.Foo.bar'),
    );
    final functionKey = entries.keys.firstWhere((key) => key.endsWith('.baz'));

    expect(entries[methodKey], contains('StateError'));
    expect(entries[functionKey], contains('Exception'));
  });
}
