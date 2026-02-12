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
      [lint(517, 14)],
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
}
