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

  @override
  void setUp() {
    super.setUp();
    newFile('/packages/throws/lib/throws.dart', throwsLibrary);
    writeTestPackageConfig2(
      config: PackageConfigFileBuilder()
        ..add(name: 'throws', rootFolder: getFolder('/packages/throws')),
    );
  }

  /// Code after applying the correction, or null when it makes no edits.
  Future<String?> _apply(String code) async {
    addTestSource(code);
    final unit = await getResolvedUnit(testFile);
    final producer = generator(
      context: CorrectionProducerContext.createResolved(
        libraryResult: testLibraryResult!,
        unitResult: unit,
        selectionOffset: parsedTestCode.position.offset,
      ),
    );
    final builder = ChangeBuilder(session: unit.session);
    await producer.compute(builder);
    final edits = builder.sourceChange.getFileEdit(testFile.path)?.edits;
    return edits == null ? null : SourceEdit.applySequence(testCode, edits);
  }

  Future<void> assertHasCorrection(String code, String expected) async {
    expect(await _apply(code), normalizeSource(expected));
  }

  Future<void> assertNoCorrection(String code) async {
    expect(await _apply(code), isNull);
  }
}
