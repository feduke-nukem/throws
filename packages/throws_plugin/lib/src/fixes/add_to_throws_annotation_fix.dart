import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/analysis_cache.dart';
import 'package:throws_plugin/src/utils/extensions/ast_node_x.dart';
import 'package:throws_plugin/src/utils/extensions/dart_file_edit_builder_x.dart';

/// Adds the errors of a throwing call to the `errors` of the enclosing
/// function's `@Throws`, keeping the declared ones.
class AddToThrowsAnnotationFix extends ResolvedCorrectionProducer {
  static const FixKind _fixKind = FixKind(
    'throws.fix.addToThrowsAnnotation',
    DartFixKindPriority.standard,
    'Add errors to @${ThrowsAnnotation.nameCapitalized}',
  );

  AddToThrowsAnnotationFix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final functionNode = node.enclosingFunction;
    final analysis = AnalysisCache.analysis(unit);
    final summary = analysis.summaryFor(functionNode);
    final annotation = functionNode == null
        ? null
        : findThrowsAnnotation(functionNode.metadata);
    if (summary == null ||
        annotation == null ||
        summary.annotation == null ||
        summary.annotation!.allowsAny) {
      return;
    }

    final errors = <DartType>{};
    for (final site in summary.sites) {
      if (site.node == node) {
        errors.addAll(summary.uncovered(site, analysis.typeSystem).types);
      }
    }
    final literal = errorsLiteral(annotation);
    if (errors.isEmpty || literal == null) {
      return;
    }

    final types = errors.toList()
      ..sort((a, b) => a.getDisplayString().compareTo(b.getDisplayString()));
    await builder.addDartFileEdit(file, (builder) {
      addToErrorsLiteral(builder, literal, types);
    });
  }
}
