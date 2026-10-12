import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

class DeclarationCollector extends RecursiveAstVisitor<void> {
  final String uri;

  /// Errors per member path (`Class.member`, `Class.new` or `function`).
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
    final typeName = node.declaredFragment?.element.enclosingElement.name;
    if (typeName == null) {
      return;
    }
    final name = node.name?.lexeme ?? 'new';
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
      return memberName;
    }
    return '${_classStack.join('.')}.$memberName';
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
  }

  final typeName = expression.staticType?.getDisplayString();
  if (typeName == null || typeName == 'InvalidType') {
    return null;
  }
  return typeName;
}

// "throws", "is thrown", "completes (the future) with", "fails with".
final _throwWord = RegExp(
  r'\bthrow|\bcomplet\w*\s+(?:the\s+(?:returned\s+)?future\s+)?with|\bfail\w*\s+with',
  caseSensitive: false,
);
final _sentenceEnd = RegExp(r'[.!?](?=\s|$)|\n\s*\n');

/// Error classes referenced as `[Name]` in sentences of [comment] that
/// mention throwing, e.g. "Throws a [StateError] if empty" or "completes the
/// future with a [FileSystemException]".
///
/// Only references the analyzer resolves to subtypes of `Error` or
/// `Exception` count, so names in examples and prose are ignored.
Set<String> errorsFromComment(Comment comment) {
  final result = <String>{};
  for (final reference in comment.references) {
    final expression = reference.expression;
    final element = expression is Identifier ? expression.element : null;
    if (element is! InterfaceElement || !_isErrorOrException(element)) {
      continue;
    }
    final sentence = _sentenceAround(comment, reference.offset);
    if (sentence != null && _throwWord.hasMatch(sentence)) {
      result.add(element.name!);
    }
  }
  return result;
}

bool _isErrorOrException(InterfaceElement element) {
  bool isRoot(InterfaceType type) =>
      type.element.library.isDartCore &&
      (type.element.name == 'Error' || type.element.name == 'Exception');
  return isRoot(element.thisType) || element.allSupertypes.any(isRoot);
}

/// The sentence of [comment] containing the source [offset].
String? _sentenceAround(Comment comment, int offset) {
  final text = StringBuffer();
  int? position;
  for (final token in comment.tokens) {
    final line = token.lexeme.startsWith('///')
        ? token.lexeme.substring(3)
        : token.lexeme;
    if (offset >= token.offset && offset < token.end) {
      position =
          text.length +
          offset -
          token.offset -
          (token.lexeme.length - line.length);
    }
    text
      ..write(line)
      ..write('\n');
  }
  if (position == null) {
    return null;
  }
  final content = text.toString();
  var start = 0;
  var end = content.length;
  for (final match in _sentenceEnd.allMatches(content)) {
    if (match.end <= position) {
      start = match.end;
    } else if (match.start >= position) {
      end = match.start;
      break;
    }
  }
  return content.substring(start, end);
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
