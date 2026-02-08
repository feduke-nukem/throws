part of '../throws_rules.dart';

class UnusedThrowsAnnotationRule extends AnalysisRule {
  static const LintCode _code = LintCode(
    'unused_throws_annotation',
    'This function is annotated with @Throws but does not throw.',
    correctionMessage: 'Remove the @Throws annotation.',
  );

  UnusedThrowsAnnotationRule()
    : super(
        name: 'unused_throws_annotation',
        description: 'Flags @Throws on functions that do not throw.',
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
        _ThrowsRuleKind.unusedThrowsAnnotation,
      ),
    );
  }
}
