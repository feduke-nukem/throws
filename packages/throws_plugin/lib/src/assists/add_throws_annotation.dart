import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/extensions/ast_node_x.dart';
import 'package:throws_plugin/src/utils/extensions/dart_file_edit_builder_x.dart';

class AddThrowsAnnotationAssist extends ResolvedCorrectionProducer {
  static const AssistKind _assistKind = AssistKind(
    'throws.assist.addThrowsAnnotation',
    DartFixKindPriority.standard,
    'Add @${ThrowsAnnotation.nameCapitalized}()',
  );

  AddThrowsAnnotationAssist({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _assistKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final functionNode = node.enclosingFunction;

    if (functionNode == null) {
      return;
    }

    final metadata = functionNode.metadata;
    if (hasThrowsAnnotationOnNode(metadata)) {
      return;
    }

    final offset = functionNode.insertOffset(metadata);
    await builder.addDartFileEdit(file, (builder) {
      final throwsRef = builder.importThrows();
      builder.addInsertion(offset, (builder) {
        builder.write(
          '@$throwsRef(reason: \'reason\', errors: {})',
        );

        builder.writeln();
      });
    });
  }
}
