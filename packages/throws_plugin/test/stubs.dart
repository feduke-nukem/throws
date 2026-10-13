import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';

/// Classes missing from the mock SDK, with the real dart:core hierarchy.
const coreStubs = '''
class FormatException implements Exception {
  const FormatException([String? message]);
}

class RangeError extends ArgumentError {
  RangeError([String? message]) : super(message);
}

class StateError extends Error {
  StateError(String message);
}
''';

/// Source of package:throws used in tests.
const throwsLibrary = r'''
const throws = Throws();

class Throws {
  final String? reason;
  final Set<Type> errors;

  const Throws({
    this.reason,
    this.errors = const {},
  });
}

const rethrows = Rethrows();

class Rethrows {
  const Rethrows();
}
''';

void addThrowsPackage(AnalysisRuleTest test) {
  test.newPackage('throws').addFile('lib/throws.dart', throwsLibrary);
}
