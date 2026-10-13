// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/lint/registry.dart'; // ignore: implementation_imports
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/lints/not_exhaustive_try_catch.dart';

import '../stubs.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NotExhaustiveTryCatchTest);
  });
}

@reflectiveTest
class NotExhaustiveTryCatchTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'not_exhaustive_try_catch';

  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(NotExhaustiveTryCatch());
    addThrowsPackage(this);
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(NotExhaustiveTryCatch());
    await super.tearDown();
  }

  void test_reports_when_try_catch_partial() async {
    await assertDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(reason: 'Delegates', errors: {FormatException, RangeError})
int delegatedParse(String input) {
  throw FormatException('x');
}

void f() {
  try {
    delegatedParse('7');
  } on FormatException catch (_) {
    // handle
  }
}''',
      [lint(448, 14)],
    );
  }

  void test_no_lint_when_no_try_catch() async {
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
@Throws()
void boom() {
  throw Exception('x');
}

void caller() {
  boom();
}''',
    );
  }

  void test_no_lint_when_try_catch_covers_all() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(reason: 'Delegates', errors: {FormatException, RangeError})
int delegatedParse(String input) {
  throw FormatException('x');
}

void f() {
  try {
    delegatedParse('7');
  } on FormatException catch (_) {
    // handle
  } on RangeError catch (_) {
    // handle
  }
}''',
    );
  }

  void test_no_lint_when_allow_any_annotation() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws()
int delegatedParse(String input) {
  throw FormatException('x');
}

@Throws()
void f() {
  try {
    delegatedParse('7');
  } on FormatException catch (_) {
    // handle
  }
}''',
    );
  }

  void test_no_lint_when_supertype_caught() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(errors: {FormatException, RangeError})
void boom() {
  throw FormatException('x');
}

void f() {
  try {
    boom();
  } on Exception {
    // handle
  } on ArgumentError {
    // handle
  }
}''',
    );
  }

  void test_reports_when_matching_catch_rethrows() async {
    final code =
        '''import 'package:throws/throws.dart';
$coreStubs
@Throws(errors: {FormatException})
void boom() {
  throw FormatException('x');
}

void f() {
  try {
    boom();
  } on FormatException {
    rethrow;
  }
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('boom'), 4)]);
  }

  void test_no_lint_for_unknown_errors() async {
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
@throws
void boom() {}

void f() {
  try {
    boom();
  } on ArgumentError {
    // handle
  }
}''',
    );
  }

  void test_no_lint_when_outer_try_covers_rest() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(errors: {FormatException, RangeError})
void boom() {
  throw FormatException('x');
}

void f() {
  try {
    try {
      boom();
    } on FormatException {
      // handle
    }
  } on RangeError {
    // handle
  }
}''',
    );
  }

  void test_reports_in_closure() async {
    const code = r'''import 'package:throws/throws.dart';
@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

void later(void Function() action) {}

void f() {
  later(() {
    try {
      boom();
    } on FormatException {
      // handle
    }
  });
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('boom'), 4)]);
  }

  void test_no_lint_in_rethrown_closure() async {
    await assertNoDiagnostics(r'''import 'package:throws/throws.dart';
@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

@rethrows
void run(void Function() action) => action();

@Throws(errors: {ArgumentError})
void f() {
  run(() {
    try {
      boom();
    } on FormatException {
      // handle
    }
  });
}''');
  }
}
