import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/utils/extensions/function_summary_x.dart';
import 'package:throws_plugin/src/utils/throws_analyzer.dart';

class IntroducedThrowsInOverride extends AnalysisRule {
  static const LintCode _code = LintCode(
    'introduced_throws_in_override',
    'Overrides should not introduce new thrown errors as it violates Liskov Substitution Principle',
    correctionMessage:
        'Match the @${ThrowsAnnotation.nameCapitalized} annotation of the overridden member or handle errors.',
    severity: DiagnosticSeverity.ERROR,
  );

  IntroducedThrowsInOverride()
    : super(
        name: 'introduced_throws_in_override',
        description:
            'Disallows new errors in overrides without @${ThrowsAnnotation.nameCapitalized}.',
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
      final shouldReportIntroducedThrows =
          !summary.hasThrowsAnnotation &&
          (summary.hasUnhandledThrow || summary.hasUnhandledThrowingCall) &&
          summary.introducesNewErrors;

      if (!shouldReportIntroducedThrows) {
        continue;
      }

      rule.reportAtToken(summary.nameToken);
    }
  }
}
