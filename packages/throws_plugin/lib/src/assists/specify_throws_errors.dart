import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/fixes/throws_annotation_mismatch_fix.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/analysis_cache.dart';
import 'package:throws_plugin/src/utils/extensions/ast_node_x.dart';

/// Turns `@throws` / `@Throws()` into `@Throws(errors: {...})` with the
/// errors the function throws.
class SpecifyThrowsErrorsAssist extends ResolvedCorrectionProducer {
  static const AssistKind _assistKind = AssistKind(
    'throws.assist.specifyThrowsErrors',
    DartFixKindPriority.standard,
    'Specify errors in @${ThrowsAnnotation.nameCapitalized}',
  );

  SpecifyThrowsErrorsAssist({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _assistKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final functionNode = node.enclosingFunction;
    final summary = AnalysisCache.analysis(unit).summaryFor(functionNode);
    final annotation = functionNode == null
        ? null
        : findThrowsAnnotation(functionNode.metadata);
    final types = summary?.escaping.sortedTypes ?? const [];
    if (annotation == null ||
        summary?.annotation?.allowsAny != true ||
        types.isEmpty) {
      return;
    }

    await builder.addDartFileEdit(file, (builder) {
      replaceThrowsAnnotation(builder, annotation, types);
    });
  }
}
