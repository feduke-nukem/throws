import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:throws_plugin/src/data/error_set.dart';
import 'package:throws_plugin/src/data/function_summary.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/throws_config.dart';

/// Result of analyzing one compilation unit.
class ThrowsAnalysis {
  final List<FunctionSummary> summaries;
  final TypeSystem? _typeSystem;
  final ThrowsConfig config;
  final Map<AstNode, FunctionSummary> _byDeclaration;

  ThrowsAnalysis._(this.summaries, this._typeSystem, this.config)
    : _byDeclaration = {
        for (final summary in summaries) summary.declaration: summary,
      };

  /// Analysis of a unit without resolution: nothing to report.
  ThrowsAnalysis._empty() : this._(const [], null, const ThrowsConfig());

  TypeSystem get typeSystem => _typeSystem!;

  /// Summary for a function/method/constructor declaration node.
  FunctionSummary? summaryFor(AstNode? declaration) =>
      declaration == null ? null : _byDeclaration[declaration];

  /// Whether `@Throws` of [summary] declares exactly what it throws: every
  /// thrown error is covered and every tracked declared error is thrown.
  bool matchesAnnotation(FunctionSummary summary) {
    final annotation = summary.annotation;
    if (annotation == null || annotation.allowsAny) {
      return true;
    }
    final thrown = summary.escaping.types;
    final declared = annotation.errors.where(config.tracks);
    final covered = thrown.every(
      (type) => declared.any((error) => typeSystem.isSubtypeOf(type, error)),
    );
    final used = declared.every(
      (error) => thrown.any((type) => typeSystem.isSubtypeOf(type, error)),
    );
    return covered && used;
  }
}

class ThrowsAnalyzer {
  final ThrowsConfig _config;
  final TypeSystem _typeSystem;
  final LibraryElement _library;

  /// Raw declared errors per callee (annotation or throws maps).
  final Map<Element, ErrorSet?> _declared = {};

  /// Unannotated functions of this unit, keyed by element.
  final Map<Element, FunctionSummary> _local = {};

  /// Closures of this unit.
  final Map<FunctionExpression, FunctionSummary> _closures = {};

  /// Whether a callee is `@rethrows` (or listed in throws.yaml).
  final Map<Element, bool> _rethrowing = {};

  ThrowsAnalyzer._(this._library)
    : _config = ThrowsConfig.of(_library.session),
      _typeSystem = _library.typeSystem;

  static ThrowsAnalysis analyze(CompilationUnit unit) {
    final library = unit.declaredFragment?.element;
    if (library == null) {
      return ThrowsAnalysis._empty();
    }
    return ThrowsAnalyzer._(library)._analyze(unit);
  }

  ThrowsAnalysis _analyze(CompilationUnit unit) {
    final collector = _DeclarationCollector();
    unit.accept(collector);
    final summaries = collector.summaries;

    for (final summary in summaries) {
      final declaration = summary.declaration;
      if (declaration is FunctionExpression) {
        _closures[declaration] = summary;
        summary.rethrown = _isRethrownArgument(declaration);
        continue;
      }
      final element = summary.element;
      if (element != null && _declaredErrors(element) == null) {
        _local[element.baseElement] = summary;
      }
    }

    // Local unannotated functions and closures feed their errors to callers
    // in this unit; repeat until none of them changes what it throws.
    final localSummaries = {..._local.values, ..._closures.values};
    var changed = true;
    for (var pass = 0; changed && pass <= summaries.length; pass++) {
      changed = false;
      for (final summary in summaries) {
        final before = summary.escaping;
        final untrackedBefore = summary.hasUntrackedThrow;
        _collectSites(summary);
        if (localSummaries.contains(summary) &&
            (!summary.escaping.sameAs(before) ||
                summary.hasUntrackedThrow != untrackedBefore)) {
          changed = true;
        }
      }
    }

    return ThrowsAnalysis._(summaries, _typeSystem, _config);
  }

  void _collectSites(FunctionSummary summary) {
    final collector = _SiteCollector(this, summary);
    summary.hasUntrackedThrow = false;
    summary.body.accept(collector);
    summary.sites = collector.sites;
    summary.escaping = collector.sites.fold(
      ErrorSet.empty,
      (union, site) => union.union(site.errors),
    );
  }

