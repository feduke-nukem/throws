import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:throws_plugin/src/utils/extensions/compilation_unit_x.dart';
import 'package:throws_plugin/src/utils/extensions/type_annotation_x.dart';
import 'package:throws_plugin/src/utils/throw_finder.dart';
import 'package:throws_plugin/src/utils/throws_expected_errors_collector.dart';

class AddMissingCatchClausesAssist extends ResolvedCorrectionProducer {
  static const AssistKind _assistKind = AssistKind(
    'throws.assist.addMissingCatchClauses',
    30,
    'Add missing catch clauses',
  );

  AddMissingCatchClausesAssist({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _assistKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    try {
      final tryStatement = node.thisOrAncestorOfType<TryStatement>();
      if (tryStatement == null) {
        return;
      }
      if (tryStatement.catchClauses.isEmpty) {
        return;
      }

      final unit = tryStatement.thisOrAncestorOfType<CompilationUnit>();
      if (unit == null) {
        return;
      }

      final expectedErrors = _expectedErrorsForTryBody(tryStatement, unit);
      if (expectedErrors.isEmpty) {
        return;
      }

      final handledErrors = _handledErrors(tryStatement);
      if (handledErrors == null) {
        return;
      }

      final missingErrors = expectedErrors
          .where((error) => !handledErrors.contains(error))
          .toList();
      if (missingErrors.isEmpty) {
        return;
      }

      final lastCatch = tryStatement.catchClauses.last;
      final insertOffset = lastCatch.end;
      final indent = utils.getLinePrefix(lastCatch.offset);
      await builder.addDartFileEdit(file, (builder) {
        builder.addInsertion(insertOffset, (builder) {
          for (final error in missingErrors) {
            builder.write(' on $error catch (e, stackTrace) {');
            builder.writeln();
            builder.writeln('$indent  // TODO: handle error');
            builder.write('$indent}');
          }
        });
      });
    } catch (_) {
      return;
    }
  }

  List<String> _expectedErrorsForTryBody(
    TryStatement statement,
    CompilationUnit unit,
  ) {
    final localInfo = unit.collectLocalThrowingInfo();
    final collector = ThrowsExpectedErrorsCollector(
      localExpectedErrorsByElement: localInfo.expectedErrorsByElement,
    );
    statement.body.accept(collector);
    return collector.expectedErrors;
  }

  Set<String>? _handledErrors(TryStatement statement) {
    final handled = <String>{};

    for (final clause in statement.catchClauses) {
      if (_catchAlwaysRethrows(clause)) {
        continue;
      }

      final typeName = clause.exceptionType?.typeName;
      if (typeName == null) {
        return null;
      }
      if (typeName == 'Object' || typeName == 'dynamic') {
        return null;
      }

      handled.add(typeName);
    }

    return handled;
  }

  bool _catchAlwaysRethrows(CatchClause clause) {
    final visitor = ThrowFinder();
    clause.body.accept(visitor);
    return visitor.foundThrow;
  }
}
