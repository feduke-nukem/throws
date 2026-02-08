import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/utils/extensions/ast_node_x.dart';

class RemoveThrowsAnnotationAssist extends ResolvedCorrectionProducer {
  static const AssistKind _assistKind = AssistKind(
    'throws.assist.removeThrowsAnnotation',
    30,
    'Remove @${ThrowsAnnotation.nameCapitalized} annotation',
  );

  RemoveThrowsAnnotationAssist({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _assistKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    try {
      final annotation = node.findThrowsAnnotation();
      if (annotation == null) {
        return;
      }

      await builder.addDartFileEdit(file, (builder) {
        builder.addDeletion(range.node(annotation));
      });
    } catch (_) {
      return;
    }
  }
}