  /// Declared errors of [element] or the members it overrides; null when
  /// the callee is not known to throw.
  ErrorSet? _declaredErrors(Element? element) {
    final executable = element is ExecutableElement
        ? element.baseElement
        : null;
    if (executable == null) {
      return null;
    }
    if (_declared.containsKey(executable)) {
      return _declared[executable];
    }

    ErrorSet? result;
    for (final member in [executable, ...overriddenMembers(executable)]) {
      final contract = annotationContract(member);
      if (contract != null) {
        result = contract.allowsAny
            ? ErrorSet.unknownOnly
            : ErrorSet(contract.errors);
        break;
      }
      final names = _config.errorNamesFor(member);
      if (names != null) {
        result = _resolveNames(names, member.library);
        break;
      }
    }
    return _declared[executable] = result;
  }

  /// Resolves error names from throws maps in the scope of the library that
  /// declares the member, falling back to dart:core.
  ErrorSet _resolveNames(List<String> names, LibraryElement library) {
    final core = _library.typeProvider.objectType.element.library;
    final types = <DartType>{};
    for (final name in names) {
      final element =
          library.firstFragment.scope.lookup(name).getter ??
          core.firstFragment.scope.lookup(name).getter;
      if (element is InterfaceElement) {
        types.add(
          _typeSystem.instantiateInterfaceToBounds(
            element: element,
            nullabilitySuffix: NullabilitySuffix.none,
          ),
        );
      }
    }
    return types.isEmpty ? ErrorSet.unknownOnly : ErrorSet(types);
  }

  /// Keeps tracked types; null when everything thrown is untracked.
  ErrorSet? _tracked(ErrorSet errors, FunctionSummary summary) {
    final types = errors.types.where(_config.tracks).toSet();
    if (types.isEmpty && !errors.unknown) {
      summary.hasUntrackedThrow = true;
      return null;
    }
    return types.length == errors.types.length
        ? errors
        : ErrorSet(types, unknown: errors.unknown);
  }

  ThrowSite? _throwSite(FunctionSummary summary, AstNode node, DartType? type) {
    final errors = type == null || type is DynamicType || type is InvalidType
        ? ErrorSet.unknownOnly
        : _tracked(ErrorSet({type}), summary);
    if (errors == null) {
      return null;
    }
    return _site(summary, node, errors, isCall: false);
  }

  /// Errors of calling [element] from [summary]; null when it does not throw.
  ErrorSet? _calleeErrors(FunctionSummary summary, Element? element) {
    final declared = _declaredErrors(element);
    if (declared != null) {
      return _tracked(declared, summary);
    }
    final local = _local[element?.baseElement];
    if (local == null) {
      return null;
    }
    if (local.hasUntrackedThrow) {
      summary.hasUntrackedThrow = true;
    }
    return local.escaping;
  }

  /// Whether [element] or a member it overrides is `@rethrows` or listed
  /// under `rethrows` in throws.yaml.
  bool _rethrows(Element? element) {
    final executable = element is ExecutableElement
        ? element.baseElement
        : null;
    if (executable == null) {
      return false;
    }
    return _rethrowing[executable] ??=
        [
          executable,
          ...overriddenMembers(executable),
        ].any(
          (member) =>
              member.metadata.annotations.any(isRethrowsAnnotation) ||
              _config.isRethrowing(member),
        );
  }

  /// Errors that [call] of a `@rethrows` [element] gets from its function
  /// arguments: closures and tear-offs of known functions.
  ErrorSet? _rethrownErrors(
    FunctionSummary summary,
    Element? element,
    Expression call,
  ) {
    if (!_rethrows(element)) {
      return null;
    }
    final arguments = switch (call) {
      InvocationExpression(:final argumentList) ||
      InstanceCreationExpression(
        :final argumentList,
      ) => argumentList.arguments,
      _ => const <Argument>[],
    };
    ErrorSet? result;
    for (final argument in arguments) {
      final expression = argument.argumentExpression;
      ErrorSet? errors;
      if (expression is FunctionExpression) {
        final closure = _closures[expression];
        if (closure == null || !closure.rethrown) {
          continue;
        }
        if (closure.hasUntrackedThrow) {
          summary.hasUntrackedThrow = true;
        }
        errors = closure.escaping;
      } else if (_isFunctionParameter(argument)) {
        errors = _calleeErrors(summary, _tornOff(expression));
      }
      if (errors != null) {
        result = result?.union(errors) ?? errors;
      }
    }
    return result;
  }

  /// Whether [closure] is an argument whose errors the call rethrows.
  bool _isRethrownArgument(FunctionExpression closure) {
    final parent = closure.parent;
    final Argument argument = parent is NamedArgument ? parent : closure;
    final element = switch (argument.parent?.parent) {
      MethodInvocation(:final methodName) => methodName.element,
      InstanceCreationExpression(:final constructorName) =>
        constructorName.element,
      FunctionExpressionInvocation(:final element) => element,
      _ => null,
    };
    if (!_rethrows(element) || !_isFunctionParameter(argument)) {
      return false;
    }
    // Errors of an async closure stay in its future; a parameter that
    // returns void drops it.
    final type = argument.correspondingParameter?.type;
    return !closure.body.isAsynchronous ||
        type is! FunctionType ||
        type.returnType is! VoidType;
  }

