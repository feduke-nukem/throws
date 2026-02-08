part of '../throws_rules.dart';

class MissingErrorHandlingRule extends AnalysisRule {
  static const LintCode _code = LintCode(
    'missing_error_handling',
    'Calling a throwing function must be handled or annotated.',
    correctionMessage:
        'Wrap the call in try/catch or annotate the function with @Throws.',
  );

  MissingErrorHandlingRule()
    : super(
        name: 'missing_error_handling',
        description:
            'Requires @Throws or try/catch when calling throwing functions.',
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
      _ThrowsCompilationUnitVisitor(this, _ThrowsRuleKind.missingErrorHandling),
    );
  }
}
