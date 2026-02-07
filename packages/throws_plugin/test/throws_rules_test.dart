// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/lint/registry.dart'; // ignore: implementation_imports
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/analyzer/throws_rules.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MissingThrowsAnnotationRuleTest);
    defineReflectiveTests(UnhandledThrowsCallRuleTest);
    defineReflectiveTests(UnusedThrowsAnnotationRuleTest);
  });
}

@reflectiveTest
class MissingThrowsAnnotationRuleTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'missing_throws_annotation';

  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(MissingThrowsAnnotationRule());
    newPackage('throws').addFile('lib/throws.dart', r'''
const throws = Throws();

class Throws {
  const Throws([String? reason, Set<Type> expectedErrors = const {}]);
  const Throws.named({
    String? reason,
    Set<Type> expectedErrors = const {},
  });
}
''');
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(MissingThrowsAnnotationRule());
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
    await assertDiagnostics(
      r'''int parseIt(String input) {
  return int.parse(input);
}''',
      [lint(4, 7)],
    );
  }
}

@reflectiveTest
class UnhandledThrowsCallRuleTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'unhandled_throws_call';

  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(UnhandledThrowsCallRule());
    newPackage('throws').addFile('lib/throws.dart', r'''
const throws = Throws();

class Throws {
  const Throws([String? reason, Set<Type> expectedErrors = const {}]);
  const Throws.named({
    String? reason,
    Set<Type> expectedErrors = const {},
  });
}
''');
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(UnhandledThrowsCallRule());
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

  void test_reports_sdk_throwing_call() async {
    await assertDiagnostics(
      r'''int parseIt(String input) {
  return int.parse(input);
}''',
      [lint(41, 5)],
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
}

@reflectiveTest
class UnusedThrowsAnnotationRuleTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'unused_throws_annotation';

  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(UnusedThrowsAnnotationRule());
    newPackage('throws').addFile('lib/throws.dart', r'''
const throws = Throws();

class Throws {
  const Throws([String? reason, Set<Type> expectedErrors = const {}]);
  const Throws.named({
    String? reason,
    Set<Type> expectedErrors = const {},
  });
}
''');
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
}
