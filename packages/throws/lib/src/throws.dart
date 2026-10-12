/// Empty annotation for marking throwing functions.
const throws = Throws();

/// Annotations for marking throwing functions.
class Throws {
  /// Why the function throws, e.g. 'Parsing of input failed'.
  final String? reason;

  /// The types of errors that the function can throw, e.g. {FormatException, IOException}.
  final Set<Type> errors;

  const Throws({
    this.reason,
    this.errors = const {},
  });
}

/// Marks a function that throws whatever its function-typed parameters
/// throw, like Swift's `rethrows`.
///
/// Callers handle the errors of the closures and tear-offs they pass:
///
/// ```dart
/// @rethrows
/// T measure<T>(T Function() action) {
///   final watch = Stopwatch()..start();
///   try {
///     return action();
///   } finally {
///     print(watch.elapsed);
///   }
/// }
/// ```
///
/// Combine with [Throws] for errors the function throws itself.
const rethrows = Rethrows();

/// Annotation behind [rethrows].
class Rethrows {
  const Rethrows();
}
