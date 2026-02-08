// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/lint/registry.dart'; // ignore: implementation_imports
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/analyzer/throws_rules.dart';

const _coreStubs = '''
class Exception {
  const Exception([String? message]);
}

class ArgumentError implements Exception {
  const ArgumentError([Object? message]);
}

class FormatException implements Exception {
  const FormatException([String? message]);
}

class RangeError implements Exception {
  const RangeError([String? message]);
}
''';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MissingThrowsAnnotationRuleTest);
    defineReflectiveTests(MissingErrorHandlingRuleTest);
    defineReflectiveTests(ThrowsAnnotationMismatchRuleTest);
    defineReflectiveTests(IntroducedThrowsInOverrideRuleTest);
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
  final String? reason;
  final Set<Type> expectedErrors;

  const Throws([
    this.reason,
    this.expectedErrors = const {},
  ]);

  const Throws.named({
    this.reason,
    this.expectedErrors = const {},
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

@reflectiveTest
class IntroducedThrowsInOverrideRuleTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'introduced_throws_in_override';

  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(
      IntroducedThrowsInOverrideRule(),
    );
    newPackage('throws').addFile('lib/throws.dart', r'''
const throws = Throws();

class Throws {
  final String? reason;
  final Set<Type> expectedErrors;

  const Throws([
    this.reason,
    this.expectedErrors = const {},
  ]);

  const Throws.named({
    this.reason,
    this.expectedErrors = const {},
  });
}
''');
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(
      IntroducedThrowsInOverrideRule(),
    );
    await super.tearDown();
  }

  void test_reports_new_error_in_override() async {
    await assertDiagnostics(
      r'''import 'package:throws/throws.dart';
abstract interface class A {
  @Throws('', {Exception})
  void m();
}

class B implements A {
  @override
  void m() {
    throw ArgumentError();
  }
}''',
      [lint(150, 1)],
    );
  }

  void test_reports_new_error_in_extends() async {
    await assertDiagnostics(
      r'''import 'package:throws/throws.dart';
abstract class A {
  @Throws('', {Exception})
  void m();
}

class B extends A {
  @override
  void m() {
    throw ArgumentError();
  }
}''',
      [lint(137, 1)],
    );
  }

  void test_no_lint_when_override_matches_base() async {
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
abstract class A {
  @Throws('', {Exception})
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

@reflectiveTest
class MissingErrorHandlingRuleTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'missing_error_handling';

  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(MissingErrorHandlingRule());
    newPackage('throws').addFile('lib/throws.dart', r'''
const throws = Throws();

class Throws {
  final String? reason;
  final Set<Type> expectedErrors;

  const Throws([
    this.reason,
    this.expectedErrors = const {},
  ]);

  const Throws.named({
    this.reason,
    this.expectedErrors = const {},
  });
}
''');
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(MissingErrorHandlingRule());
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
    await assertNoDiagnostics(
      r'''int parseIt(String input) {
  return int.parse(input);
}''',
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

  void test_reports_unhandled_when_try_catch_partial() async {
    await assertDiagnostics(
      '''import 'package:throws/throws.dart';
$_coreStubs
@Throws('Delegates', {FormatException, RangeError})
int delegatedParse(String input) {
  throw FormatException('x');
}

void f() {
  try {
    delegatedParse('7');
  } on FormatException catch (_) {
    // handle
  }
}''',
      [lint(501, 14)],
    );
  }

  void test_no_lint_when_try_catch_covers_all() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$_coreStubs
@Throws('Delegates', {FormatException, RangeError})
int delegatedParse(String input) {
  throw FormatException('x');
}

void f() {
  try {
    delegatedParse('7');
  } on FormatException catch (_) {
    // handle
  } on RangeError catch (_) {
    // handle
  }
}''',
    );
  }

  void test_reports_throw_with_stack_trace_call() async {
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
}

void main() {
  errorThrowWithStackTrace();
}''',
      [lint(308, 24)],
    );
  }
}

@reflectiveTest
class ThrowsAnnotationMismatchRuleTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'throws_annotation_mismatch';

  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(ThrowsAnnotationMismatchRule());
    newPackage('throws').addFile('lib/throws.dart', r'''
const throws = Throws();

class Throws {
  final String? reason;
  final Set<Type> expectedErrors;

  const Throws([
    this.reason,
    this.expectedErrors = const {},
  ]);

  const Throws.named({
    this.reason,
    this.expectedErrors = const {},
  });
}
''');
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
$_coreStubs
@Throws('reason', {FormatException})
void f() {
  throw RangeError('x');
}''',
      [lint(400, 1)],
    );
  }

  void test_no_lint_when_matches() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$_coreStubs
@Throws('reason', {FormatException})
void f() {
  throw FormatException('x');
}''',
    );
  }

  void test_no_lint_when_allow_any() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$_coreStubs
@throws
void f() {
  throw FormatException('x');
}''',
    );
  }

  void test_no_lint_when_exception_type_literal() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$_coreStubs
@Throws('reason', {Exception})
void f() {
  throw Exception('x');
}''',
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
  final String? reason;
  final Set<Type> expectedErrors;

  const Throws([
    this.reason,
    this.expectedErrors = const {},
  ]);

  const Throws.named({
    this.reason,
    this.expectedErrors = const {},
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

  void test_no_lint_for_abstract_member() async {
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
abstract class A {
  @Throws('', {Exception})
  void m();
}''',
    );
  }
}
