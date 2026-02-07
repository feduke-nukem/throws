import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

final List<AnalysisRule> throwsLintRules = [
  MissingThrowsAnnotationRule(),
  UnhandledThrowsCallRule(),
  UnusedThrowsAnnotationRule(),
];

class MissingThrowsAnnotationRule extends AnalysisRule {
  static const LintCode _code = LintCode(
    'missing_throws_annotation',
    'Functions that throw must be annotated with @Throws.',
    correctionMessage:
        'Add @Throws(reason, expectedErrors) or @throws to this function.',
  );

  MissingThrowsAnnotationRule()
    : super(
        name: 'missing_throws_annotation',
        description: 'Requires @Throws on functions that throw.',
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
        _ThrowsRuleKind.missingThrowsAnnotation,
      ),
    );
  }
}

class UnhandledThrowsCallRule extends AnalysisRule {
  static const LintCode _code = LintCode(
    'unhandled_throws_call',
    'Calling a @Throws function must be handled or annotated.',
    correctionMessage:
        'Wrap the call in try/catch or annotate the function with @Throws.',
  );

  UnhandledThrowsCallRule()
    : super(
        name: 'unhandled_throws_call',
        description:
            'Requires @Throws or try/catch when calling @Throws functions.',
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
      _ThrowsCompilationUnitVisitor(this, _ThrowsRuleKind.unhandledThrowsCall),
    );
  }
}

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

enum _ThrowsRuleKind {
  missingThrowsAnnotation,
  unhandledThrowsCall,
  unusedThrowsAnnotation,
}

class _ThrowsCompilationUnitVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule _rule;
  final _ThrowsRuleKind _kind;

  _ThrowsCompilationUnitVisitor(this._rule, this._kind);

  @override
  void visitCompilationUnit(CompilationUnit node) {
    final summaries = _ThrowsAnalyzer().analyze(node);

    for (final summary in summaries) {
      switch (_kind) {
        case _ThrowsRuleKind.missingThrowsAnnotation:
          if (!summary.hasThrowsAnnotation && summary.hasUnhandledThrow) {
            _rule.reportAtToken(summary.nameToken);
          }
          break;
        case _ThrowsRuleKind.unhandledThrowsCall:
          if (!summary.hasThrowsAnnotation &&
              summary.unhandledThrowingCallNodes.isNotEmpty) {
            for (final node in summary.unhandledThrowingCallNodes) {
              _rule.reportAtNode(node);
            }
          }
          break;
        case _ThrowsRuleKind.unusedThrowsAnnotation:
          if (summary.hasThrowsAnnotation &&
              !summary.hasUnhandledThrow &&
              !summary.hasUnhandledThrowingCall) {
            _rule.reportAtToken(summary.nameToken);
          }
          break;
      }
    }
  }
}

class _ThrowsAnalyzer {
  List<_FunctionSummary> analyze(CompilationUnit unit) {
    final collector = _FunctionCollector();
    unit.accept(collector);

    for (final summary in collector.summaries) {
      final visitor = _FunctionBodyVisitor(summary);
      summary.body.accept(visitor);
    }

    return collector.summaries;
  }
}

class _FunctionCollector extends RecursiveAstVisitor<void> {
  final List<_FunctionSummary> summaries = [];

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    summaries.add(
      _FunctionSummary(
        nameToken: node.name,
        body: node.functionExpression.body,
        hasThrowsAnnotation: _hasThrowsAnnotationOnNode(node.metadata),
      ),
    );
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    summaries.add(
      _FunctionSummary(
        nameToken: node.name,
        body: node.body,
        hasThrowsAnnotation: _hasThrowsAnnotationOnNode(node.metadata),
      ),
    );
    super.visitMethodDeclaration(node);
  }
}

class _FunctionSummary {
  final Token nameToken;
  final FunctionBody body;
  final bool hasThrowsAnnotation;
  bool hasUnhandledThrow = false;
  bool hasUnhandledThrowingCall = false;
  final List<AstNode> unhandledThrowingCallNodes = [];

  _FunctionSummary({
    required this.nameToken,
    required this.body,
    required this.hasThrowsAnnotation,
  });
}

class _FunctionBodyVisitor extends RecursiveAstVisitor<void> {
  final _FunctionSummary _summary;

  _FunctionBodyVisitor(this._summary);

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Skip nested functions/closures when analyzing the outer function.
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    // Skip nested methods when analyzing the outer function.
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // Skip nested functions when analyzing the outer function.
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    if (!_isHandledByTryCatch(node)) {
      _summary.hasUnhandledThrow = true;
    }
    super.visitThrowExpression(node);
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    if (!_isHandledByTryCatch(node)) {
      _summary.hasUnhandledThrow = true;
    }
    super.visitRethrowExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final element = node.methodName.element;
    if (_isThrowsAnnotated(element) && !_isHandledByTryCatch(node)) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node.methodName);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final element = node.element;
    if (_isThrowsAnnotated(element) && !_isHandledByTryCatch(node)) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node);
    }
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final element = node.constructorName.element;
    if (_isThrowsAnnotated(element) && !_isHandledByTryCatch(node)) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node.constructorName);
    }
    super.visitInstanceCreationExpression(node);
  }

  bool _isHandledByTryCatch(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is TryStatement) {
        if (_isWithin(node, current.body) && _tryProvidesHandling(current)) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  bool _isWithin(AstNode node, AstNode container) {
    return node.offset >= container.offset && node.end <= container.end;
  }

  bool _tryProvidesHandling(TryStatement statement) {
    if (statement.catchClauses.isEmpty) {
      return false;
    }

    for (final clause in statement.catchClauses) {
      if (!_catchAlwaysRethrows(clause)) {
        return true;
      }
    }
    return false;
  }

  bool _catchAlwaysRethrows(CatchClause clause) {
    final visitor = _ThrowFinder();
    clause.body.accept(visitor);
    return visitor.foundThrow;
  }
}

class _ThrowFinder extends RecursiveAstVisitor<void> {
  bool foundThrow = false;

  @override
  void visitThrowExpression(ThrowExpression node) {
    foundThrow = true;
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    foundThrow = true;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Ignore nested functions.
  }
}

bool _hasThrowsAnnotationOnNode(List<Annotation> metadata) {
  for (final annotation in metadata) {
    final name = _annotationName(annotation);
    if (name == 'Throws' || name == 'throws') {
      return true;
    }
    final source = annotation.toSource();
    if (source.startsWith('@Throws') || source.startsWith('@throws')) {
      return true;
    }
  }
  return false;
}

String? _annotationName(Annotation annotation) {
  final identifier = annotation.name;
  if (identifier is SimpleIdentifier) {
    return identifier.name;
  }
  if (identifier is PrefixedIdentifier) {
    return identifier.identifier.name;
  }
  return null;
}

bool _isThrowsAnnotated(Element? element) {
  final executable = element is ExecutableElement ? element : null;
  if (executable == null) {
    return false;
  }

  return executable.metadata.annotations.any(_isThrowsAnnotation);
}

bool _isThrowsAnnotation(ElementAnnotation annotation) {
  final value = annotation.computeConstantValue();
  final type = value?.type;
  if (type?.element?.name == 'Throws') {
    return true;
  }
  return annotation.element?.name == 'throws';
}
