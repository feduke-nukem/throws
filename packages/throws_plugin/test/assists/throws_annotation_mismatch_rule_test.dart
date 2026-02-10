// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/lint/registry.dart'; // ignore: implementation_imports
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/lints/throws_annotation_mismatch_rule.dart';

import '../stubs.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ThrowsAnnotationMismatchRuleTest);
  });
}

@reflectiveTest
class ThrowsAnnotationMismatchRuleTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'throws_annotation_mismatch';

  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(ThrowsAnnotationMismatchRule());
    addThrowsPackage(this);
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(ThrowsAnnotationMismatchRule());
    await super.tearDown();
  }

  void test_reports_mismatch_when_missing_error() async {
    await assertDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(reason: 'reason', errors: {FormatException})
void f() {
  throw RangeError('x');
}''',
      [lint(416, 1)],
    );
  }

  void test_no_lint_when_matches() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(reason: 'reason', errors: {FormatException})
void f() {
  throw FormatException('x');
}''',
    );
  }

  void test_no_lint_when_allow_any() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@throws
void f() {
  throw FormatException('x');
}''',
    );
  }

  void test_no_lint_when_exception_type_literal() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(reason: 'reason', errors: {Exception})
void f() {
  throw Exception('x');
}''',
    );
  }

  void test_no_lint_when_partial_handling_matches_annotation() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(errors: {ArgumentError, Exception})
void throwing() {
  if (1 == 1) {
    throw ArgumentError();
  }
  throw Exception('x');
}

@Throws(errors: {Exception})
void main() {
  try {
    throwing();
  } on ArgumentError catch (_) {
    // handle
  }
}''',
    );
  }

  void
  test_no_lint_when_partial_handling_matches_annotation_with_implements() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(errors: {ArgumentError, Exception})
void throwing() {
  if (1 == 1) {
    throw ArgumentError();
  }
  throw Exception('x');
}

abstract interface class A {
  @Throws(errors: {Exception})
  void doSome();
}

class B implements A {
  @override
  @Throws(errors: {Exception})
  void doSome() {
    try {
      throwing();
    } on ArgumentError catch (_) {
      // handle
    }
  }
}''',
    );
  }

  void
  test_no_lint_when_partial_handling_matches_annotation_with_extends() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(errors: {ArgumentError, Exception})
void throwing() {
  if (1 == 1) {
    throw ArgumentError();
  }
  throw Exception('x');
}

abstract class A {
  @Throws(errors: {Exception})
  void doSome();
}

class B extends A {
  @override
  @Throws(errors: {Exception})
  void doSome() {
    try {
      throwing();
    } on ArgumentError catch (_) {
      // handle
    }
  }
}''',
    );
  }
}
