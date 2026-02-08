import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/utils/extensions/function_summary_x.dart';
import 'package:throws_plugin/src/utils/throws_analyzer.dart';

class MissingThrowsAnnotationRule extends AnalysisRule {
  static const LintCode _code = LintCode(
    'missing_throws_annotation',
    'Functions that throw must be annotated with @${ThrowsAnnotation.nameCapitalized}.',
    correctionMessage:
        'Add @${ThrowsAnnotation.nameCapitalized}(reason, expectedErrors) or @throws to this function.',
  );

  MissingThrowsAnnotationRule()
    : super(
        name: 'missing_throws_annotation',
        description:
            'Requires @${ThrowsAnnotation.nameCapitalized} on functions that throw.',
      );

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
      final shouldReport =
          (!summary.hasThrowsAnnotation && summary.hasUnhandledThrow) &&
          (!summary.hasAnnotatedSuper && !summary.isCoveredByInheritedThrows);

      if (!shouldReport) {
        continue;
      }

      rule.reportAtToken(summary.nameToken);
    }
  }
}
