import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

class AddThrowsAnnotationAssist extends ResolvedCorrectionProducer {
  static const AssistKind _assistKind = AssistKind(
    'throws.assist.addThrowsAnnotation',
    30,
    'Add @throws annotation',
  );

  AddThrowsAnnotationAssist({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _assistKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    try {
      final functionNode = _findEnclosingFunction(node);
      if (functionNode == null) {
        return;
      }

      final metadata = _getMetadata(functionNode);
      if (_hasThrowsAnnotationOnNode(metadata)) {
        return;
      }

      final body = _getFunctionBody(functionNode);
      if (body == null || !_needsThrowsAnnotation(body)) {
        return;
      }

      final offset = _annotationInsertOffset(functionNode, metadata);
      await builder.addDartFileEdit(file, (builder) {
        builder.addInsertion(offset, (builder) {
          builder.write('@throws');
          builder.writeln();
        });
      });
    } catch (_) {
      return;
    }
  }
}

class RemoveThrowsAnnotationAssist extends ResolvedCorrectionProducer {
  static const AssistKind _assistKind = AssistKind(
    'throws.assist.removeThrowsAnnotation',
    30,
    'Remove @Throws annotation',
  );

  RemoveThrowsAnnotationAssist({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _assistKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    try {
      final annotation = _findThrowsAnnotation(node);
      if (annotation == null || annotation.isSynthetic) {
        return;
      }

      await builder.addDartFileEdit(file, (builder) {
        builder.addDeletion(range.node(annotation));
      });
    } catch (_) {
      return;
    }
  }
}

class WrapThrowsCallInTryCatchAssist extends ResolvedCorrectionProducer {
  static const AssistKind _assistKind = AssistKind(
    'throws.assist.wrapTryCatch',
    30,
    'Wrap in try/catch',
  );

