import 'package:analyzer/dart/ast/ast.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/utils/extensions/annotation_x.dart';
import 'package:throws_plugin/src/utils/extensions/try_statement_x.dart';
import 'package:throws_plugin/src/utils/extensions/type_annotation_x.dart';

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

  bool get isWithinTryWithCatch {
    AstNode? current = parent;
    while (current != null) {
      if (current is TryStatement) {
        if (current.catchClauses.isNotEmpty && isWithin(current.body)) {
          return true;
        }
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

  FunctionBody? get functionBody => switch (this) {
    FunctionDeclaration(:final functionExpression) => functionExpression.body,
    MethodDeclaration(:final body) => body,
    ConstructorDeclaration(:final body) => body,
    _ => null,
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
      final name = node.maybeVerifiedName;
      if (name == ThrowsAnnotation.nameCapitalized ||
          name == ThrowsAnnotation.name) {
        return node;
      }
    }

    final functionNode = node.enclosingFunction;
    if (functionNode == null) {
      return null;
    }

    for (final annotation in functionNode.metadata) {
      final name = annotation.maybeVerifiedName;
      if (name == ThrowsAnnotation.nameCapitalized ||
          name == ThrowsAnnotation.name) {
        return annotation;
      }
    }
    return null;
  }

  bool isHandledByTryCatch([Set<String>? expectedErrors]) {
    final node = this;
    AstNode? current = node.parent;
    while (current != null) {
      if (current is TryStatement) {
        if (isWithin(current.body)) {
          if (expectedErrors == null || expectedErrors.isEmpty) {
            if (current.providesHandling) {
              return true;
            }
          } else if (current.catchesAllExpected(expectedErrors)) {
            return true;
          }
        }
      }
      current = current.parent;
    }
    return false;
  }

  Set<String> unhandledExpectedErrors(Set<String> expectedErrors) {
    if (expectedErrors.isEmpty) {
      return const {};
    }

    final remaining = expectedErrors.toSet();
    AstNode? current = parent;

    while (current != null) {
      if (current is TryStatement && isWithin(current.body)) {
        final handled = current.handledErrors(remaining);
        remaining.removeAll(handled);
        if (remaining.isEmpty) {
          return remaining;
        }
      }
      current = current.parent;
    }

    return remaining;
  }

  bool isWithin(AstNode container) {
    return offset >= container.offset && end <= container.end;
  }

  String? get catchClauseTypeName {
    AstNode? current = parent;
    while (current != null) {
      if (current is CatchClause) {
        return current.exceptionType?.typeName;
      }
      current = current.parent;
    }
    return null;
  }
}
