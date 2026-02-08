import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:throws_plugin/src/helpers.dart';

class ThrowsInvocationFinder extends RecursiveAstVisitor<void> {
  final Map<String, List<String>> _expectedErrorsByName;
  final Set<Element> _localThrowingElements;
  final Map<Element, List<String>> _localExpectedErrorsByElement;
  List<String>? expectedErrors;

  ThrowsInvocationFinder(
    this._expectedErrorsByName,
    this._localThrowingElements,
    this._localExpectedErrorsByElement,
  );

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Skip nested functions.
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // Skip nested functions.
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    // Skip nested methods.
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (isErrorThrowWithStackTrace(node)) {
      final typeName = typeNameFromErrorThrowWithStackTrace(node);
      expectedErrors ??= typeName == null ? const [] : [typeName];
      super.visitMethodInvocation(node);
      return;
    }
    final element = node.methodName.element;
    final expected = expectedErrorsFromElementOrSdk(element);
    if (expected.isNotEmpty) {
      expectedErrors ??= expected.toList();
    } else if (_isLocalThrowingElement(element)) {
      final base = element?.baseElement;
      expectedErrors ??= base == null
          ? const []
          : (_localExpectedErrorsByElement[base] ?? const []);
    } else if (_isAnnotatedTopLevelCall(node)) {
      expectedErrors ??=
          _expectedErrorsByName[node.methodName.name] ?? const [];
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final expected = expectedErrorsFromElementOrSdk(node.element);
    if (expected.isNotEmpty) {
      expectedErrors ??= expected.toList();
    } else if (_isLocalThrowingElement(node.element)) {
      final base = node.element?.baseElement;
      expectedErrors ??= base == null
          ? const []
          : (_localExpectedErrorsByElement[base] ?? const []);
    }
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final expected = expectedErrorsFromElementOrSdk(
      node.constructorName.element,
    );
    if (expected.isNotEmpty) {
      expectedErrors ??= expected.toList();
    } else if (_isLocalThrowingElement(node.constructorName.element)) {
      final base = node.constructorName.element?.baseElement;
      expectedErrors ??= base == null
          ? const []
          : (_localExpectedErrorsByElement[base] ?? const []);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final expected = expectedErrorsFromElementOrSdk(node.propertyName.element);
    if (expected.isNotEmpty) {
      expectedErrors ??= expected.toList();
    } else if (_isLocalThrowingElement(node.propertyName.element)) {
      final base = node.propertyName.element?.baseElement;
      expectedErrors ??= base == null
          ? const []
          : (_localExpectedErrorsByElement[base] ?? const []);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final expected = expectedErrorsFromElementOrSdk(node.identifier.element);
    if (expected.isNotEmpty) {
      expectedErrors ??= expected.toList();
    } else if (_isLocalThrowingElement(node.identifier.element)) {
      final base = node.identifier.element?.baseElement;
      expectedErrors ??= base == null
          ? const []
          : (_localExpectedErrorsByElement[base] ?? const []);
    }
    super.visitPrefixedIdentifier(node);
  }

  bool _isLocalThrowingElement(Element? element) {
    if (element == null) {
      return false;
    }
    return _localThrowingElements.contains(element.baseElement);
  }

  bool _isAnnotatedTopLevelCall(MethodInvocation node) {
    if (node.target != null) {
      return false;
    }
    return _expectedErrorsByName.containsKey(node.methodName.name);
  }
}
