import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';

const coreStubs = '''
class Exception {
  const Exception([String? message]);
}

class ArgumentError implements Exception {
  const ArgumentError([Object? message]);
}

class FormatException implements Exception {
  const FormatException([String? message]);
}

class RangeError implements Exception {
  const RangeError([String? message]);
}
''';

void addThrowsPackage(AnalysisRuleTest test) {
  test.newPackage('throws').addFile('lib/throws.dart', r'''
const throws = Throws();

class Throws {
  final String? reason;
  final Set<Type> errors;

  const Throws({
    this.reason,
    this.errors = const {},
  });
}
''');
}
