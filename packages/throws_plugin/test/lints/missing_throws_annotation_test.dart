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
}
