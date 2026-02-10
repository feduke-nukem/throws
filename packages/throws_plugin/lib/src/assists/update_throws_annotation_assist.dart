import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/extensions/annotation_x.dart';
import 'package:throws_plugin/src/utils/extensions/ast_node_x.dart';
import 'package:throws_plugin/src/utils/extensions/compilation_unit_x.dart';

class UpdateThrowsAnnotationAssist extends ResolvedCorrectionProducer {
  static const AssistKind _assistKind = AssistKind(
    'throws.assist.updateThrowsAnnotation',
    30,
    'Update @${ThrowsAnnotation.nameCapitalized} annotation',
  );

  UpdateThrowsAnnotationAssist({required super.context});

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
      if (!hasThrowsAnnotationOnNode(metadata)) {
        return;
      }

      final targetAnnotation = metadata.firstWhere(
        (entry) {
          final name = entry.maybeVerifiedName;
          return name == ThrowsAnnotation.nameCapitalized ||
              name == ThrowsAnnotation.name;
        },
      );

      final body = functionNode.functionBody;
      if (body == null) {
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
      final reason = _reasonFromAnnotation(targetAnnotation);
      final reasonStr = reason != null
          ? 'reason: ${_stringLiteral(reason)}, '
          : '';

      await builder.addDartFileEdit(file, (builder) {
        builder.addReplacement(range.node(targetAnnotation), (builder) {
          if (expectedErrors.isNotEmpty) {
            builder.write(
              '@${ThrowsAnnotation.nameCapitalized}(${reasonStr}errors: {',
            );
            builder.write(expectedErrors.join(', '));
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
  final arguments = annotation.arguments?.arguments;
  if (arguments == null || arguments.isEmpty) {
    return null;
  }

  for (final argument in arguments) {
    if (argument is NamedExpression && argument.name.label.name == 'reason') {
      final expression = argument.expression;
      if (expression is StringLiteral) {
        return expression.stringValue;
      }
    }
  }

  final firstArg = arguments.first;
  if (firstArg is StringLiteral) {
    return firstArg.stringValue;
  }

  return null;
}

String _stringLiteral(String value) {
  final escaped = value.replaceAll('\\', r'\\').replaceAll("'", r"\'");
  return "'$escaped'";
}
