import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:throws_plugin/src/data/function_summary.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/extensions/ast_node_x.dart';
import 'package:throws_plugin/src/utils/extensions/expression_x.dart';

class ThrowsAnalyzer {
  List<FunctionSummary> analyze(CompilationUnit unit) {
    final collector = _FunctionCollector();
    unit.accept(collector);

    for (final summary in collector.summaries) {
      final visitor = _FunctionBodyVisitor(
        summary,
        includeAnnotatedAndSdk: true,
        localThrowingElements: const {},
      );
      summary.body.accept(visitor);
    }

    final localThrowingElements = <Element>{};
    collector.summaryByElement.forEach((element, summary) {
      if (summary.hasUnhandledThrow || summary.hasUnhandledThrowingCall) {
        localThrowingElements.add(element);
      }
    });

    if (localThrowingElements.isNotEmpty) {
      for (final summary in collector.summaries) {
        final visitor = _FunctionBodyVisitor(
          summary,
          includeAnnotatedAndSdk: false,
          localThrowingElements: localThrowingElements,
        );
        summary.body.accept(visitor);
      }
    }

    return collector.summaries;
  }
}

class _FunctionCollector extends RecursiveAstVisitor<void> {
  final List<FunctionSummary> summaries = [];
  final Map<Element, FunctionSummary> summaryByElement = {};

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final expectedErrors = expectedErrorsFromMetadata(node.metadata).toSet();
    final summary = FunctionSummary(
      nameToken: node.name,
      body: node.functionExpression.body,
      hasThrowsAnnotation: hasThrowsAnnotationOnNode(node.metadata),
      annotatedExpectedErrors: expectedErrors,
      allowAnyExpectedErrors:
          hasThrowsAnnotationOnNode(node.metadata) && expectedErrors.isEmpty,
      isAbstractOrExternal: isAbstractOrExternalBody(
        node.functionExpression.body,
        node.externalKeyword,
      ),
    );
    summary.element = node.declaredFragment?.element.baseElement;
    summaries.add(summary);
    final element = node.declaredFragment?.element;
    if (element != null) {
      summaryByElement[element.baseElement] = summary;
    }
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final expectedErrors = expectedErrorsFromMetadata(node.metadata).toSet();
    final summary = FunctionSummary(
      nameToken: node.name,
      body: node.body,
      hasThrowsAnnotation: hasThrowsAnnotationOnNode(node.metadata),
      annotatedExpectedErrors: expectedErrors,
      allowAnyExpectedErrors:
          hasThrowsAnnotationOnNode(node.metadata) && expectedErrors.isEmpty,
      isAbstractOrExternal:
          node.isAbstract ||
          isAbstractOrExternalBody(node.body, node.externalKeyword),
    );
    summary.element = node.declaredFragment?.element.baseElement;
    summaries.add(summary);
    final element = node.declaredFragment?.element;
    if (element != null) {
      summaryByElement[element.baseElement] = summary;
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final expectedErrors = expectedErrorsFromMetadata(node.metadata).toSet();
    final summary = FunctionSummary(
      // ignore: deprecated_member_use
      nameToken: node.name ?? node.returnType.beginToken,
      body: node.body,
      hasThrowsAnnotation: hasThrowsAnnotationOnNode(node.metadata),
      annotatedExpectedErrors: expectedErrors,
      allowAnyExpectedErrors:
          hasThrowsAnnotationOnNode(node.metadata) && expectedErrors.isEmpty,
      isAbstractOrExternal: isAbstractOrExternalBody(
        node.body,
        node.externalKeyword,
      ),
    );
    summary.element = node.declaredFragment?.element.baseElement;
    summaries.add(summary);
    final element = node.declaredFragment?.element;
    if (element != null) {
      summaryByElement[element.baseElement] = summary;
    }
    super.visitConstructorDeclaration(node);
  }
}

class _FunctionBodyVisitor extends RecursiveAstVisitor<void> {
  final FunctionSummary _summary;
  final bool _includeAnnotatedAndSdk;
  final Set<Element> _localThrowingElements;

