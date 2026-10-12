import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/analysis_cache.dart';
import 'package:throws_plugin/src/utils/extensions/ast_node_x.dart';
import 'package:throws_plugin/src/utils/extensions/dart_file_edit_builder_x.dart';

/// Adds errors an override introduces to the `@Throws` of the member it
/// overrides, when that member is declared in the analyzed package.
class AddToOverriddenThrowsFix extends ResolvedCorrectionProducer {
  static const FixKind _fixKind = FixKind(
    'throws.fix.addToOverriddenThrows',
    DartFixKindPriority.standard,
    'Add errors to @${ThrowsAnnotation.nameCapitalized} of the overridden member',
  );

  AddToOverriddenThrowsFix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final analysis = AnalysisCache.analysis(unit);
    final summary = analysis.summaryFor(node.enclosingFunction);
    final inherited = summary?.inherited;
    final element = summary?.element;
    if (summary == null ||
        inherited == null ||
        inherited.allowsAny ||
        element == null) {
      return;
    }

    final errors = <DartType>{};
    for (final site in summary.sites) {
      if (site.node == node) {
        errors.addAll(
          inherited.uncovered(site.errors, analysis.typeSystem).types,
        );
      }
    }
    final target = _annotatedOverridden(element);
    if (errors.isEmpty || target == null) {
      return;
    }

    final targetPath = target.firstFragment.libraryFragment.source.fullName;
    if (!unitResult.session.analysisContext.contextRoot.isAnalyzed(
      targetPath,
    )) {
      return;
    }
    final declaration = await sessionHelper.getFragmentDeclaration(
      target.firstFragment,
    );
    final targetNode = declaration?.node;
    final annotation = targetNode is AnnotatedNode
        ? findThrowsAnnotation(targetNode.metadata)
        : null;
    final literal = annotation == null ? null : errorsLiteral(annotation);
    if (literal == null) {
      return;
    }

    final types = errors.toList()
      ..sort((a, b) => a.getDisplayString().compareTo(b.getDisplayString()));
    await builder.addDartFileEdit(targetPath, (builder) {
      addToErrorsLiteral(builder, literal, types);
    });
  }

  /// The nearest overridden member with `@Throws`; none of them allows any
  /// error, as `inherited` would otherwise allow any.
  static ExecutableElement? _annotatedOverridden(ExecutableElement element) =>
      overriddenMembers(
        element,
      ).where((member) => annotationContract(member) != null).firstOrNull;
}
