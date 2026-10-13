import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';
import 'package:throws_plugin/src/data/error_set.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/fixes/catch_clauses.dart';
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
            !summary.isClosure &&
            !site.inTryWithCatch &&
            !summary.uncovered(site, analysis.typeSystem).isEmpty) {
          rule.reportAtNode(site.node);
        }
      }
    }
  }
}

/// Wraps the statement with the throwing call in try/catch.
abstract class _WrapInTryFix extends ResolvedCorrectionProducer {
  _WrapInTryFix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  /// Types to catch; `null` entries write `on Object`.
  List<DartType?> clauseTypes(ErrorSet errors);

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final statement = _wrappableStatement(node);
    if (statement != null) {
      return _wrapStatement(builder, statement);
    }
    final body = _voidExpressionBody(node, unit);
    if (body != null) {
      return _wrapExpressionBody(builder, body);
    }
  }

  void _writeClauses(DartEditBuilder builder, ErrorSet errors, String indent) {
    final types = clauseTypes(errors);
    for (var i = 0; i < types.length; i++) {
      builder.write(' ');
      writeCatchClause(builder, types[i], indent, index: i);
    }
  }

  /// `void f() => call();` becomes a block body with try/catch.
  Future<void> _wrapExpressionBody(
    ChangeBuilder builder,
    ExpressionFunctionBody body,
  ) async {
    final errors = _uncoveredErrors(unit, body);
    if (errors.isEmpty) {
      return;
    }
    final indent = utils.getLinePrefix(body.offset);
    await builder.addDartFileEdit(file, (builder) {
      builder.addReplacement(range.node(body), (builder) {
        if (body.keyword case final keyword?) {
          builder.write('${keyword.lexeme} ');
        }
        builder.writeln('{');
        builder.writeln('$indent  try {');
        builder.writeln('$indent    ${utils.getNodeText(body.expression)};');
        builder.write('$indent  }');
        _writeClauses(builder, errors, '$indent  ');
        builder.writeln();
        builder.write('$indent}');
      });
    });
  }

  Future<void> _wrapStatement(
    ChangeBuilder builder,
    Statement statement,
  ) async {
    final errors = _uncoveredErrors(unit, statement);
    if (errors.isEmpty) {
      return;
    }

    final replacementRange = utils.getLinesRange(range.node(statement));
    final indent = utils.getLinePrefix(replacementRange.offset);
    await builder.addDartFileEdit(file, (builder) {
      builder.addReplacement(replacementRange, (builder) {
        final body = switch (statement) {
          VariableDeclarationStatement(:final variables) =>
            _writeLateDeclaration(
              builder,
              variables,
              indent,
            ),
          _ => utils.getNodeText(statement),
        };
        builder.writeln('${indent}try {');
        builder.writeln('$indent  $body');
        builder.write('$indent}');
        _writeClauses(builder, errors, indent);
        builder.writeln();
      });
    });
  }

  /// Declares `late` the variable of `final x = call();` before the try, so
  /// it stays in scope; returns the assignment for the try body.
  String _writeLateDeclaration(
    DartEditBuilder builder,
    VariableDeclarationList variables,
    String indent,
  ) {
    final variable = variables.variables.single;
    builder.write('${indent}late ');
    if (variables.isFinal) {
      builder.write('final ');
    }
    final type = variables.type;
    if (type != null) {
      builder.write(utils.getNodeText(type));
    } else {
      builder.writeType(
        variable.declaredFragment?.element.type,
        shouldWriteDynamic: true,
      );
    }
    builder.writeln(' ${variable.name.lexeme};');
    return '${variable.name.lexeme} = '
        '${utils.getNodeText(variable.initializer!)};';
  }
}

class NoTryCatchFix extends _WrapInTryFix {
  static const FixKind _fixKind = FixKind(
    'throws.fix.noTryCatch',
    DartFixKindPriority.standard,
    'Wrap in try/catch',
  );

  NoTryCatchFix({required super.context});

  @override
  FixKind get fixKind => _fixKind;

  @override
  List<DartType?> clauseTypes(ErrorSet errors) =>
      errors.types.isEmpty ? const [null] : subtypesFirst(errors.types);
}

class NoTryCatchWithDefaultFix extends _WrapInTryFix {
  static const FixKind _fixKind = FixKind(
    'throws.fix.noTryCatchDefault',
    DartFixKindPriority.standard,
    'Wrap in try/catch with default clause',
  );

  NoTryCatchWithDefaultFix({required super.context});

  @override
  FixKind get fixKind => _fixKind;

  @override
  List<DartType?> clauseTypes(ErrorSet errors) => const [null];
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

/// The `=> expression` body of the function around [node] when the function
/// returns nothing, so wrapping it needs no return value in catch clauses.
ExpressionFunctionBody? _voidExpressionBody(
  AstNode node,
  CompilationUnit unit,
) {
  final body = node.thisOrAncestorOfType<ExpressionFunctionBody>();
  final summary = AnalysisCache.analysis(
    unit,
  ).summaryFor(node.enclosingFunctionOrClosure);
  final returnType = summary?.element?.returnType;
  if (body == null || summary?.body != body || returnType == null) {
    return null;
  }
  final isVoid =
      returnType is VoidType ||
      ((returnType.isDartAsyncFuture || returnType.isDartAsyncFutureOr) &&
          returnType is InterfaceType &&
          returnType.typeArguments.single is VoidType);
  return isVoid ? body : null;
}

/// Errors from calls in [scope] that the enclosing function does not declare.
ErrorSet _uncoveredErrors(CompilationUnit unit, AstNode scope) {
  final analysis = AnalysisCache.analysis(unit);
  final summary = analysis.summaryFor(scope.enclosingFunctionOrClosure);
  if (summary == null) {
    return ErrorSet.empty;
  }
  var errors = ErrorSet.empty;
  for (final site in summary.sitesWithin(scope)) {
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
