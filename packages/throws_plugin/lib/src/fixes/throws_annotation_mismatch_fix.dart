import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
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
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    try {
      final functionNode = node.enclosingFunction;
      final summary = AnalysisCache.analysis(unit).summaryFor(functionNode);
      final targetAnnotation = functionNode == null
          ? null
          : findThrowsAnnotation(functionNode.metadata);
      if (summary == null || targetAnnotation == null) {
        return;
      }

      final types = summary.escaping.sortedTypes;
      final reason = _reasonFromAnnotation(targetAnnotation);
      final reasonStr = reason != null
          ? 'reason: ${_stringLiteral(reason)}, '
          : '';

      await builder.addDartFileEdit(file, (builder) {
        builder.addReplacement(range.node(targetAnnotation), (builder) {
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
      });
    } catch (_) {
      return;
    }
  }
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
