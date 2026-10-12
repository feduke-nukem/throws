// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/lint/registry.dart'; // ignore: implementation_imports
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/lints/no_try_catch.dart';

import '../stubs.dart';

const _boom = r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}
''';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoTryCatchTest);
  });
}

@reflectiveTest
class NoTryCatchTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'no_try_catch';

  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(NoTryCatch());
    addThrowsPackage(this);
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(NoTryCatch());
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

  void test_reports_when_annotation_missing_errors_for_unhandled_call() async {
    await assertDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(errors: {ArgumentError, Exception})
int throwing() {
  throw ArgumentError();
}

@Throws(errors: {Exception})
void main() {
  throwing();
}''',
      [lint(423, 8)],
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

  void test_no_lint_when_try_catch_partial() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(reason: 'Delegates', errors: {FormatException, RangeError})
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
    );
  }

  void test_no_lint_when_try_catch_covers_all() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(reason: 'Delegates', errors: {FormatException, RangeError})
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

  void test_no_lint_when_try_catch_rethrows_other_error() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(reason: 'Delegates to parsePositiveInt', errors: {RangeError})
int delegatedParse(String input) {
  throw RangeError('x');
}

void check() {
  try {
    delegatedParse('input');
  } on RangeError catch (e, stackTrace) { // ignore: unused_catch_stack
    throw Exception();
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

  void test_no_lint_when_catching_supertype() async {
    await assertNoDiagnostics(
      '''import 'package:throws/throws.dart';
$coreStubs
@Throws(errors: {FormatException})
void boom() {
  throw FormatException('x');
}

void caller() {
  try {
    boom();
  } on Exception catch (_) {
    // handle
  }
}''',
    );
  }

  void test_reports_transitive_local_throwing_call() async {
    const code = r'''int a() {
  return b();
}

int b() {
  return c();
}

int c() {
  throw Exception('x');
}''';
    await assertDiagnostics(code, [
      lint(code.indexOf('b();'), 1),
      lint(code.indexOf('c();'), 1),
    ]);
  }

  void test_no_lint_for_method_tear_off() async {
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
class Box {
  @Throws()
  int value() => throw Exception('x');
}

int Function() read(Box box) {
  return box.value;
}''',
    );
  }

  void test_reports_implicit_this_getter() async {
    const code = r'''import 'package:throws/throws.dart';
class Box {
  @Throws()
  int get value => throw Exception('x');

  int read() {
    return value;
  }
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('value'), 5)]);
  }

  void test_reports_prebuilt_sdk_call() async {
    newFile('$testPackageRootPath/throws.yaml', '''
throws:
  prebuilt:
    - dart
''');
    const code = r'''int parseIt(String input) {
  return int.parse(input);
}''';
    await assertDiagnostics(code, [lint(code.indexOf('parse('), 5)]);
  }

  void test_no_lint_when_prebuilt_error_caught() async {
    newFile('$testPackageRootPath/throws.yaml', '''
throws:
  prebuilt:
    - dart
''');
    await assertNoDiagnostics(
      r'''int parseIt(String input) {
  try {
    return int.parse(input);
  } on FormatException {
    return 0;
  }
}''',
    );
  }

  void test_no_lint_when_errors_untracked() async {
    newFile('$testPackageRootPath/throws.yaml', '''
throws:
  track:
    - exception
''');
    await assertNoDiagnostics(
      r'''import 'package:throws/throws.dart';
@Throws(errors: {ArgumentError})
void boom() {
  throw ArgumentError();
}

void caller() {
  boom();
}''',
    );
  }

  void test_reports_when_exceptions_tracked() async {
    newFile('$testPackageRootPath/throws.yaml', '''
throws:
  track:
    - exception
''');
    const code = r'''import 'package:throws/throws.dart';
@Throws(errors: {ArgumentError, Exception})
void boom() {
  throw Exception('x');
}

void caller() {
  boom();
}''';
    await assertDiagnostics(code, [lint(code.indexOf('boom();'), 4)]);
  }

  void test_reports_annotated_constructor_call() async {
    const code = r'''import 'package:throws/throws.dart';
class A {
  @Throws(errors: {FormatException})
  A() {
    throw FormatException();
  }
}

void f() {
  A();
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('A()'), 1)]);
  }

  void test_reports_static_method_call() async {
    const code = r'''import 'package:throws/throws.dart';
class A {
  @Throws(errors: {FormatException})
  static void m() {
    throw FormatException();
  }
}

void f() {
  A.m();
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('m()'), 1)]);
  }

  void test_reports_top_level_getter() async {
    const code = r'''import 'package:throws/throws.dart';
@Throws(errors: {FormatException})
int get value => throw FormatException();

int f() {
  return value;
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('value'), 5)]);
  }

  void test_reports_call_through_implementation_type() async {
    const code = r'''import 'package:throws/throws.dart';
abstract class A {
  @Throws(errors: {FormatException})
  void m();
}

class B implements A {
  @override
  void m() {
    throw FormatException();
  }
}

void f(B b) {
  b.m();
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('m()'), 1)]);
  }

  void test_no_lint_when_inherited_contract_covers_call() async {
    await assertNoDiagnostics(
      '''$_boom
abstract class A {
  @Throws(errors: {FormatException, ArgumentError})
  void m();
}

class B implements A {
  @override
  void m() {
    boom();
  }
}''',
    );
  }

  void test_no_lint_when_outer_try_catches() async {
    await assertNoDiagnostics(
      '''$_boom
void f() {
  try {
    try {
      boom();
    } finally {
      print('done');
    }
  } catch (_) {
    // handle
  }
}''',
    );
  }

  void test_reports_call_in_catch_block() async {
    const code = '''$_boom
void f() {
  try {
    print('x');
  } catch (_) {
    boom();
  }
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('boom'), 4)]);
  }

  void test_no_lint_for_call_in_closure() async {
    await assertNoDiagnostics(
      '''$_boom
void Function() f() {
  return () => boom();
}''',
    );
  }

  void test_reports_once_for_recursive_local_functions() async {
    const code = r'''void a(int n) {
  if (n > 0) b(n - 1);
  throw FormatException();
}

void b(int n) {
  a(n);
}''';
    await assertDiagnostics(code, [
      lint(code.indexOf('b(n - 1)'), 1),
      lint(code.indexOf('a(n);'), 1),
    ]);
  }

  void test_reports_configured_member() async {
    newFile('$testPackageRootPath/throws.yaml', '''
throws:
  members:
    package:test/test.dart:
      load:
        - FormatException
''');
    const code = r'''void load() {}

void f() {
  load();
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('load'), 4)]);
  }

  void test_reports_member_from_include_file() async {
    newFile('$testPackageRootPath/maps/errors.yaml', '''
package:test/test.dart:
  load: [FormatException]
''');
    newFile('$testPackageRootPath/throws.yaml', '''
throws:
  include:
    - maps/errors.yaml
''');
    const code = r'''void load() {}

void f() {
  load();
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('load'), 4)]);
  }

  void test_reports_member_from_include_directory() async {
    newFile('$testPackageRootPath/maps/errors.yaml', '''
package:test/test.dart:
  load: FormatException
''');
    newFile('$testPackageRootPath/maps/ignored.txt', 'x');
    newFile('$testPackageRootPath/throws.yaml', '''
throws:
  include: maps
''');
    const code = r'''void load() {}

void f() {
  load();
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('load'), 4)]);
  }

  void test_ignores_v1_keys() async {
    newFile('$testPackageRootPath/throws.yaml', '''
throws:
  include_sdk_errors: true
  include_prebuilt: [dart]
  custom_errors:
    package:test/test.dart.load: [FormatException]
''');
    await assertNoDiagnostics(
      r'''void load() {}

int f(String input) {
  load();
  return int.parse(input);
}''',
    );
  }

  void test_reports_configured_class_members() async {
    newFile('$testPackageRootPath/throws.yaml', '''
throws:
  members:
    package:test/test.dart:
      A.new: FormatException
      A.named: FormatException
      A.m: FormatException
      A.value: FormatException
''');
    const code = r'''class A {
  A();
  A.named();
  void m() {}
  int get value => 0;
}

void f() {
  A().m();
  A.named().value;
}''';
    await assertDiagnostics(code, [
      lint(code.indexOf('A().'), 1),
      lint(code.indexOf('m();'), 1),
      lint(code.lastIndexOf('A.named()'), 7),
      lint(code.lastIndexOf('value'), 5),
    ]);
  }

  void test_unresolved_error_name_needs_any_catch() async {
    newFile('$testPackageRootPath/throws.yaml', '''
throws:
  members:
    package:test/test.dart:
      load: NoSuchType
''');
    await assertNoDiagnostics(
      r'''void load() {}

void f() {
  try {
    load();
  } on ArgumentError {
    // handle
  }
}''',
    );
  }

  void test_ignores_invalid_throws_yaml() async {
    newFile('$testPackageRootPath/throws.yaml', 'throws: [');
    await assertNoDiagnostics(
      r'''int parseIt(String input) {
  return int.parse(input);
}''',
    );
  }
}
