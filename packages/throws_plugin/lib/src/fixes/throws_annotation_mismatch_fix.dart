import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/analysis_cache.dart';
import 'package:throws_plugin/src/utils/extensions/ast_node_x.dart';
import 'package:throws_plugin/src/utils/extensions/dart_file_edit_builder_x.dart';

class ThrowsAnnotationMismatchFix extends ResolvedCorrectionProducer {
  static const FixKind _fixKind = FixKind(
    'throws.fix.throwsAnnotationMismatch',
    DartFixKindPriority.standard,
    'Update @${ThrowsAnnotation.nameCapitalized} annotation',
  );

  ThrowsAnnotationMismatchFix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.acrossSingleFile;

  @override
  FixKind? get multiFixKind => _multiFixKind;

  static const FixKind _multiFixKind = FixKind(
    'throws.fix.throwsAnnotationMismatch.multi',
    DartFixKindPriority.inFile,
    'Update @Throws annotations everywhere in file',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final functionNode = node.enclosingFunction;
    final summary = AnalysisCache.analysis(unit).summaryFor(functionNode);
    final targetAnnotation = functionNode == null
        ? null
        : findThrowsAnnotation(functionNode.metadata);
    if (summary == null || targetAnnotation == null) {
      return;
    }

    await builder.addDartFileEdit(file, (builder) {
      replaceThrowsAnnotation(
        builder,
        targetAnnotation,
        summary.escaping.sortedTypes,
      );
    });
  }
}

/// Replaces [annotation] with `@Throws(errors: {types})`, keeping its reason,
/// or with `@throws` when [types] is empty.
void replaceThrowsAnnotation(
  DartFileEditBuilder builder,
  Annotation annotation,
  List<DartType> types,
) {
  final reason = _reasonFromAnnotation(annotation);
  final reasonStr = reason != null ? 'reason: ${_stringLiteral(reason)}, ' : '';
  builder.addReplacement(range.node(annotation), (builder) {
    if (types.isNotEmpty) {
      builder.write(
        '@${ThrowsAnnotation.nameCapitalized}(${reasonStr}errors: {',
      );
      writeTypeList(builder, types);
      builder.write('})');
    } else {
      builder.write('@${ThrowsAnnotation.name}');
    }
  });
}

String? _reasonFromAnnotation(Annotation annotation) {
  return annotation.elementAnnotation
      ?.computeConstantValue()
      ?.getField('reason')
      ?.toStringValue();
}

String _stringLiteral(String value) {
  final escaped = value.replaceAll('\\', r'\\').replaceAll("'", r"\'");
  return "'$escaped'";
}
