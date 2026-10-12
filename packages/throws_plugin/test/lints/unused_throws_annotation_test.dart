// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/lint/registry.dart'; // ignore: implementation_imports
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/lints/unused_throws_annotation.dart';

import '../stubs.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UnusedThrowsAnnotationTest);
  });
}

@reflectiveTest
class UnusedThrowsAnnotationTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'unused_throws_annotation';

  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(UnusedThrowsAnnotation());
    addThrowsPackage(this);
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(UnusedThrowsAnnotation());
    await super.tearDown();
  }

  void test_reports_unused_annotation() async {
    await assertDiagnostics(
      r'''import 'package:throws/throws.dart';
@throws
int delegatedParse(String input) {
  return 2;
}''',
      [lint(49, 14)],
    );
  }

  void test_no_lint_when_throwing() async {
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
@Throws()
int delegatedParse(String input) {
  throw Exception('x');
}''',
    );
  }

  void test_no_lint_for_abstract_member() async {
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
abstract class A {
      @Throws(reason: '', errors: {Exception})
  void m();
}''',
    );
  }

  void test_no_lint_when_only_untracked_errors_thrown() async {
    newFile('$testPackageRootPath/throws.yaml', '''
throws:
  track:
    - exception
''');
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
@Throws(errors: {ArgumentError})
void f() {
  throw ArgumentError();
}''',
    );
  }

  void test_no_lint_when_calling_throwing_function() async {
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
@Throws(errors: {ArgumentError})
void boom() {
  throw ArgumentError();
}

@Throws(errors: {ArgumentError})
void f() {
  boom();
}''',
    );
  }

  void test_reports_when_throw_caught_locally() async {
    const code = r'''import 'package:throws/throws.dart';
@Throws(errors: {ArgumentError})
void f() {
  try {
    throw ArgumentError();
  } on ArgumentError {
    // handle
  }
}''';
    await assertDiagnostics(code, [lint(code.indexOf('f()'), 1)]);
  }

  void test_no_lint_for_external_function() async {
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
@throws
external void f();''',
    );
  }
}
