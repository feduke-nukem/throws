import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/extensions/ast_node_x.dart';
import 'package:throws_plugin/src/utils/extensions/compilation_unit_x.dart';

class AddThrowsAnnotationAssist extends ResolvedCorrectionProducer {
  static const AssistKind _assistKind = AssistKind(
    'throws.assist.addThrowsAnnotation',
    30,
    'Add @${ThrowsAnnotation.nameCapitalized} annotation',
  );

  AddThrowsAnnotationAssist({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _assistKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    try {
      final functionNode = node.enclosingFunction;
      if (functionNode == null) {
        return;
      }

      final metadata = functionNode.metadata;
      if (hasThrowsAnnotationOnNode(metadata)) {
        return;
      }

      final body = functionNode.functionBody;
      if (body == null || !needsThrowsAnnotation(body)) {
        return;
      }

      final unit = functionNode.thisOrAncestorOfType<CompilationUnit>();
      if (unit == null) {
        return;
      }
      final localInfo = unit.collectLocalThrowingInfo();
      final expectedErrors = collectExpectedErrors(
        body,
        localExpectedErrorsByElement: localInfo.expectedErrorsByElement,
      );

      final offset = functionNode.insertOffset(metadata);
      await builder.addDartFileEdit(file, (builder) {
        builder.addInsertion(offset, (builder) {
          if (expectedErrors.isNotEmpty) {
            builder.write(
              '@${ThrowsAnnotation.nameCapitalized}(reason: \'reason\', errors: {',
            );
            builder.write(expectedErrors.join(', '));
            builder.write('})');
          } else {
            builder.write('@${ThrowsAnnotation.name}');
          }
          builder.writeln();
        });
      });
    } catch (_) {
      return;
    }
  }
}
