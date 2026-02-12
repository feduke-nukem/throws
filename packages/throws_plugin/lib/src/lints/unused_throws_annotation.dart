import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/utils/extensions/ast_node_x.dart';
import 'package:throws_plugin/src/utils/throws_analyzer.dart';

class UnusedThrowsAnnotation extends AnalysisRule {
  static const LintCode _code = LintCode(
    'unused_throws_annotation',
    'Unused @${ThrowsAnnotation.nameCapitalized} annotation.',
    correctionMessage:
        'Remove unused @${ThrowsAnnotation.nameCapitalized} annotation.',
    severity: DiagnosticSeverity.ERROR,
  );

  UnusedThrowsAnnotation()
    : super(
        name: 'unused_throws_annotation',
        description:
            'Warns when @${ThrowsAnnotation.nameCapitalized} is unused.',
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

class UnusedThrowsAnnotationFix extends ResolvedCorrectionProducer {
  static const FixKind _fixKind = FixKind(
    'throws.fix.unusedThrowsAnnotation',
    DartFixKindPriority.standard,
    'Remove @${ThrowsAnnotation.nameCapitalized} annotation',
  );

  UnusedThrowsAnnotationFix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    try {
      final annotation = node.findThrowsAnnotation();
      if (annotation == null) {
        return;
      }

      await builder.addDartFileEdit(file, (builder) {
        builder.addDeletion(range.node(annotation));
      });
    } catch (_) {
      return;
    }
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
