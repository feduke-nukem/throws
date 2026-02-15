import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:throws_plugin/src/data/function_summary.dart';
import 'package:throws_plugin/src/data/local_throwing_info.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/analysis_cache.dart';
import 'package:throws_plugin/src/utils/extensions/ast_node_x.dart';
import 'package:throws_plugin/src/utils/extensions/expression_x.dart';
import 'package:throws_plugin/src/utils/extensions/function_summary_x.dart';

class IntroducedThrowsInOverride extends AnalysisRule {
  static const LintCode _code = LintCode(
    'introduced_throws_in_override',
    'Overrides should not introduce new thrown errors as it violates Liskov Substitution Principle',
    correctionMessage:
        'Match the @${ThrowsAnnotation.nameCapitalized} annotation of the overridden member or handle errors.',
    severity: DiagnosticSeverity.ERROR,
  );

  IntroducedThrowsInOverride()
    : super(
        name: 'introduced_throws_in_override',
        description:
            'Disallows new errors in overrides without @${ThrowsAnnotation.nameCapitalized}.',
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
    final summaries = AnalysisCache.throwsSummaries(node);
    final localInfo = AnalysisCache.localThrowingInfo(node);

    for (final summary in summaries) {
      final info = summary.inheritedThrowsInfo;
      if (info == null || info.allowAny) {
        continue;
      }

      final shouldReportIntroducedThrows =
          (summary.hasUnhandledThrow || summary.hasUnhandledThrowingCall) &&
          summary.introducesNewErrors;

      if (!shouldReportIntroducedThrows) {
        continue;
      }

      final reportNodes = _collectIntroducedNodes(
        summary,
        info.expectedErrors,
        localInfo,
      );
      if (reportNodes.isEmpty) {
        rule.reportAtToken(summary.nameToken);
        continue;
      }
      for (final node in reportNodes) {
        rule.reportAtNode(node);
      }
    }
  }

  List<AstNode> _collectIntroducedNodes(
    FunctionSummary summary,
    Set<String> inheritedErrors,
    LocalThrowingInfo localInfo,
  ) {
    final nodes = <AstNode>[];
    final candidates = <AstNode>[
      ...summary.unhandledThrowNodes,
      ...summary.unhandledThrowingCallNodes,
    ];
    for (final node in candidates) {
      final expected = _expectedErrorsForNode(node, localInfo);
      if (expected.isEmpty) {
        continue;
      }
      final introduced = expected.any(
        (error) => !inheritedErrors.contains(error),
      );
      if (introduced) {
        nodes.add(node);
      }
    }
    return nodes;
  }

  Set<String> _expectedErrorsForNode(
    AstNode node,
    LocalThrowingInfo localInfo,
  ) {
    if (node is ThrowExpression) {
      final typeName = node.expression.typeName;
      return {typeName ?? 'Object'};
    }
    if (node is RethrowExpression) {
      final catchTypeName = node.catchClauseTypeName;
      return {catchTypeName ?? 'Object'};
    }
    if (node is MethodInvocation && isErrorThrowWithStackTrace(node)) {
      return expectedErrorsFromErrorThrowWithStackTrace(node);
    }

    final element = _elementForCallNode(node);
    final expected = expectedErrorsFromElementOrSdk(element);
    if (expected.isNotEmpty) {
      return expected;
    }
    final base = element?.baseElement;
    if (base == null) {
      return const {};
    }
    final localExpected = localInfo.expectedErrorsByElement[base];
    if (localExpected == null || localExpected.isEmpty) {
      return const {};
    }
    return localExpected.toSet();
  }

  Element? _elementForCallNode(AstNode node) {
    if (node is SimpleIdentifier) {
      return node.element;
    }
    if (node is MethodInvocation) {
      return node.methodName.element;
    }
    if (node is FunctionExpressionInvocation) {
      return node.element;
    }
    if (node is ConstructorName) {
      return node.element;
    }
    if (node is PropertyAccess) {
      return node.propertyName.element;
    }
    if (node is PrefixedIdentifier) {
      return node.identifier.element;
    }
    return null;
  }
}