  WrapThrowsCallInTryCatchAssist({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _assistKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    try {
      final statement = _findEnclosingStatement(node);
      if (statement == null || statement.isSynthetic) {
        return;
      }
      if (_isWithinTryStatement(statement)) {
        return;
      }

      final expression = _statementExpression(statement);
      if (expression == null) {
        return;
      }

      final expectedErrors = _expressionExpectedErrors(expression, unit);
      if (expectedErrors == null) {
        return;
      }

      final statementSource = statement.toSource().trim();
      if (statementSource.isEmpty) {
        return;
      }

      final replacementRange = utils.getLinesRange(range.node(statement));
      final indent = utils.getLinePrefix(replacementRange.offset);
      final errors = expectedErrors.isEmpty ? const ['Object'] : expectedErrors;
      await builder.addDartFileEdit(file, (builder) {
        builder.addReplacement(replacementRange, (builder) {
          builder.writeln('${indent}try {');
          builder.writeln('$indent  $statementSource');
          builder.write('$indent}');
          for (final error in errors) {
            builder.writeln(' on $error catch (e, stackTrace) {');
            builder.writeln('$indent  // TODO: handle error');
            builder.write('$indent}');
          }
          builder.writeln();
        });
      });
    } catch (_) {
      return;
    }
  }
}

AstNode? _findEnclosingFunction(AstNode node) {
  AstNode? current = node;
  while (current != null) {
    if (current is FunctionDeclaration || current is MethodDeclaration) {
      return current;
    }
    current = current.parent;
  }
  return null;
}

Statement? _findEnclosingStatement(AstNode node) {
  AstNode? current = node;
  while (current != null) {
    if (current is ExpressionStatement) {
      return current;
    }

    if (current is ReturnStatement) {
      return current;
    }

    if (current is FunctionDeclaration || current is MethodDeclaration) {
      return null;
    }
    current = current.parent;
  }
  return null;
}

Expression? _statementExpression(Statement statement) {
  if (statement is ExpressionStatement) {
    return statement.expression;
  }
  if (statement is ReturnStatement) {
    return statement.expression;
  }
  return null;
}

bool _isWithinTryStatement(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is TryStatement) {
      return true;
    }
    current = current.parent;
  }
  return false;
}

List<String>? _expressionExpectedErrors(
  Expression expression,
  CompilationUnit unit,
) {
  final finder = _ThrowsInvocationFinder(
    _collectAnnotatedTopLevelFunctions(unit),
  );
  expression.accept(finder);
  return finder.expectedErrors;
}

List<Annotation> _getMetadata(AstNode node) {
  if (node is FunctionDeclaration) {
    return node.metadata;
  }
  if (node is MethodDeclaration) {
    return node.metadata;
  }
  return const [];
}

FunctionBody? _getFunctionBody(AstNode node) {
  if (node is FunctionDeclaration) {
    return node.functionExpression.body;
  }
  if (node is MethodDeclaration) {
    return node.body;
  }
  return null;
}

int _annotationInsertOffset(AstNode node, List<Annotation> metadata) {
  if (metadata.isNotEmpty) {
    return metadata.first.offset;
  }
  if (node is FunctionDeclaration) {
    return node.beginToken.offset;
  }
  if (node is MethodDeclaration) {
    return node.beginToken.offset;
  }
  return node.offset;
}

Annotation? _findThrowsAnnotation(AstNode node) {
  if (node is Annotation) {
    final name = _annotationName(node);
    if (name == 'Throws' || name == 'throws') {
      return node;
    }
  }

  final functionNode = _findEnclosingFunction(node);
  if (functionNode == null) {
    return null;
  }

  for (final annotation in _getMetadata(functionNode)) {
    final name = _annotationName(annotation);
    if (name == 'Throws' || name == 'throws') {
      return annotation;
    }
  }
  return null;
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

bool _needsThrowsAnnotation(FunctionBody body) {
  final visitor = _ThrowsBodyVisitor();
  body.accept(visitor);
  return visitor.hasUnhandledThrow || visitor.hasUnhandledThrowingCall;
}

class _ThrowsBodyVisitor extends RecursiveAstVisitor<void> {
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
    final element = node.methodName.element;
    if (_isThrowsAnnotated(element) && !_isHandledByTryCatch(node)) {
      hasUnhandledThrowingCall = true;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final element = node.element;
    if (_isThrowsAnnotated(element) && !_isHandledByTryCatch(node)) {
      hasUnhandledThrowingCall = true;
    }
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final element = node.constructorName.element;
    if (_isThrowsAnnotated(element) && !_isHandledByTryCatch(node)) {
      hasUnhandledThrowingCall = true;
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

class _ThrowsInvocationFinder extends RecursiveAstVisitor<void> {
  final Map<String, List<String>> _expectedErrorsByName;
  List<String>? expectedErrors;

  _ThrowsInvocationFinder(this._expectedErrorsByName);

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
    final element = node.methodName.element;
    if (_isThrowsAnnotated(element)) {
      expectedErrors ??= _expectedErrorsFromElement(element) ?? const [];
    } else if (_isAnnotatedTopLevelCall(node)) {
      expectedErrors ??=
          _expectedErrorsByName[node.methodName.name] ?? const [];
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    if (_isThrowsAnnotated(node.element)) {
      expectedErrors ??= _expectedErrorsFromElement(node.element) ?? const [];
    }
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_isThrowsAnnotated(node.constructorName.element)) {
      expectedErrors ??=
          _expectedErrorsFromElement(node.constructorName.element) ?? const [];
    }
    super.visitInstanceCreationExpression(node);
  }

  bool _isAnnotatedTopLevelCall(MethodInvocation node) {
    if (node.target != null) {
      return false;
    }
    return _expectedErrorsByName.containsKey(node.methodName.name);
  }
}

Map<String, List<String>> _collectAnnotatedTopLevelFunctions(
  CompilationUnit unit,
) {
  final names = <String, List<String>>{};
  for (final declaration in unit.declarations) {
    if (declaration is FunctionDeclaration) {
      if (_hasThrowsAnnotationOnNode(declaration.metadata)) {
        names[declaration.name.lexeme] = _expectedErrorsFromMetadata(
          declaration.metadata,
        );
      }
    }
  }
  return names;
}

List<String> _expectedErrorsFromMetadata(List<Annotation> metadata) {
  for (final annotation in metadata) {
    final name = _annotationName(annotation);
    if (name == 'Throws' || name == 'throws') {
      return _expectedErrorsFromAnnotation(annotation);
    }
  }
  return const [];
}

List<String> _expectedErrorsFromAnnotation(Annotation annotation) {
  final arguments = annotation.arguments?.arguments;
  if (arguments == null || arguments.length < 2) {
    return const [];
  }

  final expected = arguments[1];
  if (expected is SetOrMapLiteral) {
    return _expectedErrorsFromLiteralElements(expected.elements);
  }
  if (expected is ListLiteral) {
    return _expectedErrorsFromLiteralElements(expected.elements);
  }
  return const [];
}

List<String> _expectedErrorsFromLiteralElements(
  List<CollectionElement> elements,
) {
  final result = <String>[];
  for (final element in elements) {
    if (element is Expression) {
      final typeName = _typeNameFromExpression(element);
      if (typeName != null) {
        result.add(typeName);
      }
    }
  }
  return result;
}

String? _typeNameFromExpression(Expression expression) {
  if (expression is TypeLiteral) {
    return expression.type.toSource();
  }
  if (expression is SimpleIdentifier) {
    return expression.name;
  }
  if (expression is PrefixedIdentifier) {
    return expression.identifier.name;
  }
  return null;
}

List<String>? _expectedErrorsFromElement(Element? element) {
  final executable = element is ExecutableElement ? element : null;
  if (executable == null) {
    return null;
  }

  for (final annotation in executable.metadata.annotations) {
    if (_isThrowsAnnotation(annotation)) {
      final value = annotation.computeConstantValue();
      final expectedField = value?.getField('expectedErrors');
      final values = expectedField?.toSetValue();
      if (values == null) {
        return const [];
      }
      final names = <String>[];
      for (final entry in values) {
        final typeValue = entry.toTypeValue();
        final typeName = typeValue?.getDisplayString(withNullability: false);
        if (typeName != null) {
          names.add(typeName);
        }
      }
      return names;
    }
  }
  return null;
}
