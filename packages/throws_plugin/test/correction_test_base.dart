import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/package_config_file_builder.dart';
import 'package:analyzer_testing/src/single_unit.dart'; // ignore: implementation_imports
import 'package:test/test.dart';

import 'stubs.dart';

typedef ProducerGenerator =
    ResolvedCorrectionProducer Function({
      required CorrectionProducerContext context,
    });

/// Runs a quick fix or assist at the `^` marker of the test code.
abstract class CorrectionTest extends SingleUnitTest {
  ProducerGenerator get generator;

  /// The change made by the last correction.
  late SourceChange lastChange;

  @override
  void setUp() {
    super.setUp();
    newFile('/packages/throws/lib/throws.dart', throwsLibrary);
    writeTestPackageConfig2(
      config: PackageConfigFileBuilder()
        ..add(name: 'throws', rootFolder: getFolder('/packages/throws')),
    );
  }

  /// Code after applying the correction at every `^` marker, or null when
  /// it makes no edits. Several markers emulate "fix all in file".
  Future<String?> apply(String code) async {
    addTestSource(code);
    final unit = await getResolvedUnit(testFile);
    final positions = parsedTestCode.positions;
    final builder = ChangeBuilder(session: unit.session);
    for (final position in positions) {
      final producer = generator(
        context: CorrectionProducerContext.createResolved(
          libraryResult: testLibraryResult!,
          unitResult: unit,
          applyingBulkFixes: positions.length > 1,
          selectionOffset: position.offset,
        ),
      );
      if (positions.length > 1) {
        expect(producer.canBeAppliedAcrossSingleFile, isTrue);
        expect(producer.multiFixKind, isNotNull);
      }
      await producer.compute(builder);
    }
    lastChange = builder.sourceChange;
    final edits = lastChange.getFileEdit(testFile.path)?.edits;
    return edits == null ? null : SourceEdit.applySequence(testCode, edits);
  }

  Future<void> assertHasCorrection(String code, String expected) async {
    expect(await apply(code), normalizeSource(expected));
  }

  /// Text at each linked edit position of [lastChange] in [result].
  List<String> linkedTexts(String result) => [
    for (final group in lastChange.linkedEditGroups)
      for (final position in group.positions)
        result.substring(position.offset, position.offset + group.length),
  ];

  /// [path] content after applying [lastChange] to [original].
  String changedFile(String path, String original) =>
      SourceEdit.applySequence(original, lastChange.getFileEdit(path)!.edits);

  Future<void> assertNoCorrection(String code) async {
    expect(await apply(code), isNull);
  }
}