  static bool _isFunctionParameter(Argument argument) {
    final type = argument.correspondingParameter?.type;
    return type is FunctionType || (type?.isDartCoreFunction ?? false);
  }

  /// Function or method torn off by [expression].
  static ExecutableElement? _tornOff(Expression expression) {
    final element = switch (expression) {
      FunctionReference(:final function) => _tornOff(function),
      Identifier(:final element) => element,
      PropertyAccess(:final propertyName) => propertyName.element,
      _ => null,
    };
    return element is ExecutableElement && element is! PropertyAccessorElement
        ? element
        : null;
  }

  ThrowSite? _callSite(
    FunctionSummary summary,
    AstNode node,
    Element? element,
    Expression call,
  ) {
    final callee = _calleeErrors(summary, element);
    final rethrown = _rethrownErrors(summary, element, call);
    var errors = rethrown == null
        ? callee
        : callee?.union(rethrown) ?? rethrown;
    if (errors == null || errors.isEmpty) {
      return null;
    }
    final type = call.staticType;
    final isFuture =
        type != null && (type.isDartAsyncFuture || type.isDartAsyncFutureOr);
    if (isFuture) {
      errors = _withoutFutureHandled(call, errors);
      if (errors.isEmpty) {
        return null;
      }
    }
    return _site(summary, node, errors, isCall: true, isFuture: isFuture);
  }

  /// Removes errors handled by `catchError`, `onError<E>`, `then(onError:)`
  /// or `ignore` chained on the future returned by [call].
  ErrorSet _withoutFutureHandled(Expression call, ErrorSet errors) {
    final objectType = _library.typeProvider.objectType;
    final types = {...errors.types};
    Expression future = call;
    while (true) {
      final chained = future.parent;
      if (chained is! MethodInvocation || chained.target != future) {
        break;
      }
      future = chained;
      final handled = switch (chained.methodName.name) {
        'catchError' || 'ignore' => objectType,
        'onError' => chained.typeArgumentTypes?.firstOrNull ?? objectType,
        'then' when _hasNamedArgument(chained, 'onError') => objectType,
        _ => null,
      };
      if (handled == null) {
        continue;
      }
      if (handled.isDartCoreObject) {
        return ErrorSet.empty;
      }
      types.removeWhere((type) => _typeSystem.isSubtypeOf(type, handled));
    }
    return ErrorSet(types, unknown: errors.unknown);
  }

  static bool _hasNamedArgument(MethodInvocation node, String name) =>
      node.argumentList.arguments.any(
        (argument) => argument is NamedArgument && argument.name.lexeme == name,
      );

  /// Applies try/catch statements around [node] within the function body.
  ThrowSite? _site(
    FunctionSummary summary,
    AstNode node,
    ErrorSet errors, {
    required bool isCall,
    bool isFuture = false,
  }) {
    final types = {...errors.types};
    var unknown = errors.unknown;
    var inTryWithCatch = false;
    // Errors of a future reach a try only through `await`.
    var awaited = !isFuture;

    for (
      AstNode? current = node.parent;
      current != null && current != summary.body;
      current = current.parent
    ) {
      if (current is AwaitExpression) {
        awaited = true;
      }
      if (!awaited ||
          current is! TryStatement ||
          current.catchClauses.isEmpty ||
          node.offset < current.body.offset ||
          node.end > current.body.end) {
        continue;
      }
      inTryWithCatch = true;
      for (final clause in current.catchClauses) {
        if (alwaysRethrows(clause)) {
          continue;
        }
        if (catchesAll(clause)) {
          return null;
        }
        final caught = clause.exceptionType!.type!;
        unknown = false;
        types.removeWhere((type) => _typeSystem.isSubtypeOf(type, caught));
      }
      if (types.isEmpty && !unknown) {
        return null;
      }
    }

    return ThrowSite(
      node: node,
      isCall: isCall,
      errors: ErrorSet(types, unknown: unknown),
      inTryWithCatch: inTryWithCatch,
      isUnawaitedFuture: !awaited,
    );
  }
}

