import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';
import 'package:throws_plugin/src/analyzer/sdk_throws_map.dart';

part 'assists/add_throws_annotation_assist.dart';
part 'assists/remove_throws_annotation_assist.dart';
part 'assists/update_throws_annotation_assist.dart';
part 'assists/wrap_throws_call_in_try_catch_assist.dart';

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

    if (current is VariableDeclarationStatement) {
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
  if (statement is VariableDeclarationStatement) {
    final declarations = statement.variables.variables;
    if (declarations.length != 1) {
      return null;
    }
    return declarations.first.initializer;
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
  final localInfo = _collectLocalThrowingInfo(unit);
  final finder = _ThrowsInvocationFinder(
    _collectAnnotatedTopLevelFunctions(unit),
    localInfo.elements,
    localInfo.expectedErrorsByElement,
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

bool _isThrowsAnnotatedOrSdk(Element? element) {
  final executable = element is ExecutableElement ? element : null;
  if (executable == null) {
    return false;
  }

  if (executable.metadata.annotations.any(_isThrowsAnnotation)) {
    return true;
  }

  return isSdkThrowingElement(executable);
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

List<String> _collectExpectedErrors(
  FunctionBody body, {
  required Map<Element, List<String>> localExpectedErrorsByElement,
}) {
  final collector = _ThrowsExpectedErrorsCollector(
    localExpectedErrorsByElement: localExpectedErrorsByElement,
  );
  body.accept(collector);
  return collector.expectedErrors;
}

class _ThrowsExpectedErrorsCollector extends RecursiveAstVisitor<void> {
  final Set<String> _errors = {};
  final Map<Element, List<String>> _localExpectedErrorsByElement;

  _ThrowsExpectedErrorsCollector({
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
    if (_isErrorThrowWithStackTrace(node)) {
      final expectedErrors = _expectedErrorsFromErrorThrowWithStackTrace(node);
      if (!_isHandledByTryCatch(node, expectedErrors: expectedErrors)) {
        final typeName = _typeNameFromErrorThrowWithStackTrace(node);
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
      final typeName = _typeNameFromExpression(node.expression);
      if (typeName != null) {
        _errors.add(typeName);
      }
    }
    super.visitThrowExpression(node);
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    if (!_isHandledByTryCatch(node)) {
      final catchTypeName = _catchClauseTypeName(node);
      _errors.add(catchTypeName ?? 'Object');
    }
    super.visitRethrowExpression(node);
  }

  void _maybeCollect(AstNode node, Element? element) {
    final expected = _expectedErrorsFromElementOrSdk(element);
    if (expected != null && expected.isNotEmpty) {
      if (_isHandledByTryCatch(node, expectedErrors: expected.toSet())) {
        return;
      }
      _errors.addAll(expected);
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
    if (_isHandledByTryCatch(node, expectedErrors: localExpected.toSet())) {
      return;
    }
    _errors.addAll(localExpected);
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
      final typeName = _typeNameFromTypeAnnotation(clause.exceptionType);
      if (typeName == null) {
        return true;
      }
      if (_isCatchAllType(typeName)) {
        return true;
      }

      covered.add(typeName);
    }

    return expectedErrors.every(covered.contains);
  }

  bool _catchAlwaysRethrows(CatchClause clause) {
    final visitor = _ThrowFinder();
    clause.body.accept(visitor);
    return visitor.foundThrow;
  }
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
    if (_isErrorThrowWithStackTrace(node)) {
      final expectedErrors = _expectedErrorsFromErrorThrowWithStackTrace(node);
      if (!_isHandledByTryCatch(node, expectedErrors: expectedErrors)) {
        hasUnhandledThrow = true;
      }
      super.visitMethodInvocation(node);
      return;
    }
    final element = node.methodName.element;
    final expected = _expectedErrorsFromElementOrSdk(element);
    if (_isThrowsAnnotatedOrSdk(element) &&
        !_isHandledByTryCatch(
          node,
          expectedErrors: expected?.toSet(),
        )) {
      hasUnhandledThrowingCall = true;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final element = node.element;
    final expected = _expectedErrorsFromElementOrSdk(element);
    if (_isThrowsAnnotatedOrSdk(element) &&
        !_isHandledByTryCatch(
          node,
          expectedErrors: expected?.toSet(),
        )) {
      hasUnhandledThrowingCall = true;
    }
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final element = node.constructorName.element;
    final expected = _expectedErrorsFromElementOrSdk(element);
    if (_isThrowsAnnotatedOrSdk(element) &&
        !_isHandledByTryCatch(
          node,
          expectedErrors: expected?.toSet(),
        )) {
      hasUnhandledThrowingCall = true;
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final element = node.propertyName.element;
    final expected = _expectedErrorsFromElementOrSdk(element);
    if (_isThrowsAnnotatedOrSdk(element) &&
        !_isHandledByTryCatch(
          node,
          expectedErrors: expected?.toSet(),
        )) {
      hasUnhandledThrowingCall = true;
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final element = node.identifier.element;
    final expected = _expectedErrorsFromElementOrSdk(element);
    if (_isThrowsAnnotatedOrSdk(element) &&
        !_isHandledByTryCatch(
          node,
          expectedErrors: expected?.toSet(),
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
      if (_catchAlwaysRethrows(clause)) {
        continue;
      }

      final typeName = _typeNameFromTypeAnnotation(clause.exceptionType);
      if (typeName == null) {
        return true;
      }
      if (_isCatchAllType(typeName)) {
        return true;
      }

      covered.add(typeName);
    }

    return expectedErrors.every(covered.contains);
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

class _ThrowsInvocationFinder extends RecursiveAstVisitor<void> {
  final Map<String, List<String>> _expectedErrorsByName;
  final Set<Element> _localThrowingElements;
  final Map<Element, List<String>> _localExpectedErrorsByElement;
  List<String>? expectedErrors;

  _ThrowsInvocationFinder(
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
    if (_isErrorThrowWithStackTrace(node)) {
      final typeName = _typeNameFromErrorThrowWithStackTrace(node);
      expectedErrors ??= typeName == null ? const [] : [typeName];
      super.visitMethodInvocation(node);
      return;
    }
    final element = node.methodName.element;
    final expected = _expectedErrorsFromElementOrSdk(element);
    if (expected != null) {
      expectedErrors ??= expected;
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
    final expected = _expectedErrorsFromElementOrSdk(node.element);
    if (expected != null) {
      expectedErrors ??= expected;
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
    final expected = _expectedErrorsFromElementOrSdk(
      node.constructorName.element,
    );
    if (expected != null) {
      expectedErrors ??= expected;
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
    final expected = _expectedErrorsFromElementOrSdk(node.propertyName.element);
    if (expected != null) {
      expectedErrors ??= expected;
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
    final expected = _expectedErrorsFromElementOrSdk(node.identifier.element);
    if (expected != null) {
      expectedErrors ??= expected;
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

class _LocalThrowingInfo {
  final Set<Element> elements;
  final Map<Element, List<String>> expectedErrorsByElement;

  _LocalThrowingInfo(this.elements, this.expectedErrorsByElement);
}

_LocalThrowingInfo _collectLocalThrowingInfo(CompilationUnit unit) {
  final elements = <Element>{};
  final expectedErrorsByElement = <Element, List<String>>{};
  for (final declaration in unit.declarations) {
    if (declaration is FunctionDeclaration) {
      final body = declaration.functionExpression.body;
      final visitor = _ThrowsBodyVisitor();
      body.accept(visitor);
      if (visitor.hasUnhandledThrow || visitor.hasUnhandledThrowingCall) {
        final element = declaration.declaredFragment?.element;
        if (element != null) {
          final base = element.baseElement;
          elements.add(base);
          final expected = _collectExpectedErrors(
            body,
            localExpectedErrorsByElement: const {},
          );
          expectedErrorsByElement[base] = expected;
        }
      }
    } else if (declaration is ClassDeclaration) {
      for (final member in declaration.members) {
        if (member is MethodDeclaration) {
          final visitor = _ThrowsBodyVisitor();
          member.body.accept(visitor);
          if (visitor.hasUnhandledThrow || visitor.hasUnhandledThrowingCall) {
            final element = member.declaredFragment?.element;
            if (element != null) {
              final base = element.baseElement;
              elements.add(base);
              final expected = _collectExpectedErrors(
                member.body,
                localExpectedErrorsByElement: const {},
              );
              expectedErrorsByElement[base] = expected;
            }
          }
        }
      }
    }
  }
  return _LocalThrowingInfo(elements, expectedErrorsByElement);
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
    final element = expression.element;
    if (element is ClassElement ||
        element is TypeAliasElement ||
        element is EnumElement ||
        element is ExtensionTypeElement) {
      return expression.name;
    }
  }
  if (expression is PrefixedIdentifier) {
    final element = expression.identifier.element;
    if (element is ClassElement ||
        element is TypeAliasElement ||
        element is EnumElement ||
        element is ExtensionTypeElement) {
      return expression.identifier.name;
    }
  }
  final staticType = expression.staticType;
  final staticName = staticType?.getDisplayString(withNullability: false);
  if (staticName != null && staticName != 'dynamic') {
    return staticName;
  }
  if (expression is SimpleIdentifier) {
    return expression.name;
  }
  if (expression is PrefixedIdentifier) {
    return expression.identifier.name;
  }
  return null;
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

String? _typeNameFromErrorThrowWithStackTrace(MethodInvocation node) {
  final args = node.argumentList.arguments;
  if (args.isEmpty) {
    return null;
  }
  return _typeNameFromExpression(args.first);
}

Set<String> _expectedErrorsFromErrorThrowWithStackTrace(MethodInvocation node) {
  final typeName = _typeNameFromErrorThrowWithStackTrace(node);
  if (typeName == null) {
    return const {};
  }
  return {typeName};
}

String? _typeNameFromTypeAnnotation(TypeAnnotation? annotation) {
  if (annotation == null) {
    return null;
  }
  final type = annotation.type;
  if (type != null) {
    return type.getDisplayString(withNullability: false);
  }
  return annotation.toSource();
}

bool _isCatchAllType(String typeName) {
  return typeName == 'Object' || typeName == 'dynamic';
}

String? _catchClauseTypeName(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is CatchClause) {
      return _typeNameFromTypeAnnotation(current.exceptionType);
    }
    current = current.parent;
  }
  return null;
}

List<String>? _expectedErrorsFromElementOrSdk(Element? element) {
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

  return sdkThrowsForElement(executable);
}
