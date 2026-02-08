import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:throws_plugin/src/analyzer/sdk_throws_map.dart';

part 'rules/introduced_throws_in_override_rule.dart';
part 'rules/missing_error_handling_rule.dart';
part 'rules/missing_throws_annotation_rule.dart';
part 'rules/throws_annotation_mismatch_rule.dart';
part 'rules/unused_throws_annotation_rule.dart';

final List<AnalysisRule> throwsLintRules = [
  MissingThrowsAnnotationRule(),
  MissingErrorHandlingRule(),
  ThrowsAnnotationMismatchRule(),
  IntroducedThrowsInOverrideRule(),
  UnusedThrowsAnnotationRule(),
];

enum _ThrowsRuleKind {
  missingThrowsAnnotation,
  missingErrorHandling,
  throwsAnnotationMismatch,
  introducedThrowsInOverride,
  unusedThrowsAnnotation,
}

class _ThrowsCompilationUnitVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule _rule;
  final _ThrowsRuleKind _kind;

  _ThrowsCompilationUnitVisitor(this._rule, this._kind);

  @override
  void visitCompilationUnit(CompilationUnit node) {
    final summaries = _ThrowsAnalyzer().analyze(node);

    for (final summary in summaries) {
      switch (_kind) {
        case _ThrowsRuleKind.missingThrowsAnnotation:
          if (!summary.hasThrowsAnnotation && summary.hasUnhandledThrow) {
            if (!_hasAnnotatedSuper(summary) &&
                !_isCoveredByInheritedThrows(summary)) {
              _rule.reportAtToken(summary.nameToken);
            }
          }
          break;
        case _ThrowsRuleKind.missingErrorHandling:
          if (!summary.hasThrowsAnnotation &&
              summary.unhandledThrowingCallNodes.isNotEmpty) {
            if (!_isCoveredByInheritedThrows(summary)) {
              for (final node in summary.unhandledThrowingCallNodes) {
                _rule.reportAtNode(node);
              }
            }
          }
          break;
        case _ThrowsRuleKind.throwsAnnotationMismatch:
          if (summary.hasThrowsAnnotation &&
              !summary.allowAnyExpectedErrors &&
              summary.thrownErrors.isNotEmpty &&
              !_matchesAnnotation(summary)) {
            _rule.reportAtToken(summary.nameToken);
          }
          break;
        case _ThrowsRuleKind.introducedThrowsInOverride:
          if (!summary.hasThrowsAnnotation &&
              (summary.hasUnhandledThrow || summary.hasUnhandledThrowingCall) &&
              _introducesNewErrors(summary)) {
            _rule.reportAtToken(summary.nameToken);
          }
          break;
        case _ThrowsRuleKind.unusedThrowsAnnotation:
          if (summary.hasThrowsAnnotation &&
              !summary.hasUnhandledThrow &&
              !summary.hasUnhandledThrowingCall &&
              !summary.isAbstractOrExternal) {
            _rule.reportAtToken(summary.nameToken);
          }
          break;
      }
    }
  }
}

class _ThrowsAnalyzer {
  List<_FunctionSummary> analyze(CompilationUnit unit) {
    final collector = _FunctionCollector();
    unit.accept(collector);

    for (final summary in collector.summaries) {
      final visitor = _FunctionBodyVisitor(
        summary,
        includeAnnotatedAndSdk: true,
        localThrowingElements: const {},
      );
      summary.body.accept(visitor);
    }

    final localThrowingElements = <Element>{};
    collector.summaryByElement.forEach((element, summary) {
      if (summary.hasUnhandledThrow || summary.hasUnhandledThrowingCall) {
        localThrowingElements.add(element);
      }
    });

    if (localThrowingElements.isNotEmpty) {
      for (final summary in collector.summaries) {
        final visitor = _FunctionBodyVisitor(
          summary,
          includeAnnotatedAndSdk: false,
          localThrowingElements: localThrowingElements,
        );
        summary.body.accept(visitor);
      }
    }

    return collector.summaries;
  }
}

