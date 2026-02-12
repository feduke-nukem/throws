import 'package:test/test.dart';
import 'package:throws_collector/src/collector.dart';

void main() {
  test('collects thrown errors from fixture project', () async {
    final root = 'test/fixtures/simple_project';
    final entries = await collectThrows(rootPath: root);

    final methodKey = entries.keys.firstWhere(
      (key) => key.endsWith('.Foo.bar'),
    );
    final functionKey = entries.keys.firstWhere((key) => key.endsWith('.baz'));

    expect(entries[methodKey], contains('StateError'));
    expect(entries[functionKey], contains('Exception'));
  });
}
