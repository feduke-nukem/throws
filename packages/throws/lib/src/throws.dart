const throws = Throws();

class Throws {
  final String? reason;
  final Set<Type> errors;

  const Throws({
    this.reason,
    this.errors = const {},
  });
}
