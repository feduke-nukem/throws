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

  const ThrowSite({
    required this.node,
    required this.isCall,
    required this.errors,
    required this.inTryWithCatch,
  });
}

/// Throwing behaviour of one function, method or constructor.
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

  /// Contract callers rely on: own annotation, else the inherited one.
  ThrowsContract? get contract => annotation ?? inherited;

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
