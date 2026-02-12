// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/lint/registry.dart'; // ignore: implementation_imports
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/lints/no_try_catch.dart';

import '../stubs.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoTryCatchTest);
  });
}

@reflectiveTest
class NoTryCatchTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'no_try_catch';

  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(NoTryCatch());
    addThrowsPackage(this);
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(NoTryCatch());
    await super.tearDown();
  }

  void test_reports_unhandled_throws_call() async {
    await assertDiagnostics(
      r'''import 'package:throws/throws.dart';
@Throws()
void boom() {
  throw Exception('x');
}

void caller() {
  boom();
}''',
      [lint(106, 4)],
    );
  }

  void test_reports_unhandled_throws_call_in_return() async {
    await assertDiagnostics(
      r'''import 'package:throws/throws.dart';
@Throws()
int boom() {
  throw Exception('x');
}

int caller() {
  return boom();
}''',
      [lint(111, 4)],
    );
  }

  void test_no_lint_when_try_catch() async {
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
@Throws()
void boom() {
  throw Exception('x');
}

void caller() {
  try {
    boom();
  } catch (_) {}
}''',
    );
  }

  void test_no_lint_when_annotated() async {
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
@Throws()
void boom() {
  throw Exception('x');
}

@Throws()
void caller() {
  boom();
}''',
    );
  }

  void test_reports_when_annotation_missing_errors_for_unhandled_call() async {
    await assertDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(errors: {ArgumentError, Exception})
int throwing() {
  throw ArgumentError();
}

@Throws(errors: {Exception})
void main() {
  throwing();
}''',
      [lint(492, 8)],
    );
  }

  void test_reports_sdk_throwing_call() async {
    await assertNoDiagnostics(
      r'''int parseIt(String input) {
  return int.parse(input);
}''',
    );
  }

  void test_reports_throws_getter_call() async {
    await assertDiagnostics(
      r'''import 'package:throws/throws.dart';
class Box {
  @Throws()
  int get value => throw Exception('x');
}

int readValue(Box box) {
  return box.value;
}''',
      [lint(143, 5)],
    );
  }

  void test_reports_local_throwing_call() async {
    await assertDiagnostics(
      r'''int getSingle() {
  throw Exception('x');
}

void main() {
  getSingle();
}''',
      [lint(61, 9)],
    );
  }

  void test_no_lint_when_try_catch_partial() async {
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
  }
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

  void test_no_lint_when_try_catch_rethrows_other_error() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(reason: 'Delegates to parsePositiveInt', errors: {RangeError})
int delegatedParse(String input) {
  throw RangeError('x');
}

void check() {
  try {
    delegatedParse('input');
  } on RangeError catch (e, stackTrace) { // ignore: unused_catch_stack
    throw Exception();
  }
}''',
    );
  }

  void test_reports_throw_with_stack_trace_call() async {
    await assertDiagnostics(
      r'''class Error {
  external static Never throwWithStackTrace(Object error, StackTrace stackTrace);
}

class StackTrace {
  const StackTrace();
  static const StackTrace current = StackTrace();
}

void errorThrowWithStackTrace() {
  Error.throwWithStackTrace(Exception(), StackTrace.current);
}

void main() {
  errorThrowWithStackTrace();
}''',
      [lint(308, 24)],
    );
  }
}
