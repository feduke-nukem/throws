import 'package:analyzer/dart/ast/ast.dart';
import 'package:throws_plugin/src/helpers.dart' as helpers;

extension AstNodeX on AstNode {
  AstNode? get enclosingFunction {
    AstNode? current = this;
    while (current != null) {
      if (current is FunctionDeclaration ||
          current is MethodDeclaration ||
          current is ConstructorDeclaration) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }

  Statement? get enclosingStatement {
    AstNode? current = this;
    while (current != null) {
      if (current is ExpressionStatement) {
        return current;
      }

      if (current is ReturnStatement) {
        return current;
      }

      if (current is VariableDeclarationStatement) {
        return current;
      }

      if (current is FunctionDeclaration ||
          current is MethodDeclaration ||
          current is ConstructorDeclaration) {
        return null;
      }
      current = current.parent;
    }
    return null;
  }

  bool get isWithinTryStatement {
    AstNode? current = parent;
    while (current != null) {
      if (current is TryStatement) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  List<Annotation> get metadata => switch (this) {
    FunctionDeclaration(:final metadata) => metadata,
    MethodDeclaration(:final metadata) => metadata,
    ConstructorDeclaration(:final metadata) => metadata,
    _ => const [],
  };

  int insertOffset(List<Annotation> metadata) => switch (this) {
    FunctionDeclaration() when metadata.isNotEmpty => metadata.first.offset,
    MethodDeclaration() when metadata.isNotEmpty => metadata.first.offset,
    ConstructorDeclaration() when metadata.isNotEmpty => metadata.first.offset,
    FunctionDeclaration(:final documentationComment)
        when documentationComment != null =>
      documentationComment.endToken.next?.offset ??
          documentationComment.end + 1,
    MethodDeclaration(:final documentationComment)
        when documentationComment != null =>
      documentationComment.endToken.next?.offset ??
          documentationComment.end + 1,
    ConstructorDeclaration(:final documentationComment)
        when documentationComment != null =>
      documentationComment.endToken.next?.offset ??
          documentationComment.end + 1,
    FunctionDeclaration(:var beginToken) => beginToken.offset,
    MethodDeclaration(:var beginToken) => beginToken.offset,
    ConstructorDeclaration(:var beginToken) => beginToken.offset,
    _ when metadata.isNotEmpty => metadata.first.offset,
    _ => offset,
  };

  Annotation? findThrowsAnnotation() {
    final node = this;
    if (node is Annotation) {
      final match = helpers.findThrowsAnnotation([node]);
      if (match != null) {
        return match;
      }
    }
    final functionNode = node.enclosingFunction;
    if (functionNode == null) {
      return null;
    }
    return helpers.findThrowsAnnotation(functionNode.metadata);
  }
}
