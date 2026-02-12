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
import 'package:analyzer_plugin/utilities/range_factory.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/analysis_cache.dart';
import 'package:throws_plugin/src/utils/extensions/ast_node_x.dart';
import 'package:throws_plugin/src/utils/extensions/expression_x.dart';
import 'package:throws_plugin/src/utils/extensions/statement_x.dart';

class NoTryCatch extends AnalysisRule {
  static const LintCode _code = LintCode(
    'no_try_catch',
    'Calling a throwing function must be handled or annotated.',
    correctionMessage:
        'Wrap the call in try/catch or annotate the function with @${ThrowsAnnotation.nameCapitalized}.',
    severity: DiagnosticSeverity.ERROR,
  );

  NoTryCatch()
    : super(
        name: 'no_try_catch',
        description:
            'Requires @${ThrowsAnnotation.nameCapitalized} or try/catch when calling throwing functions.',
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
    final summaries = AnalysisCache.throwsSummaries(node);

    for (final summary in summaries) {
      if (summary.unhandledThrowingCallNodes.isEmpty) {
        continue;
      }

      final reportNodes = summary.unhandledThrowingCallNodes.where(
        (node) => shouldReportUnhandledCall(
          node,
          requireTryCatch: false,
        ),
      );

      for (final node in reportNodes) {
        rule.reportAtNode(node);
      }
    }
  }
}

class NoTryCatchFix extends ResolvedCorrectionProducer {
  static const FixKind _fixKind = FixKind(
    'throws.fix.noTryCatch',
    DartFixKindPriority.standard,
    'Wrap in try/catch',
  );

  NoTryCatchFix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

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

class NoTryCatchWithDefaultFix extends ResolvedCorrectionProducer {
  static const FixKind _fixKind = FixKind(
    'throws.fix.noTryCatchDefault',
    DartFixKindPriority.standard,
    'Wrap in try/catch with default clause',
  );

  NoTryCatchWithDefaultFix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

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

      final statementSource = statement.toSource().trim();
      if (statementSource.isEmpty) {
        return;
      }

      final replacementRange = utils.getLinesRange(range.node(statement));
      final indent = utils.getLinePrefix(replacementRange.offset);
      await builder.addDartFileEdit(file, (builder) {
        builder.addReplacement(replacementRange, (builder) {
          builder.writeln('${indent}try {');
          builder.writeln('$indent  $statementSource');
          builder.writeln('$indent} on Object catch (e, stackTrace) {');
          builder.writeln('$indent  // TODO: handle error');
          builder.writeln('$indent}');
        });
      });
    } catch (_) {
      return;
    }
  }
}