  _FunctionBodyVisitor(
    this._summary, {
    required bool includeAnnotatedAndSdk,
    required Set<Element> localThrowingElements,
  }) : _includeAnnotatedAndSdk = includeAnnotatedAndSdk,
       _localThrowingElements = localThrowingElements;

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
    if (!node.isHandledByTryCatch()) {
      _summary.hasUnhandledThrow = true;
      _summary.unhandledThrowNodes.add(node);
      final typeName = node.expression.typeName;
      if (typeName != null) {
        _summary.thrownErrors.add(typeName);
      }
    }
    super.visitThrowExpression(node);
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    if (!node.isHandledByTryCatch()) {
      _summary.hasUnhandledThrow = true;
      _summary.unhandledThrowNodes.add(node);
      final catchTypeName = node.catchClauseTypeName;
      _summary.thrownErrors.add(catchTypeName ?? 'Object');
    }
    super.visitRethrowExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (isErrorThrowWithStackTrace(node)) {
      final expectedErrors = expectedErrorsFromErrorThrowWithStackTrace(node);
      if (!node.isHandledByTryCatch(expectedErrors)) {
        _summary.hasUnhandledThrow = true;
        _summary.unhandledThrowNodes.add(node);
        final typeName = typeNameFromErrorThrowWithStackTrace(node);
        if (typeName != null) {
          _summary.thrownErrors.add(typeName);
        }
      }
      super.visitMethodInvocation(node);
      return;
    }
    final element = node.methodName.element;
    if (_includeAnnotatedAndSdk && isThrowsAnnotatedOrSdk(element)) {
      _registerUnhandledThrowingCall(
        node,
        node.methodName,
        expectedErrorsFromElementOrSdk(element),
        addThrownErrors: true,
      );
    }
    if (_isLocalThrowingElement(element) &&
        !_isHandledLocalThrowingCall(node, element)) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node.methodName);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final element = node.element;
    if (_includeAnnotatedAndSdk && isThrowsAnnotatedOrSdk(element)) {
      _registerUnhandledThrowingCall(
        node,
        node,
        expectedErrorsFromElementOrSdk(element),
        addThrownErrors: true,
      );
    }
    if (_isLocalThrowingElement(element) &&
        !_isHandledLocalThrowingCall(node, element)) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node);
    }
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final element = node.constructorName.element;
    if (_includeAnnotatedAndSdk && isThrowsAnnotatedOrSdk(element)) {
      _registerUnhandledThrowingCall(
        node,
        node.constructorName,
        expectedErrorsFromElementOrSdk(element),
        addThrownErrors: true,
      );
    }
    if (_isLocalThrowingElement(element) &&
        !_isHandledLocalThrowingCall(node, element)) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node.constructorName);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final element = node.propertyName.element;
    if (_includeAnnotatedAndSdk && isThrowsAnnotatedOrSdk(element)) {
      _registerUnhandledThrowingCall(
        node,
        node.propertyName,
        expectedErrorsFromElementOrSdk(element),
        addThrownErrors: true,
      );
    }
    if (_isLocalThrowingElement(element) &&
        !_isHandledLocalThrowingCall(node, element)) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node.propertyName);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final element = node.identifier.element;
    if (_includeAnnotatedAndSdk && isThrowsAnnotatedOrSdk(element)) {
      _registerUnhandledThrowingCall(
        node,
        node.identifier,
        expectedErrorsFromElementOrSdk(element),
        addThrownErrors: true,
      );
    }
    if (_isLocalThrowingElement(element) &&
        !_isHandledLocalThrowingCall(node, element)) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node.identifier);
    }
    super.visitPrefixedIdentifier(node);
  }

  bool _isLocalThrowingElement(Element? element) {
    if (element == null) {
      return false;
    }
    if (_localThrowingElements.isEmpty) {
      return false;
    }
    return _localThrowingElements.contains(element.baseElement);
  }

  bool _isHandledThrowingCall(AstNode node, Set<String> expectedErrors) {
    if (expectedErrors.isEmpty) {
      return node.isWithinTryWithCatch;
    }
    return node.unhandledExpectedErrors(expectedErrors).isEmpty;
  }

  bool _isHandledLocalThrowingCall(AstNode node, Element? element) {
    final expectedErrors = expectedErrorsFromElementOrSdk(element);
    if (expectedErrors.isNotEmpty) {
      return _isHandledThrowingCall(node, expectedErrors);
    }
    return node.isHandledByTryCatch();
  }

  bool _registerUnhandledThrowingCall(
    AstNode node,
    AstNode reportNode,
    Set<String> expectedErrors, {
    required bool addThrownErrors,
  }) {
    if (expectedErrors.isEmpty) {
      if (!node.isWithinTryWithCatch) {
        _summary.hasUnhandledThrowingCall = true;
        _summary.unhandledThrowingCallNodes.add(reportNode);
        return true;
      }
      return false;
    }

    final unhandled = node.unhandledExpectedErrors(expectedErrors);
    if (unhandled.isEmpty) {
      return false;
    }

    _summary.hasUnhandledThrowingCall = true;
    _summary.unhandledThrowingCallNodes.add(reportNode);
    if (addThrownErrors) {
      _summary.thrownErrors.addAll(unhandled);
    }
    return true;
  }
}
