import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

class ThrowFinder extends RecursiveAstVisitor<void> {
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
  void visitMethodInvocation(MethodInvocation node) {
    if (_isErrorThrowWithStackTrace(node)) {
      foundThrow = true;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Ignore nested functions.
  }
}

bool _isErrorThrowWithStackTrace(MethodInvocation node) {
  if (node.methodName.name != 'throwWithStackTrace') {
    return false;
  }

  final element = node.methodName.element;
  if (element is ExecutableElement) {
    final enclosing = element.enclosingElement;
    if (enclosing is InterfaceElement && enclosing.name == 'Error') {
      return true;
    }
  }

  final target = node.target;
  if (target is Identifier && target.name == 'Error') {
    return true;
  }

  return false;
}
