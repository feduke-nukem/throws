import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class DeclarationCollector extends RecursiveAstVisitor<void> {
  final String uri;
  final Map<String, Set<String>> entries = {};
  final List<String> _classStack = [];

  DeclarationCollector(this.uri);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _classStack.add(node.namePart.typeName.lexeme);
    super.visitClassDeclaration(node);
    _classStack.removeLast();
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _classStack.add(node.name.lexeme);
    super.visitMixinDeclaration(node);
    _classStack.removeLast();
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    _classStack.add(node.namePart.typeName.lexeme);
    super.visitEnumDeclaration(node);
    _classStack.removeLast();
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    final name = node.name?.lexeme ?? 'Extension';
    _classStack.add(name);
    super.visitExtensionDeclaration(node);
    _classStack.removeLast();
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final name = node.name.lexeme;
    final errors = _collectErrors(node.functionExpression.body, parent: node);
    _maybeAdd(name, errors);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final name = node.name.lexeme;
    final errors = _collectErrors(node.body, parent: node);
    _maybeAdd(name, errors);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    // ignore: deprecated_member_use
    final typeName = node.typeName?.name ?? node.returnType.name;
    final ctorName = node.name?.lexeme;
    final name = ctorName == null ? typeName : '$typeName.$ctorName';
    final errors = _collectErrors(node.body, parent: node);
    _maybeAdd(name, errors, selfType: typeName, allowObjectFallback: false);
  }

  void _maybeAdd(
    String name,
    _ErrorSummary summary, {
    String? selfType,
    bool allowObjectFallback = true,
  }) {
    if (_isPrivateEntry(name)) {
      return;
    }
    if (!summary.hasThrow && summary.docErrors.isEmpty) {
      return;
    }

    final errors = <String>{};
    errors.addAll(summary.bodyErrors);
    errors.addAll(summary.docErrors);
    if (selfType != null) {
      errors.remove(selfType);
    }
    if (allowObjectFallback && summary.hasThrow && errors.isEmpty) {
      errors.add('Object');
    }

    if (errors.isEmpty) {
      return;
    }

    final key = _buildKey(name);
    entries.putIfAbsent(key, () => <String>{}).addAll(errors);
  }

  String _buildKey(String memberName) {
    if (_classStack.isEmpty) {
      return '$uri.$memberName';
    }
    final className = _classStack.join('.');
    return '$uri.$className.$memberName';
  }

  bool _isPrivateEntry(String memberName) {
    if (uri.startsWith('dart:_')) {
      return true;
    }
    if (_hasPrivatePathSegment(uri)) {
      return true;
    }
    if (_classStack.any((name) => name.startsWith('_'))) {
      return true;
    }
    final parts = memberName.split('.');
    if (parts.any((part) => part.startsWith('_'))) {
      return true;
    }
    return false;
  }

  _ErrorSummary _collectErrors(FunctionBody body, {required AstNode parent}) {
    final throwVisitor = _ThrowCollector();
    body.accept(throwVisitor);

    return _ErrorSummary(
      hasThrow: throwVisitor.hasThrow,
      bodyErrors: throwVisitor.errors,
      docErrors: {..._docErrors(parent), ..._docErrors(body.parent)},
    );
  }

  Set<String> _docErrors(AstNode? node) {
    if (node is AnnotatedNode && node.documentationComment != null) {
      return errorsFromComment(node.documentationComment!);
    }
    return const {};
  }
}

class _ErrorSummary {
  final bool hasThrow;
  final Set<String> bodyErrors;
  final Set<String> docErrors;

  const _ErrorSummary({
    required this.hasThrow,
    required this.bodyErrors,
    required this.docErrors,
  });
}

class _ThrowCollector extends RecursiveAstVisitor<void> {
  bool hasThrow = false;
  final Set<String> errors = {};

  @override
  void visitThrowExpression(ThrowExpression node) {
    hasThrow = true;
    final typeName = typeNameFromExpression(node.expression);

    if (typeName != null) {
      errors.add(typeName);
    }
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    hasThrow = true;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Skip nested functions.
  }
}

String? typeNameFromExpression(Expression expression) {
  switch (expression) {
    case InstanceCreationExpression(:final constructorName):
      return constructorName.type.name.lexeme;
    case TypeLiteral(:final type):
      return type.toSource();
    case SimpleIdentifier(:final name):
      return name;
    case PrefixedIdentifier(:final identifier):
      return identifier.name;
  }

  final typeName = expression.staticType?.getDisplayString();
  if (typeName == null || typeName == 'InvalidType') {
    return null;
  }
  return typeName;
}

Set<String> errorsFromComment(Comment comment) {
  final documentation = documentationCommentsParser(comment.tokens).join('\n');
  final regex = RegExp(r'\b([A-Z][A-Za-z0-9_]*(?:Exception|Error))\b');
  final matches = regex.allMatches(documentation);
  final result = <String>{};
  for (final match in matches) {
    final name = match.group(1);
    if (name != null) {
      result.add(name);
    }
  }
  return result;
}

List<String> documentationCommentsParser(List<Token>? comments) {
  const docCommentPrefix = '///';
  return comments
          ?.map(
            (Token line) => line.length > docCommentPrefix.length
                ? line.toString().substring(docCommentPrefix.length)
                : '',
          )
          .toList() ??
      <String>[];
}

bool _hasPrivatePathSegment(String uri) {
  final schemeIndex = uri.indexOf(':');
  final path = schemeIndex == -1 ? uri : uri.substring(schemeIndex + 1);
  for (final segment in path.split('/')) {
    if (segment.startsWith('_')) {
      return true;
    }
  }
  return false;
}
