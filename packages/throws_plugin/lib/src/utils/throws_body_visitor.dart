import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/extensions/type_annotation_x.dart';
import 'package:throws_plugin/src/utils/throw_finder.dart';

class ThrowsBodyVisitor extends RecursiveAstVisitor<void> {
  bool hasUnhandledThrow = false;
  bool hasUnhandledThrowingCall = false;

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
  void visitThrowExpression(ThrowExpression node) {
    if (!_isHandledByTryCatch(node)) {
      hasUnhandledThrow = true;
    }
    super.visitThrowExpression(node);
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    if (!_isHandledByTryCatch(node)) {
      hasUnhandledThrow = true;
    }
    super.visitRethrowExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (isErrorThrowWithStackTrace(node)) {
      final expectedErrors = expectedErrorsFromErrorThrowWithStackTrace(node);
      if (!_isHandledByTryCatch(node, expectedErrors: expectedErrors)) {
        hasUnhandledThrow = true;
      }
      super.visitMethodInvocation(node);
      return;
    }
    final element = node.methodName.element;
    final expected = expectedErrorsFromElementOrSdk(element);
    if (isThrowsAnnotatedOrSdk(element) &&
        !_isHandledByTryCatch(
          node,
          expectedErrors: expected,
        )) {
      hasUnhandledThrowingCall = true;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final element = node.element;
    final expected = expectedErrorsFromElementOrSdk(element);
    if (isThrowsAnnotatedOrSdk(element) &&
        !_isHandledByTryCatch(
          node,
          expectedErrors: expected,
        )) {
      hasUnhandledThrowingCall = true;
    }
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final element = node.constructorName.element;
    final expected = expectedErrorsFromElementOrSdk(element);
    if (isThrowsAnnotatedOrSdk(element) &&
        !_isHandledByTryCatch(
          node,
          expectedErrors: expected,
        )) {
      hasUnhandledThrowingCall = true;
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final element = node.propertyName.element;
    final expected = expectedErrorsFromElementOrSdk(element);
    if (isThrowsAnnotatedOrSdk(element) &&
        !_isHandledByTryCatch(
          node,
          expectedErrors: expected,
        )) {
      hasUnhandledThrowingCall = true;
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final element = node.identifier.element;
    final expected = expectedErrorsFromElementOrSdk(element);
    if (isThrowsAnnotatedOrSdk(element) &&
        !_isHandledByTryCatch(
          node,
          expectedErrors: expected,
        )) {
      hasUnhandledThrowingCall = true;
    }
    super.visitPrefixedIdentifier(node);
  }

  bool _isHandledByTryCatch(
    AstNode node, {
    Set<String>? expectedErrors,
  }) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is TryStatement) {
        if (_isWithin(node, current.body)) {
          if (expectedErrors == null || expectedErrors.isEmpty) {
            if (_tryProvidesHandling(current)) {
              return true;
            }
          } else if (_tryCatchesAllExpected(current, expectedErrors)) {
            return true;
          }
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

  bool _tryCatchesAllExpected(
    TryStatement statement,
    Set<String> expectedErrors,
  ) {
    if (statement.catchClauses.isEmpty) {
      return false;
    }

    final covered = <String>{};

    for (final clause in statement.catchClauses) {
      final typeName = clause.exceptionType?.typeName;
      if (typeName == null) {
        return true;
      }
      if (isCatchAllType(typeName)) {
        return true;
      }

      covered.add(typeName);
    }

    return expectedErrors.every(covered.contains);
  }

  bool _catchAlwaysRethrows(CatchClause clause) {
    final visitor = RethrowFinder();
    clause.body.accept(visitor);
    return visitor.foundRethrow;
  }
}
