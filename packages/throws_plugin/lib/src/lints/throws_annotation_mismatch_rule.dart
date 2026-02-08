import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/throws_analyzer.dart';

class ThrowsAnnotationMismatchRule extends AnalysisRule {
  static const LintCode _code = LintCode(
    'throws_annotation_mismatch',
    'The @${ThrowsAnnotation.nameCapitalized} annotation does not match the thrown errors.',
    correctionMessage:
        'Update @${ThrowsAnnotation.nameCapitalized} to match the errors thrown in this function.',
  );

  ThrowsAnnotationMismatchRule()
    : super(
        name: 'throws_annotation_mismatch',
        description:
            'Ensures @${ThrowsAnnotation.nameCapitalized} matches the errors thrown.',
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
      if (summary.hasThrowsAnnotation &&
          !summary.allowAnyExpectedErrors &&
          summary.thrownErrors.isNotEmpty &&
          !matchesAnnotation(summary)) {
        rule.reportAtToken(summary.nameToken);
      }
    }
  }
}
