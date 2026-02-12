// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/lint/registry.dart'; // ignore: implementation_imports
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/lints/introduced_throws_in_override.dart';

import '../stubs.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(IntroducedThrowsInOverrideTest);
  });
}

@reflectiveTest
class IntroducedThrowsInOverrideTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'introduced_throws_in_override';

  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(
      IntroducedThrowsInOverride(),
    );
    addThrowsPackage(this);
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(
      IntroducedThrowsInOverride(),
    );
    await super.tearDown();
  }

  void test_reports_new_error_in_override() async {
    await assertDiagnostics(
      r'''import 'package:throws/throws.dart';
abstract interface class A {
  @Throws(reason: '', errors: {Exception})
  void m();
}

class B implements A {
  @override
  void m() {
    throw ArgumentError();
  }
}''',
      [lint(166, 1)],
    );
  }

  void test_reports_new_error_in_extends() async {
    await assertDiagnostics(
      r'''import 'package:throws/throws.dart';
abstract class A {
  @Throws(reason: '', errors: {Exception})
  void m();
}

class B extends A {
  @override
  void m() {
    throw ArgumentError();
  }
}''',
      [lint(153, 1)],
    );
  }

  void test_no_lint_when_override_matches_base() async {
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
abstract class A {
  @Throws(reason: '', errors: {Exception})
  void m();
}

class B implements A {
  @override
  void m() {
    throw Exception('x');
  }
}''',
    );
  }
}
