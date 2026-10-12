import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/utils/analysis_cache.dart';

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
    final analysis = AnalysisCache.analysis(node);

    for (final summary in analysis.summaries) {
      final inherited = summary.inherited;
      if (inherited == null || inherited.allowsAny) {
        continue;
      }

      for (final site in summary.sites) {
        if (!inherited.uncovered(site.errors, analysis.typeSystem).isEmpty) {
          rule.reportAtNode(site.node);
        }
      }
    }
  }
}
