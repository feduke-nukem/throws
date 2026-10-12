import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/utils/analysis_cache.dart';
import 'package:throws_plugin/src/utils/extensions/ast_node_x.dart';
import 'package:throws_plugin/src/utils/extensions/dart_file_edit_builder_x.dart';

class MissingThrowsAnnotationFix extends ResolvedCorrectionProducer {
  static const FixKind _fixKind = FixKind(
    'throws.fix.missingThrowsAnnotation',
    DartFixKindPriority.standard,
    'Add @${ThrowsAnnotation.nameCapitalized} annotation',
  );

  MissingThrowsAnnotationFix({required super.context});

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
      if (functionNode == null ||
          summary == null ||
          summary.annotation != null ||
          summary.sites.isEmpty) {
        return;
      }

      final types = summary.escaping.sortedTypes;
      final metadata = functionNode.metadata;
      final offset = functionNode.insertOffset(metadata);
      final indent = utils.getLinePrefix(offset);
      await builder.addDartFileEdit(file, (builder) {
        final throwsRef = builder.importThrows(
          isCapitalized: types.isNotEmpty,
        );
        builder.addInsertion(offset, (builder) {
          builder.write(indent);
          if (types.isNotEmpty) {
            builder.write('@$throwsRef(reason: \'reason\', errors: {');
            writeTypeList(builder, types);
            builder.write('})');
          } else {
            builder.write('@$throwsRef');
          }
          builder.writeln();
        });
      });
    } catch (_) {
      return;
    }
  }
}
