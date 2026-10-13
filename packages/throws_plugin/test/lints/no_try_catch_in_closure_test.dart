// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/lint/registry.dart'; // ignore: implementation_imports
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/lints/no_try_catch_in_closure.dart';

import '../stubs.dart';

const _boom = r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException})
void boom() {
  throw FormatException();
}

void later(void Function() action) {}

@rethrows
void run(void Function() action) => action();
''';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoTryCatchInClosureTest);
  });
}

@reflectiveTest
class NoTryCatchInClosureTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'no_try_catch_in_closure';

  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(NoTryCatchInClosure());
    addThrowsPackage(this);
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(NoTryCatchInClosure());
    await super.tearDown();
  }

  void test_reports_call_in_closure_to_plain_parameter() async {
    const code = '''$_boom
void f() {
  later(() => boom());
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('boom'), 4)]);
  }

  void test_reports_call_in_stored_closure() async {
    const code = '''$_boom
final handler = () {
  boom();
};''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('boom'), 4)]);
  }

  void test_reports_call_in_nested_closure() async {
    const code = '''$_boom
void f() {
  run(() {
    later(() => boom());
  });
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('boom'), 4)]);
  }

  void test_no_lint_when_closure_is_rethrown() async {
    await assertNoDiagnostics('''$_boom
void f() {
  run(() => boom());
}''');
  }

  void test_no_lint_when_handled_in_closure() async {
    await assertNoDiagnostics('''$_boom
void f() {
  later(() {
    try {
      boom();
    } on FormatException {
      // handle
    }
  });
}''');
  }

  void test_no_lint_for_partial_catch_in_closure() async {
    await assertNoDiagnostics('''$_boom
@Throws(errors: {FormatException, ArgumentError})
void boom2() => boom();

void f() {
  later(() {
    try {
      boom2();
    } on FormatException {
      // handle
    }
  });
}''');
  }

  void test_reports_despite_try_outside_closure() async {
    const code = '''$_boom
void f() {
  try {
    later(() => boom());
  } on FormatException {
    // handle
  }
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('boom'), 4)]);
  }

  void test_no_lint_for_explicit_throw() async {
    await assertNoDiagnostics('''$_boom
void f() {
  later(() => throw FormatException());
}''');
  }

  void test_reports_async_closure_to_void_parameter() async {
    const code = '''$_boom
@Throws(errors: {FormatException})
Future<void> asyncBoom() async => boom();

void f() {
  run(() async => await asyncBoom());
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('asyncBoom'), 9)]);
  }
}