class _FunctionCollector extends RecursiveAstVisitor<void> {
  final List<_FunctionSummary> summaries = [];
  final Map<Element, _FunctionSummary> summaryByElement = {};

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final expectedErrors = _expectedErrorsFromMetadata(node.metadata).toSet();
    final summary = _FunctionSummary(
      nameToken: node.name,
      body: node.functionExpression.body,
      hasThrowsAnnotation: _hasThrowsAnnotationOnNode(node.metadata),
      annotatedExpectedErrors: expectedErrors,
      allowAnyExpectedErrors:
          _hasThrowsAnnotationOnNode(node.metadata) && expectedErrors.isEmpty,
      isAbstractOrExternal: _isAbstractOrExternalBody(
        node.functionExpression.body,
        node.externalKeyword,
      ),
    );
    summary.element = node.declaredFragment?.element.baseElement;
    summaries.add(summary);
    final element = node.declaredFragment?.element;
    if (element != null) {
      summaryByElement[element.baseElement] = summary;
    }
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final expectedErrors = _expectedErrorsFromMetadata(node.metadata).toSet();
    final summary = _FunctionSummary(
      nameToken: node.name,
      body: node.body,
      hasThrowsAnnotation: _hasThrowsAnnotationOnNode(node.metadata),
      annotatedExpectedErrors: expectedErrors,
      allowAnyExpectedErrors:
          _hasThrowsAnnotationOnNode(node.metadata) && expectedErrors.isEmpty,
      isAbstractOrExternal:
          node.isAbstract ||
          _isAbstractOrExternalBody(node.body, node.externalKeyword),
    );
    summary.element = node.declaredFragment?.element.baseElement;
    summaries.add(summary);
    final element = node.declaredFragment?.element;
    if (element != null) {
      summaryByElement[element.baseElement] = summary;
    }
    super.visitMethodDeclaration(node);
  }
}

class _FunctionSummary {
  final Token nameToken;
  final FunctionBody body;
  final bool hasThrowsAnnotation;
  final Set<String> annotatedExpectedErrors;
  final bool allowAnyExpectedErrors;
  final bool isAbstractOrExternal;
  final Set<String> thrownErrors = {};
  Element? element;
  bool hasUnhandledThrow = false;
  bool hasUnhandledThrowingCall = false;
  final List<AstNode> unhandledThrowingCallNodes = [];

  _FunctionSummary({
    required this.nameToken,
    required this.body,
    required this.hasThrowsAnnotation,
    required this.annotatedExpectedErrors,
    required this.allowAnyExpectedErrors,
    required this.isAbstractOrExternal,
  });
}

bool _matchesAnnotation(_FunctionSummary summary) {
  if (!summary.hasThrowsAnnotation) {
    return true;
  }
  if (summary.allowAnyExpectedErrors) {
    return true;
  }
  final actual = summary.thrownErrors.toSet();
  final expected = summary.annotatedExpectedErrors;
  return actual.length == expected.length && actual.every(expected.contains);
}

class _FunctionBodyVisitor extends RecursiveAstVisitor<void> {
  final _FunctionSummary _summary;
  final bool _includeAnnotatedAndSdk;
  final Set<Element> _localThrowingElements;

