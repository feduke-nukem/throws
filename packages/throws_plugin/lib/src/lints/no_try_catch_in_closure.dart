import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/utils/analysis_cache.dart';

/// `no_try_catch` for closures that are not passed to a `@rethrows`
/// parameter: nothing can catch their errors outside, and they cannot be
/// annotated.
class NoTryCatchInClosure extends AnalysisRule {
  static const LintCode _code = LintCode(
    'no_try_catch_in_closure',
    'Calling a throwing function in a closure must be handled.',
    correctionMessage:
        'Wrap the call in try/catch, or pass the closure to a function '
        'annotated with @${ThrowsAnnotation.rethrows}.',
    severity: DiagnosticSeverity.ERROR,
  );

  NoTryCatchInClosure()
    : super(
        name: 'no_try_catch_in_closure',
        description:
            'Requires try/catch when calling throwing functions in closures '
            'whose errors are not rethrown.',
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
      if (!summary.isClosure || summary.rethrown) {
        continue;
      }
      for (final site in summary.sites) {
        if (site.isCall && !site.inTryWithCatch) {
          rule.reportAtNode(site.node);
        }
      }
    }
  }
}
