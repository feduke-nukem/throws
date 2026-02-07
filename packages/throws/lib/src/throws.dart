const throws = Throws();

class Throws {
  final String? reason;
  final Set<Type> expectedErrors;

  const Throws([
    this.reason,
    this.expectedErrors = const {},
  ]);
}