  _FunctionBodyVisitor(
    this._summary, {
    required bool includeAnnotatedAndSdk,
    required Set<Element> localThrowingElements,
  }) : _includeAnnotatedAndSdk = includeAnnotatedAndSdk,
       _localThrowingElements = localThrowingElements;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Skip nested functions/closures when analyzing the outer function.
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    // Skip nested methods when analyzing the outer function.
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // Skip nested functions when analyzing the outer function.
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    if (!_isHandledByTryCatch(node)) {
      _summary.hasUnhandledThrow = true;
      final typeName = _typeNameFromExpression(node.expression);
      if (typeName != null) {
        _summary.thrownErrors.add(typeName);
      }
    }
    super.visitThrowExpression(node);
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    if (!_isHandledByTryCatch(node)) {
      _summary.hasUnhandledThrow = true;
      final catchTypeName = _catchClauseTypeName(node);
      _summary.thrownErrors.add(catchTypeName ?? 'Object');
    }
    super.visitRethrowExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isErrorThrowWithStackTrace(node)) {
      final expectedErrors = _expectedErrorsFromErrorThrowWithStackTrace(node);
      if (!_isHandledByTryCatch(node, expectedErrors: expectedErrors)) {
        _summary.hasUnhandledThrow = true;
        final typeName = _typeNameFromErrorThrowWithStackTrace(node);
        if (typeName != null) {
          _summary.thrownErrors.add(typeName);
        }
      }
      super.visitMethodInvocation(node);
      return;
    }
    final element = node.methodName.element;
    if (_includeAnnotatedAndSdk &&
        _isThrowsAnnotatedOrSdk(element) &&
        !_isHandledByTryCatch(
          node,
          expectedErrors: _expectedErrorsFromElementOrSdk(element),
        )) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node.methodName);
      _summary.thrownErrors.addAll(_expectedErrorsFromElementOrSdk(element));
    }
    if (_isLocalThrowingElement(element) && !_isHandledByTryCatch(node)) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node.methodName);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final element = node.element;
    if (_includeAnnotatedAndSdk &&
        _isThrowsAnnotatedOrSdk(element) &&
        !_isHandledByTryCatch(
          node,
          expectedErrors: _expectedErrorsFromElementOrSdk(element),
        )) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node);
      _summary.thrownErrors.addAll(_expectedErrorsFromElementOrSdk(element));
    }
    if (_isLocalThrowingElement(element) && !_isHandledByTryCatch(node)) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node);
    }
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final element = node.constructorName.element;
    if (_includeAnnotatedAndSdk &&
        _isThrowsAnnotatedOrSdk(element) &&
        !_isHandledByTryCatch(
          node,
          expectedErrors: _expectedErrorsFromElementOrSdk(element),
        )) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node.constructorName);
      _summary.thrownErrors.addAll(_expectedErrorsFromElementOrSdk(element));
    }
    if (_isLocalThrowingElement(element) && !_isHandledByTryCatch(node)) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node.constructorName);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final element = node.propertyName.element;
    if (_includeAnnotatedAndSdk &&
        _isThrowsAnnotatedOrSdk(element) &&
        !_isHandledByTryCatch(
          node,
          expectedErrors: _expectedErrorsFromElementOrSdk(element),
        )) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node.propertyName);
      _summary.thrownErrors.addAll(_expectedErrorsFromElementOrSdk(element));
    }
    if (_isLocalThrowingElement(element) && !_isHandledByTryCatch(node)) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node.propertyName);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final element = node.identifier.element;
    if (_includeAnnotatedAndSdk &&
        _isThrowsAnnotatedOrSdk(element) &&
        !_isHandledByTryCatch(
          node,
          expectedErrors: _expectedErrorsFromElementOrSdk(element),
        )) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node.identifier);
      _summary.thrownErrors.addAll(_expectedErrorsFromElementOrSdk(element));
    }
    if (_isLocalThrowingElement(element) && !_isHandledByTryCatch(node)) {
      _summary.hasUnhandledThrowingCall = true;
      _summary.unhandledThrowingCallNodes.add(node.identifier);
    }
    super.visitPrefixedIdentifier(node);
  }

  bool _isLocalThrowingElement(Element? element) {
    if (element == null) {
      return false;
    }
    if (_localThrowingElements.isEmpty) {
      return false;
    }
    return _localThrowingElements.contains(element.baseElement);
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

bool _isAbstractOrExternalBody(FunctionBody body, Token? externalKeyword) {
  if (externalKeyword != null) {
    return true;
  }
  return body is EmptyFunctionBody;
}

bool _hasAnnotatedSuper(_FunctionSummary summary) {
  final element = summary.element;
  if (element is! ExecutableElement) {
    return false;
  }
  final info = _collectInheritedThrowsInfo(element);
  if (info.hasAnnotatedSuper) {
    return true;
  }
  return _findUnitOverrideInfo(summary).hasAnnotatedSuper;
}

bool _isCoveredByInheritedThrows(_FunctionSummary summary) {
  final element = summary.element;
  if (element is! ExecutableElement) {
    return false;
  }

  var info = _collectInheritedThrowsInfo(element);
  if (!info.hasAnnotatedSuper) {
    info = _findUnitOverrideInfo(summary);
    if (!info.hasAnnotatedSuper) {
      return false;
    }
  }
  if (info.allowAny) {
    return true;
  }
  if (summary.thrownErrors.isEmpty) {
    return false;
  }

  return summary.thrownErrors.every(info.expectedErrors.contains);
}

bool _introducesNewErrors(_FunctionSummary summary) {
  final element = summary.element;
  if (element is! ExecutableElement) {
    return false;
  }

  var info = _collectInheritedThrowsInfo(element);
  if (!info.hasAnnotatedSuper || info.allowAny) {
    info = _findUnitOverrideInfo(summary);
    if (!info.hasAnnotatedSuper || info.allowAny) {
      return false;
    }
  }
  if (summary.thrownErrors.isEmpty) {
    return false;
  }

  return summary.thrownErrors.any(
    (error) => !info.expectedErrors.contains(error),
  );
}

class _InheritedThrowsInfo {
  final bool hasAnnotatedSuper;
  final bool allowAny;
  final Set<String> expectedErrors;

  const _InheritedThrowsInfo({
    required this.hasAnnotatedSuper,
    required this.allowAny,
    required this.expectedErrors,
  });
}

_InheritedThrowsInfo _findUnitOverrideInfo(_FunctionSummary summary) {
  final element = summary.element;
  if (element is! ExecutableElement) {
    return const _InheritedThrowsInfo(
      hasAnnotatedSuper: false,
      allowAny: false,
      expectedErrors: {},
    );
  }

  final session = element.session;
  final library = element.library;
  if (session == null) {
    return const _InheritedThrowsInfo(
      hasAnnotatedSuper: false,
      allowAny: false,
      expectedErrors: {},
    );
  }

  final parsed = session.getParsedLibraryByElement(library);
  if (parsed is! ParsedLibraryResult) {
    return const _InheritedThrowsInfo(
      hasAnnotatedSuper: false,
      allowAny: false,
      expectedErrors: {},
    );
  }

  final collector = _OverrideInfoCollector(summary.nameToken.lexeme);
  for (final unit in parsed.units) {
    unit.unit.accept(collector);
    if (collector.result.hasAnnotatedSuper) {
      break;
    }
  }
  return collector.result;
}

class _OverrideInfoCollector extends RecursiveAstVisitor<void> {
  final String _memberName;
  _InheritedThrowsInfo _result = const _InheritedThrowsInfo(
    hasAnnotatedSuper: false,
    allowAny: false,
    expectedErrors: {},
  );

  _OverrideInfoCollector(this._memberName);

  _InheritedThrowsInfo get result => _result;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        if (member.name.lexeme == _memberName &&
            _hasThrowsAnnotationOnNode(member.metadata) &&
            member.body is EmptyFunctionBody) {
          final errors = _expectedErrorsFromMetadata(member.metadata);
          if (errors.isEmpty) {
            _result = const _InheritedThrowsInfo(
              hasAnnotatedSuper: true,
              allowAny: true,
              expectedErrors: {},
            );
          } else {
            _result = _InheritedThrowsInfo(
              hasAnnotatedSuper: true,
              allowAny: false,
              expectedErrors: errors.toSet(),
            );
          }
        }
      }
    }
    super.visitClassDeclaration(node);
  }
}

