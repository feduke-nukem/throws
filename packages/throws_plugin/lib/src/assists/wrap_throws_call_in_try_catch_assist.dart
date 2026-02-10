import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/extensions/ast_node_x.dart';
import 'package:throws_plugin/src/utils/extensions/expression_x.dart';
import 'package:throws_plugin/src/utils/extensions/statement_x.dart';

class WrapThrowsCallInTryCatchAssist extends ResolvedCorrectionProducer {
  static const AssistKind _assistKind = AssistKind(
    'throws.assist.wrapTryCatch',
    30,
    'Wrap in try/catch',
  );

  WrapThrowsCallInTryCatchAssist({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _assistKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    try {
      final statement = node.enclosingStatement;
      if (statement == null || statement.isSynthetic) {
        return;
      }
      if (statement.isWithinTryStatement) {
        return;
      }

      final expression = statement.expression;
      if (expression == null) {
        return;
      }

      final expectedErrors = expression.expectedErrors(unit);
      if (expectedErrors == null) {
        return;
      }

      final annotatedErrors = annotatedErrorsForEnclosingFunction(statement);
      if (annotatedErrors != null && annotatedErrors.isEmpty) {
        return;
      }

      final filteredExpectedErrors = annotatedErrors == null
          ? expectedErrors
          : expectedErrors
                .where((error) => !annotatedErrors.contains(error))
                .toList();
      if (filteredExpectedErrors.isEmpty) {
        return;
      }

      final statementSource = statement.toSource().trim();
      if (statementSource.isEmpty) {
        return;
      }

      final replacementRange = utils.getLinesRange(range.node(statement));
      final indent = utils.getLinePrefix(replacementRange.offset);
      final errors = filteredExpectedErrors.isEmpty
          ? const ['Object']
          : filteredExpectedErrors;
      await builder.addDartFileEdit(file, (builder) {
        builder.addReplacement(replacementRange, (builder) {
          builder.writeln('${indent}try {');
          builder.writeln('$indent  $statementSource');
          builder.write('$indent}');
          for (final error in errors) {
            builder.writeln(' on $error catch (e, stackTrace) {');
            builder.writeln('$indent  // TODO: handle error');
            builder.write('$indent}');
          }
          builder.writeln();
        });
      });
    } catch (_) {
      return;
    }
  }
}
