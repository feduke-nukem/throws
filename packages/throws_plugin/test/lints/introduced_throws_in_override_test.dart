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
      [lint(176, 21)],
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
      [lint(163, 21)],
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

  void test_no_lint_when_override_throws_subtype() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
abstract class A {
  @Throws(errors: {Exception})
  void m();
}

class B implements A {
  @override
  void m() {
    throw FormatException('x');
  }
}''',
    );
  }

  void test_no_lint_when_base_allows_any() async {
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
abstract class A {
  @throws
  void m();
}

class B implements A {
  @override
  void m() {
    throw ArgumentError();
  }
}''',
    );
  }

  void test_reports_call_introducing_error() async {
    const code = r'''import 'package:throws/throws.dart';
@Throws(errors: {ArgumentError})
void boom() {
  throw ArgumentError();
}

abstract class A {
  @Throws(errors: {Exception})
  void m();
}

class B implements A {
  @override
  void m() {
    boom();
  }
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('boom'), 4)]);
  }

  void test_no_lint_when_error_caught_in_override() async {
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
abstract class A {
  @Throws(errors: {Exception})
  void m();
}

class B implements A {
  @override
  void m() {
    try {
      throw ArgumentError();
    } on ArgumentError {
      // handle
    }
  }
}''',
    );
  }

  void test_reports_getter_override() async {
    const code = r'''import 'package:throws/throws.dart';
abstract class A {
  @Throws(errors: {Exception})
  int get value;
}

class B implements A {
  @override
  int get value => throw ArgumentError();
}''';
    await assertDiagnostics(code, [
      lint(code.indexOf('throw ArgumentError()'), 21),
    ]);
  }

  void test_reports_mixin_member() async {
    const code = r'''import 'package:throws/throws.dart';
mixin M {
  @Throws(errors: {Exception})
  void m() {
    throw Exception('x');
  }
}

class B with M {
  @override
  void m() {
    throw ArgumentError();
  }
}''';
    await assertDiagnostics(code, [
      lint(code.indexOf('throw ArgumentError()'), 21),
    ]);
  }
}
