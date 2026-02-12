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