_InheritedThrowsInfo _collectInheritedThrowsInfo(ExecutableElement element) {
  final enclosing = element.enclosingElement;
  if (enclosing is! InterfaceElement) {
    return const _InheritedThrowsInfo(
      hasAnnotatedSuper: false,
      allowAny: false,
      expectedErrors: {},
    );
  }

  final name = element.displayName;
  final expectedErrors = <String>{};
  var hasAnnotatedSuper = false;
  var allowAny = false;

  final candidates = <ExecutableElement>{};
  if (element is MethodElement) {
    final nameObj = Name.forLibrary(element.library, element.name ?? name);
    candidates.addAll(enclosing.getOverridden(nameObj) ?? const []);
  } else if (element is PropertyAccessorElement) {
    final nameObj = Name.forLibrary(element.library, element.name ?? name);
    candidates.addAll(enclosing.getOverridden(nameObj) ?? const []);
    candidates.addAll(enclosing.getOverridden(nameObj.forGetter) ?? const []);
    candidates.addAll(enclosing.getOverridden(nameObj.forSetter) ?? const []);
  }

  final types = <InterfaceType>{};
  types.addAll(enclosing.allSupertypes);
  types.addAll(enclosing.interfaces);
  if (enclosing.supertype != null) {
    types.add(enclosing.supertype!);
  }
  types.addAll(enclosing.mixins);
  for (final type in types) {
    final typeElement = type.element;
    if (element is MethodElement) {
      final targetName = element.name ?? name;
      final member = typeElement.getMethod(targetName);
      if (member != null) {
        candidates.add(member);
      } else {
        for (final candidate in typeElement.methods) {
          if (candidate.name == targetName) {
            candidates.add(candidate);
          }
        }
      }
    } else if (element is PropertyAccessorElement) {
      final isSetter = element.name?.endsWith('=') ?? false;
      final targetName = element.name ?? name;
      final member = isSetter
          ? typeElement.getSetter(targetName)
          : typeElement.getGetter(targetName);
      if (member != null) {
        candidates.add(member);
      } else {
        final list = isSetter ? typeElement.setters : typeElement.getters;
        for (final candidate in list) {
          if (candidate.name == targetName) {
            candidates.add(candidate);
          }
        }
      }
    }
  }

  for (final member in candidates) {
    if (_hasThrowsAnnotationOnElement(member)) {
      hasAnnotatedSuper = true;
      final errors = _expectedErrorsFromAnnotationElement(member);
      if (errors.isEmpty) {
        allowAny = true;
      } else {
        expectedErrors.addAll(errors);
      }
    }
  }

  return _InheritedThrowsInfo(
    hasAnnotatedSuper: hasAnnotatedSuper,
    allowAny: allowAny,
    expectedErrors: expectedErrors,
  );
}

