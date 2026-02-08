part of '../throws_rules.dart';

class MissingThrowsAnnotationRule extends AnalysisRule {
  static const LintCode _code = LintCode(
    'missing_throws_annotation',
    'Functions that throw must be annotated with @Throws.',
    correctionMessage:
        'Add @Throws(reason, expectedErrors) or @throws to this function.',
  );

  MissingThrowsAnnotationRule()
    : super(
        name: 'missing_throws_annotation',
        description: 'Requires @Throws on functions that throw.',
      );

  @override
  LintCode get diagnosticCode => _code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addCompilationUnit(
      this,
      _ThrowsCompilationUnitVisitor(
        this,
        _ThrowsRuleKind.missingThrowsAnnotation,
      ),
    );
  }
}
