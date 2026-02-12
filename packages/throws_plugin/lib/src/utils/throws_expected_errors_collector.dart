import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/extensions/ast_node_x.dart';
import 'package:throws_plugin/src/utils/extensions/expression_x.dart';
import 'package:throws_plugin/src/utils/extensions/type_annotation_x.dart';
import 'package:throws_plugin/src/utils/throw_finder.dart';

class ThrowsExpectedErrorsCollector extends RecursiveAstVisitor<void> {
  final Set<String> _errors = {};
  final Map<Element, List<String>> _localExpectedErrorsByElement;

  ThrowsExpectedErrorsCollector({
    required Map<Element, List<String>> localExpectedErrorsByElement,
  }) : _localExpectedErrorsByElement = localExpectedErrorsByElement;

  List<String> get expectedErrors {
    final errors = _errors.toList();
    errors.sort();
    return errors;
  }

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
      final expectedErrors = expectedErrorsFromErrorThrowWithStackTrace(node);
      if (!_isHandledByTryCatch(node, expectedErrors: expectedErrors)) {
        final typeName = typeNameFromErrorThrowWithStackTrace(node);
        if (typeName != null) {
          _errors.add(typeName);
        }
      }
      super.visitMethodInvocation(node);
      return;
    }
    _maybeCollect(node, node.methodName.element);
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    _maybeCollect(node, node.element);
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _maybeCollect(node, node.constructorName.element);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _maybeCollect(node, node.propertyName.element);
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _maybeCollect(node, node.identifier.element);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    if (!_isHandledByTryCatch(node)) {
      final typeName = node.expression.typeName;
      if (typeName != null) {
        _errors.add(typeName);
      }
    }
    super.visitThrowExpression(node);
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    if (!_isHandledByTryCatch(node)) {
      final catchTypeName = node.catchClauseTypeName;
      _errors.add(catchTypeName ?? 'Object');
    }
    super.visitRethrowExpression(node);
  }

  void _maybeCollect(AstNode node, Element? element) {
    final expected = expectedErrorsFromElementOrSdk(element);
    if (expected.isNotEmpty) {
      final unhandled = node.unhandledExpectedErrors(expected.toSet());
      if (unhandled.isEmpty) {
        return;
      }
      _errors.addAll(unhandled);
      return;
    }

    if (_isHandledByTryCatch(node)) {
      return;
    }

    final base = element?.baseElement;
    if (base == null) {
      return;
    }
    final localExpected = _localExpectedErrorsByElement[base];
    if (localExpected == null || localExpected.isEmpty) {
      return;
    }
    final unhandled = node.unhandledExpectedErrors(localExpected.toSet());
    if (unhandled.isEmpty) {
      return;
    }
    _errors.addAll(unhandled);
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