bool _hasThrowsAnnotationOnElement(ExecutableElement element) {
  return element.metadata.annotations.any(_isThrowsAnnotation);
}

Set<String> _expectedErrorsFromElementOrSdk(Element? element) {
  final executable = element is ExecutableElement ? element : null;
  if (executable == null) {
    return const {};
  }

  final errors = _expectedErrorsFromAnnotationElement(executable);
  if (errors.isNotEmpty) {
    return errors.toSet();
  }

  final sdkErrors = sdkThrowsForElement(executable);
  if (sdkErrors == null) {
    return const {};
  }
  return sdkErrors.toSet();
}

List<String> _expectedErrorsFromAnnotationElement(ExecutableElement element) {
  for (final annotation in element.metadata.annotations) {
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
  return const [];
}

String? _typeNameFromExpression(Expression expression) {
  if (expression is InstanceCreationExpression) {
    return expression.constructorName.type.name.lexeme;
  }
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
  if (expression is MethodInvocation && expression.target == null) {
    final name = expression.methodName.name;
    if (name.isNotEmpty && name[0] == name[0].toUpperCase()) {
      return name;
    }
  }
  if (expression is SimpleIdentifier) {
    return expression.name;
  }
  if (expression is PrefixedIdentifier) {
    return expression.identifier.name;
  }
  return null;
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
