part of '../throws_rules.dart';

class ThrowsAnnotationMismatchRule extends AnalysisRule {
  static const LintCode _code = LintCode(
    'throws_annotation_mismatch',
    'Throws annotation errors do not match actual thrown errors.',
    correctionMessage: 'Update @Throws expectedErrors to match thrown errors.',
  );

  ThrowsAnnotationMismatchRule()
    : super(
        name: 'throws_annotation_mismatch',
        description:
            'Flags @Throws annotations that do not match actual thrown errors.',
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
        _ThrowsRuleKind.throwsAnnotationMismatch,
      ),
    );
  }
}
