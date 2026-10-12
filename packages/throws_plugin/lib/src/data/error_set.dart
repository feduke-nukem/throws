import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';

/// Errors that a throw or a call may produce.
///
/// [unknown] means it throws, but the error types are not declared
/// (e.g. `@throws` or a `dynamic` thrown value).
class ErrorSet {
  final Set<DartType> types;
  final bool unknown;

  const ErrorSet(this.types, {this.unknown = false});

  static const ErrorSet empty = ErrorSet({});
  static const ErrorSet unknownOnly = ErrorSet({}, unknown: true);

  bool get isEmpty => types.isEmpty && !unknown;

  ErrorSet union(ErrorSet other) => ErrorSet(
    {...types, ...other.types},
    unknown: unknown || other.unknown,
  );

  bool sameAs(ErrorSet other) =>
      unknown == other.unknown &&
      types.length == other.types.length &&
      types.containsAll(other.types);

  /// Types sorted by display name, for stable quick fix output.
  List<DartType> get sortedTypes =>
      types.toList()
        ..sort((a, b) => a.getDisplayString().compareTo(b.getDisplayString()));
}

/// Errors declared by `@Throws`; empty [errors] allows any error.
class ThrowsContract {
  final Set<DartType> errors;

  const ThrowsContract(this.errors);

  bool get allowsAny => errors.isEmpty;

  /// Whether thrown [type] is a subtype of a declared error.
  bool covers(DartType type, TypeSystem typeSystem) =>
      allowsAny || errors.any((error) => typeSystem.isSubtypeOf(type, error));

  /// Part of [thrown] not covered by this contract.
  ///
  /// Unknown errors are covered by any contract.
  ErrorSet uncovered(ErrorSet thrown, TypeSystem typeSystem) {
    if (allowsAny) {
      return ErrorSet.empty;
    }
    return ErrorSet(
      thrown.types.where((type) => !covers(type, typeSystem)).toSet(),
    );
  }
}
