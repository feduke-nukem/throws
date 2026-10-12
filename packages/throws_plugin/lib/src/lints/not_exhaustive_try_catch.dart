import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/fixes/catch_clauses.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/analysis_cache.dart';
import 'package:throws_plugin/src/utils/extensions/ast_node_x.dart';

class NotExhaustiveTryCatch extends AnalysisRule {
  static const LintCode _code = LintCode(
    'not_exhaustive_try_catch',
    'Try/catch does not handle all expected errors from this call.',
    correctionMessage:
        'Add missing catch clauses or update @${ThrowsAnnotation.nameCapitalized}.',
    severity: DiagnosticSeverity.ERROR,
  );

  NotExhaustiveTryCatch()
    : super(
        name: 'not_exhaustive_try_catch',
        description:
            'Requires try/catch to cover all expected errors for throwing calls.',
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
      for (final site in summary.sites) {
        if (site.isCall &&
            site.inTryWithCatch &&
            !summary.uncovered(site, analysis.typeSystem).isEmpty) {
          rule.reportAtNode(site.node);
        }
      }
    }
  }
}

class NotExhaustiveTryCatchFix extends ResolvedCorrectionProducer {
  static const _assistKind = FixKind(
    'throws.fix.notExhaustiveTryCatch',
    DartFixKindPriority.standard,
    'Add missing catch clauses',
  );

  NotExhaustiveTryCatchFix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _assistKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final tryStatement = node.thisOrAncestorOfType<TryStatement>();
    if (tryStatement == null || tryStatement.catchClauses.isEmpty) {
      return;
    }

    final analysis = AnalysisCache.analysis(unit);
    final summary = analysis.summaryFor(tryStatement.enclosingFunction);
    if (summary == null) {
      return;
    }

    final missing = <DartType>{};
    for (final site in summary.sitesWithin(tryStatement.body)) {
      if (site.isCall) {
        missing.addAll(summary.uncovered(site, analysis.typeSystem).types);
      }
    }
    if (missing.isEmpty) {
      return;
    }

    final lastCatch = tryStatement.catchClauses.last;
    final indent = utils.getLinePrefix(lastCatch.offset);
    await builder.addDartFileEdit(file, (builder) {
      for (final type in subtypesFirst(missing)) {
        // A clause for a supertype must come after the new one.
        final before = clauseCatching(
          tryStatement,
          type,
          analysis.typeSystem,
        );
        if (before != null) {
          builder.addInsertion(before.offset, (builder) {
            writeCatchClause(builder, type, indent);
            builder.write(' ');
          });
        } else {
          builder.addInsertion(lastCatch.end, (builder) {
            builder.write(' ');
            writeCatchClause(builder, type, indent);
          });
        }
      }
    });
  }
}

class NotExhaustiveTryCatchDefaultFix extends ResolvedCorrectionProducer {
  static const _fixKind = FixKind(
    'throws.fix.notExhaustiveTryCatchDefault',
    DartFixKindPriority.standard,
    'Add default catch clause',
  );

  NotExhaustiveTryCatchDefaultFix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final tryStatement = node.thisOrAncestorOfType<TryStatement>();
    if (tryStatement == null || tryStatement.catchClauses.isEmpty) {
      return;
    }
    if (tryStatement.catchClauses.any(
      (clause) => !alwaysRethrows(clause) && catchesAll(clause),
    )) {
      return;
    }

    final lastCatch = tryStatement.catchClauses.last;
    final indent = utils.getLinePrefix(lastCatch.offset);
    await builder.addDartFileEdit(file, (builder) {
      builder.addInsertion(lastCatch.end, (builder) {
        builder.write(' ');
        writeCatchClause(builder, null, indent);
      });
    });
  }
}
