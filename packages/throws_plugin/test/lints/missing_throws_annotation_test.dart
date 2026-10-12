// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/lint/registry.dart'; // ignore: implementation_imports
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/lints/missing_throws_annotation.dart';

import '../stubs.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MissingThrowsAnnotationTest);
  });
}

@reflectiveTest
class MissingThrowsAnnotationTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'missing_throws_annotation';

  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(MissingThrowsAnnotation());
    addThrowsPackage(this);
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(MissingThrowsAnnotation());
    await super.tearDown();
  }

  void test_reports_throw_without_annotation() async {
    await assertDiagnostics(
      r'''// ignore: unused_import
import 'package:throws/throws.dart';
void f() {
  throw Exception('x');
}''',
      [lint(67, 1)],
    );
  }

  void test_reports_throw_with_stack_trace_without_annotation() async {
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
}''',
      [lint(198, 24)],
    );
  }

  void test_no_lint_when_annotated() async {
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
@Throws()
void f() {
  throw Exception('x');
}''',
    );
  }

  void test_no_lint_when_not_throwing() async {
    await assertNoDiagnostics(
      r'''// ignore: unused_import
import 'package:throws/throws.dart';
int f() {
  return 2;
}''',
    );
  }

  void test_reports_sdk_throwing_call_without_annotation() async {
    await assertNoDiagnostics(
      r'''int parseIt(String input) {
  return int.parse(input);
}''',
    );
  }

  void test_reports_same_named_method_in_unrelated_class() async {
    const code = r'''import 'package:throws/throws.dart';
abstract class A {
  @Throws(errors: {Exception})
  void m();
}

class C {
  void m() {
    throw Exception('x');
  }
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('m()'), 1)]);
  }

  void test_no_lint_when_errors_untracked() async {
    newFile('$testPackageRootPath/throws.yaml', '''
throws:
  track: exception
''');
    await assertNoDiagnostics(
      r'''void f() {
  throw ArgumentError();
}''',
    );
  }

  void test_no_lint_when_throw_caught_locally() async {
    await assertNoDiagnostics(
      r'''void f() {
  try {
    throw FormatException();
  } on FormatException {
    // handle
  }
}''',
    );
  }

  void test_reports_when_catch_rethrows() async {
    const code = r'''void f() {
  try {
    throw FormatException();
  } on FormatException {
    rethrow;
  }
}''';
    await assertDiagnostics(code, [lint(code.indexOf('f()'), 1)]);
  }

  void test_reports_when_catch_type_does_not_match() async {
    const code = r'''void f() {
  try {
    throw FormatException();
  } on ArgumentError {
    // handle
  }
}''';
    await assertDiagnostics(code, [lint(code.indexOf('f()'), 1)]);
  }

  void test_no_lint_for_throw_in_closure() async {
    await assertNoDiagnostics(
      r'''void Function() f() {
  return () => throw FormatException();
}''',
    );
  }

  void test_reports_local_function() async {
    const code = r'''void f() {
  void g() {
    throw FormatException();
  }

  g;
}''';
    await assertDiagnostics(code, [lint(code.indexOf('g()'), 1)]);
  }

  void test_reports_constructor() async {
    const code = r'''class A {
  A() {
    throw FormatException();
  }
}''';
    await assertDiagnostics(code, [lint(code.indexOf('A()'), 1)]);
  }

  void test_reports_named_constructor() async {
    const code = r'''class A {
  A.named() {
    throw FormatException();
  }
}''';
    await assertDiagnostics(code, [lint(code.indexOf('named'), 5)]);
  }

  void test_reports_getter() async {
    const code = r'''class A {
  int get value => throw FormatException();
}''';
    await assertDiagnostics(code, [lint(code.indexOf('value'), 5)]);
  }

  void test_no_lint_when_override_of_annotated_member() async {
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
abstract class A {
  @Throws(errors: {FormatException})
  void m();
}

class B extends A {
  @override
  void m() {
    throw FormatException();
  }
}''',
    );
  }

  void test_no_lint_for_rethrow_without_try_in_closure() async {
    await assertNoDiagnostics(
      r'''void f() {
  try {
    print('x');
  } catch (e) {
    () {
      print(e);
    }();
  }
}''',
    );
  }
}
