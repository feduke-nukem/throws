part of '../throws_assists.dart';

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
      final statement = _findEnclosingStatement(node);
      if (statement == null || statement.isSynthetic) {
        return;
      }
      if (_isWithinTryStatement(statement)) {
        return;
      }

      final expression = _statementExpression(statement);
      if (expression == null) {
        return;
      }

      final expectedErrors = _expressionExpectedErrors(expression, unit);
      if (expectedErrors == null) {
        return;
      }

      final statementSource = statement.toSource().trim();
      if (statementSource.isEmpty) {
        return;
      }

      final replacementRange = utils.getLinesRange(range.node(statement));
      final indent = utils.getLinePrefix(replacementRange.offset);
      final errors = expectedErrors.isEmpty ? const ['Object'] : expectedErrors;
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
