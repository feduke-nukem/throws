part of '../throws_rules.dart';

class IntroducedThrowsInOverrideRule extends AnalysisRule {
  static const LintCode _code = LintCode(
    'introduced_throws_in_override',
    'This override introduces new error types not declared in the base member.',
    correctionMessage:
        'Update the base member @Throws expectedErrors or annotate this member.',
  );

  IntroducedThrowsInOverrideRule()
    : super(
        name: 'introduced_throws_in_override',
        description:
            'Flags overrides that introduce new error types without updating the base annotation.',
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
        _ThrowsRuleKind.introducedThrowsInOverride,
      ),
    );
  }
}