class _DeclarationCollector extends RecursiveAstVisitor<void> {
  final List<FunctionSummary> summaries = [];

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Bodies of function declarations are summarized with the declaration.
    if (node.parent is! FunctionDeclaration) {
      _add(
        node,
        node.beginToken,
        node.body,
        node.declaredFragment?.element,
        false,
      );
    }
    super.visitFunctionExpression(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _add(
      node,
      node.name,
      node.functionExpression.body,
      node.declaredFragment?.element,
      isAbstractOrExternalBody(
        node.functionExpression.body,
        node.externalKeyword != null,
      ),
    );
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _add(
      node,
      node.name,
      node.body,
      node.declaredFragment?.element,
      isAbstractOrExternalBody(node.body, node.externalKeyword != null),
    );
    super.visitMethodDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _add(
      node,
      node.name ??
          node.typeName?.token ??
          node.firstTokenAfterCommentAndMetadata,
      node.body,
      node.declaredFragment?.element,
      isAbstractOrExternalBody(node.body, node.externalKeyword != null),
    );
    super.visitConstructorDeclaration(node);
  }

  void _add(
    AstNode node,
    Token nameToken,
    FunctionBody body,
    ExecutableElement? element,
    bool isAbstractOrExternal,
  ) {
    final base = element?.baseElement;
    summaries.add(
      FunctionSummary(
        declaration: node,
        nameToken: nameToken,
        body: body,
        element: base,
        annotation: base == null ? null : annotationContract(base),
        inherited: base == null ? null : inheritedContract(base),
        isAbstractOrExternal: isAbstractOrExternal,
      ),
    );
  }
}

/// Collects throw and throwing call sites of one body, skipping nested
/// functions and closures (they have their own summaries).
class _SiteCollector extends RecursiveAstVisitor<void> {
  final ThrowsAnalyzer _analyzer;
  final FunctionSummary _summary;
  final List<ThrowSite> sites = [];

  _SiteCollector(this._analyzer, this._summary);

  void _add(ThrowSite? site) {
    if (site != null) {
      sites.add(site);
    }
  }

  /// [node] is reported; [call] is the whole call expression.
  void _call(AstNode node, Element? element, Expression call) {
    _add(_analyzer._callSite(_summary, node, element, call));
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {}

  @override
  void visitMethodDeclaration(MethodDeclaration node) {}

  @override
  void visitThrowExpression(ThrowExpression node) {
    _add(_analyzer._throwSite(_summary, node, node.expression.staticType));
    super.visitThrowExpression(node);
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    final caught = node.thisOrAncestorOfType<CatchClause>()?.exceptionType;
    _add(
      _analyzer._throwSite(
        _summary,
        node,
        caught?.type ?? _analyzer._library.typeProvider.objectType,
      ),
    );
    super.visitRethrowExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (isErrorThrowWithStackTrace(node)) {
      final arguments = node.argumentList.arguments;
      _add(
        _analyzer._throwSite(
          _summary,
          node,
          arguments.isEmpty
              ? null
              : arguments.first.argumentExpression.staticType,
        ),
      );
    } else {
      _call(node.methodName, node.methodName.element, node);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    _call(node, node.element, node);
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _call(node.constructorName, node.constructorName.element, node);
    super.visitInstanceCreationExpression(node);
  }

  // Property reads call getters; method tear-offs are not calls.
  @override
  void visitPropertyAccess(PropertyAccess node) {
    final element = node.propertyName.element;
    if (element is PropertyAccessorElement) {
      _call(node.propertyName, element, node);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final element = node.identifier.element;
    if (element is PropertyAccessorElement) {
      _call(node.identifier, element, node);
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    // Null for assignment targets: those go through visitAssignmentExpression.
    _call(node, node.element, node);
    super.visitIndexExpression(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    _call(node, node.element, node);
    super.visitBinaryExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    _call(node, node.element, node);
    super.visitPrefixExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    _call(node, node.element, node);
    super.visitPostfixExpression(node);
  }

  /// Setters, `[]=`, and the read and operator of compound assignments.
  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final target = node.leftHandSide;
    if (node.operator.type != TokenType.EQ) {
      _call(target, node.readElement, node);
      _call(node, node.element, node);
    }
    _call(target, node.writeElement, node);
    super.visitAssignmentExpression(node);
  }

  /// Getter read through implicit `this` or a top-level getter.
  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final parent = node.parent;
    final handledByParent =
        (parent is PropertyAccess && parent.propertyName == node) ||
        (parent is PrefixedIdentifier && parent.identifier == node) ||
        (parent is MethodInvocation && parent.methodName == node);
    if (!handledByParent &&
        node.element is GetterElement &&
        !node.inDeclarationContext()) {
      _call(node, node.element, node);
    }
    super.visitSimpleIdentifier(node);
  }
}
