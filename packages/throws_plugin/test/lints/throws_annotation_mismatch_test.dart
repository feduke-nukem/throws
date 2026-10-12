// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/lint/registry.dart'; // ignore: implementation_imports
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/lints/throws_annotation_mismatch.dart';

import '../stubs.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ThrowsAnnotationMismatchTest);
  });
}

@reflectiveTest
class ThrowsAnnotationMismatchTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'throws_annotation_mismatch';

  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(ThrowsAnnotationMismatch());
    addThrowsPackage(this);
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(ThrowsAnnotationMismatch());
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
      [lint(347, 1)],
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

  void test_no_lint_when_declared_supertype() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(errors: {Exception})
void f() {
  throw FormatException('x');
}''',
    );
  }

  void test_reports_when_declared_error_not_thrown() async {
    final code =
        '''import 'package:throws/throws.dart';
$coreStubs
@Throws(errors: {FormatException, ArgumentError})
void f() {
  throw FormatException('x');
}''';
    await assertDiagnostics(code, [lint(code.indexOf('f()'), 1)]);
  }

  void test_no_lint_when_declared_error_untracked() async {
    newFile('$testPackageRootPath/throws.yaml', '''
throws:
  track:
    - exception
''');
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
@Throws(errors: {Exception, ArgumentError})
void f() {
  throw Exception('x');
}''',
    );
  }

  void test_no_lint_when_extra_error_caught_locally() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(errors: {FormatException})
void f(bool b) {
  try {
    if (b) throw RangeError('x');
  } on RangeError {
    // handle
  }
  throw FormatException('x');
}''',
    );
  }

  void test_reports_when_called_function_adds_error() async {
    final code =
        '''import 'package:throws/throws.dart';
$coreStubs
@Throws(errors: {RangeError})
void boom() {
  throw RangeError('x');
}

@Throws(errors: {FormatException})
void f() {
  boom();
  throw FormatException('x');
}''';
    await assertDiagnostics(code, [lint(code.indexOf('f()'), 1)]);
  }

  void test_no_lint_for_unknown_thrown_error() async {
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
@Throws(errors: {ArgumentError})
void f(dynamic e) {
  throw e;
}''',
    );
  }
}
