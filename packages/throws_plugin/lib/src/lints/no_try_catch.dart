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
import 'package:throws_plugin/src/data/error_set.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/utils/analysis_cache.dart';
import 'package:throws_plugin/src/utils/extensions/ast_node_x.dart';
import 'package:throws_plugin/src/utils/extensions/statement_x.dart';

class NoTryCatch extends AnalysisRule {
  static const LintCode _code = LintCode(
    'no_try_catch',
    'Calling a throwing function must be handled or annotated.',
    correctionMessage:
        'Wrap the call in try/catch or annotate the function with @${ThrowsAnnotation.nameCapitalized}.',
    severity: DiagnosticSeverity.ERROR,
  );

  NoTryCatch()
    : super(
        name: 'no_try_catch',
        description:
            'Requires @${ThrowsAnnotation.nameCapitalized} or try/catch when calling throwing functions.',
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
            !site.inTryWithCatch &&
            !summary.uncovered(site, analysis.typeSystem).isEmpty) {
          rule.reportAtNode(site.node);
        }
      }
    }
  }
}

class NoTryCatchFix extends ResolvedCorrectionProducer {
  static const FixKind _fixKind = FixKind(
    'throws.fix.noTryCatch',
    DartFixKindPriority.standard,
    'Wrap in try/catch',
  );

  NoTryCatchFix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    try {
      final statement = _wrappableStatement(node);
      if (statement == null) {
        return;
      }

      final errors = _uncoveredErrors(unit, statement);
      if (errors.isEmpty) {
        return;
      }

      final replacementRange = utils.getLinesRange(range.node(statement));
      final indent = utils.getLinePrefix(replacementRange.offset);
      final types = errors.sortedTypes;
      await builder.addDartFileEdit(file, (builder) {
        builder.addReplacement(replacementRange, (builder) {
          builder.writeln('${indent}try {');
          builder.writeln('$indent  ${statement.toSource().trim()}');
          builder.write('$indent}');
          if (types.isEmpty) {
            builder.writeln(' on Object catch (e, stackTrace) {');
            builder.writeln('$indent  // TODO: handle error');
            builder.write('$indent}');
          }
          for (final type in types) {
            builder.write(' on ');
            builder.writeType(type);
            builder.writeln(' catch (e, stackTrace) {');
            builder.writeln('$indent  // TODO: handle error');
            builder.write('$indent}');
          }
          builder.writeln();
        });
      });
    } catch (_) {
      return;
    }
  }
}

class NoTryCatchWithDefaultFix extends ResolvedCorrectionProducer {
  static const FixKind _fixKind = FixKind(
    'throws.fix.noTryCatchDefault',
    DartFixKindPriority.standard,
    'Wrap in try/catch with default clause',
  );

  NoTryCatchWithDefaultFix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    try {
      final statement = _wrappableStatement(node);
      if (statement == null || _uncoveredErrors(unit, statement).isEmpty) {
        return;
      }

      final replacementRange = utils.getLinesRange(range.node(statement));
      final indent = utils.getLinePrefix(replacementRange.offset);
      await builder.addDartFileEdit(file, (builder) {
        builder.addReplacement(replacementRange, (builder) {
          builder.writeln('${indent}try {');
          builder.writeln('$indent  ${statement.toSource().trim()}');
          builder.writeln('$indent} on Object catch (e, stackTrace) {');
          builder.writeln('$indent  // TODO: handle error');
          builder.writeln('$indent}');
        });
      });
    } catch (_) {
      return;
    }
  }
}

/// Statement around [node] that a try/catch can wrap.
Statement? _wrappableStatement(AstNode node) {
  final statement = node.enclosingStatement;
  if (statement == null ||
      statement.isSynthetic ||
      statement.isWithinTryStatement ||
      statement.expression == null) {
    return null;
  }
  return statement;
}

/// Errors from calls in [statement] that the enclosing function does not
/// declare.
ErrorSet _uncoveredErrors(CompilationUnit unit, Statement statement) {
  final analysis = AnalysisCache.analysis(unit);
  final summary = analysis.summaryFor(statement.enclosingFunction);
  if (summary == null) {
    return ErrorSet.empty;
  }
  var errors = ErrorSet.empty;
  for (final site in summary.sitesWithin(statement)) {
    // Wrapping an unawaited future in try/catch would not handle its errors.
    if (site.isUnawaitedFuture) {
      return ErrorSet.empty;
    }
    if (site.isCall) {
      errors = errors.union(summary.uncovered(site, analysis.typeSystem));
    }
  }
  return errors;
}
