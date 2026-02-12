import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/extensions/compilation_unit_x.dart';
import 'package:throws_plugin/src/utils/extensions/type_annotation_x.dart';
import 'package:throws_plugin/src/utils/throw_finder.dart';
import 'package:throws_plugin/src/utils/throws_analyzer.dart';
import 'package:throws_plugin/src/utils/throws_expected_errors_collector.dart';

class NotExhaustiveTryCatch extends AnalysisRule {
  static const LintCode _code = LintCode(
    'not_exhaustive_try_catch',
    'Try/catch does not handle all expected errors from this call.',
    correctionMessage:
        'Add missing catch clauses or update @${ThrowsAnnotation.nameCapitalized}.',
    severity: DiagnosticSeverity.ERROR,
  );

  NotExhaustiveTryCatch()
    : super(
        name: 'not_exhaustive_try_catch',
        description:
            'Requires try/catch to cover all expected errors for throwing calls.',
      );

  static const LintCode code = _code;

  @override
  LintCode get diagnosticCode => _code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addCompilationUnit(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    final summaries = ThrowsAnalyzer().analyze(node);

    for (final summary in summaries) {
      if (summary.unhandledThrowingCallNodes.isEmpty) {
        continue;
      }

      final reportNodes = summary.unhandledThrowingCallNodes.where(
        (node) => shouldReportUnhandledCall(
          node,
          requireTryCatch: true,
        ),
      );

      for (final node in reportNodes) {
        rule.reportAtNode(node);
      }
    }
  }
}

class NotExhaustiveTryCatchFix extends ResolvedCorrectionProducer {
  static const _assistKind = FixKind(
    'throws.fix.notExhaustiveTryCatch',
    DartFixKindPriority.standard,
    'Add missing catch clauses',
  );

  NotExhaustiveTryCatchFix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _assistKind;

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

      final annotatedErrors = annotatedErrorsForEnclosingFunction(tryStatement);
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

      final handledErrors = _handledErrors(tryStatement);
      if (handledErrors == null) {
        return;
      }

      final missingErrors = filteredExpectedErrors
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
    final visitor = RethrowFinder();
    clause.body.accept(visitor);
    return visitor.foundRethrow;
  }
}

class NotExhaustiveTryCatchDefaultFix extends ResolvedCorrectionProducer {
  static const _fixKind = FixKind(
    'throws.fix.notExhaustiveTryCatchDefault',
    DartFixKindPriority.standard,
    'Add default catch clause',
  );

  NotExhaustiveTryCatchDefaultFix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

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

      final handled = _handledErrors(tryStatement);
      if (handled == null) {
        return;
      }
      if (handled.contains('Object') || handled.contains('dynamic')) {
        return;
      }

      final lastCatch = tryStatement.catchClauses.last;
      final insertOffset = lastCatch.end;
      final indent = utils.getLinePrefix(lastCatch.offset);
      await builder.addDartFileEdit(file, (builder) {
        builder.addInsertion(insertOffset, (builder) {
          builder.write(' on Object catch (e, stackTrace) {');
          builder.writeln();
          builder.writeln('$indent  // TODO: handle error');
          builder.write('$indent}');
        });
      });
    } catch (_) {
      return;
    }
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
    final visitor = RethrowFinder();
    clause.body.accept(visitor);
    return visitor.foundRethrow;
  }
}
