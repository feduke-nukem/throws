// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/lint/registry.dart'; // ignore: implementation_imports
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/lints/unused_throws_annotation_rule.dart';

import '../stubs.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UnusedThrowsAnnotationRuleTest);
  });
}

@reflectiveTest
class UnusedThrowsAnnotationRuleTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'unused_throws_annotation';

  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(UnusedThrowsAnnotationRule());
    addThrowsPackage(this);
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(UnusedThrowsAnnotationRule());
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
}
