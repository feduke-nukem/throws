import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:throws_plugin/src/data/error_set.dart';

/// A throw or a throwing call whose errors escape local try/catch.
class ThrowSite {
  /// Node to report diagnostics at.
  final AstNode node;

  /// Whether this is a call (as opposed to `throw`/`rethrow`).
  final bool isCall;

  /// Errors left after the enclosing try/catch statements.
  final ErrorSet errors;

  /// Whether the site is inside the body of a try with catch clauses.
  final bool inTryWithCatch;

  /// Whether this call returns a future that is not awaited, or a stream
  /// that is not iterated with `await for`, so no surrounding try/catch can
  /// handle its errors.
  final bool isUnawaitedFuture;

  const ThrowSite({
    required this.node,
    required this.isCall,
    required this.errors,
    required this.inTryWithCatch,
    this.isUnawaitedFuture = false,
  });
}

/// Throwing behaviour of one function, method, constructor or closure.
class FunctionSummary {
  final AstNode declaration;
  final Token nameToken;
  final FunctionBody body;
  final ExecutableElement? element;

  /// Own `@Throws` annotation.
  final ThrowsContract? annotation;

  /// Union of `@Throws` on overridden members.
  final ThrowsContract? inherited;

  final bool isAbstractOrExternal;

  /// Whether this closure is passed to a `@rethrows` parameter, so its
  /// errors are thrown by that call instead.
  bool rethrown = false;

  List<ThrowSite> sites = const [];

  /// Whether the body throws errors excluded by the `track` option.
  bool hasUntrackedThrow = false;

  /// Union of errors escaping this function.
  ErrorSet escaping = ErrorSet.empty;

  FunctionSummary({
    required this.declaration,
    required this.nameToken,
    required this.body,
    required this.element,
    required this.annotation,
    required this.inherited,
    required this.isAbstractOrExternal,
  });

  bool get isClosure => declaration is FunctionExpression;

  /// Contract callers rely on: own annotation, else the inherited one.
  ///
  /// A rethrown closure lets every error out to the call it is passed to.
  ThrowsContract? get contract =>
      rethrown ? const ThrowsContract({}) : annotation ?? inherited;

  bool get hasUnhandledThrow => sites.any((site) => !site.isCall);

  /// Errors of [site] that are neither caught nor declared by [contract].
  ErrorSet uncovered(ThrowSite site, TypeSystem typeSystem) {
    return contract?.uncovered(site.errors, typeSystem) ?? site.errors;
  }

  /// Sites located inside [node].
  Iterable<ThrowSite> sitesWithin(AstNode node) => sites.where(
    (site) => site.node.offset >= node.offset && site.node.end <= node.end,
  );
}
