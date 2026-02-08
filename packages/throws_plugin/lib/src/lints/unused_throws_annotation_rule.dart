import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/utils/throws_analyzer.dart';

class UnusedThrowsAnnotationRule extends AnalysisRule {
  static const LintCode _code = LintCode(
    'unused_throws_annotation',
    'Remove @${ThrowsAnnotation.nameCapitalized} when no errors are thrown.',
    correctionMessage:
        'Remove unused @${ThrowsAnnotation.nameCapitalized} annotation.',
  );

  UnusedThrowsAnnotationRule()
    : super(
        name: 'unused_throws_annotation',
        description:
            'Warns when @${ThrowsAnnotation.nameCapitalized} is unused.',
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
          !summary.hasUnhandledThrow &&
          !summary.hasUnhandledThrowingCall &&
          !summary.isAbstractOrExternal) {
        rule.reportAtToken(summary.nameToken);
      }
    }
  }
}
