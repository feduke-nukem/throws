import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/utils/extensions/function_summary_x.dart';
import 'package:throws_plugin/src/utils/throws_analyzer.dart';

class MissingErrorHandlingRule extends AnalysisRule {
  static const LintCode _code = LintCode(
    'missing_error_handling',
    'Calling a throwing function must be handled or annotated.',
    correctionMessage:
        'Wrap the call in try/catch or annotate the function with @${ThrowsAnnotation.nameCapitalized}.',
  );

  MissingErrorHandlingRule()
    : super(
        name: 'missing_error_handling',
        description:
            'Requires @${ThrowsAnnotation.nameCapitalized} or try/catch when calling throwing functions.',
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
      if (summary.unhandledThrowingCallNodes.isEmpty) {
        continue;
      }

      if (!summary.hasThrowsAnnotation) {
        if (!summary.isCoveredByInheritedThrows) {
          for (final node in summary.unhandledThrowingCallNodes) {
            rule.reportAtNode(node);
          }
        }
        continue;
      }

      if (summary.allowAnyExpectedErrors) {
        continue;
      }

      final annotated = summary.annotatedExpectedErrors.toSet();
      final hasMissingErrors = summary.thrownErrors.any(
        (error) => !annotated.contains(error),
      );
      if (!hasMissingErrors) {
        continue;
      }

      for (final node in summary.unhandledThrowingCallNodes) {
        rule.reportAtNode(node);
      }
    }
  }
}
