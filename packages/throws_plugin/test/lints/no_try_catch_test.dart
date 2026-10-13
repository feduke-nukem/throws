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

  void test_reports_operators() async {
    const code = r'''import 'package:throws/throws.dart';
class A {
  @Throws(errors: {FormatException})
  A operator +(A other) => throw FormatException();

  @Throws(errors: {FormatException})
  A operator -() => throw FormatException();

  @Throws(errors: {FormatException})
  int operator [](int i) => throw FormatException();

  @Throws(errors: {FormatException})
  void operator []=(int i, int v) => throw FormatException();
}

void f(A a) {
  a + a;
  -a;
  a[0];
  a[1] = 2;
}''';
    await assertDiagnostics(code, [
      lint(code.indexOf('a + a'), 5),
      lint(code.indexOf('-a;'), 2),
      lint(code.indexOf('a[0]'), 4),
      lint(code.indexOf('a[1]'), 4),
    ]);
  }

  void test_reports_compound_index_read_once() async {
    const code = r'''import 'package:throws/throws.dart';
class A {
  @Throws(errors: {FormatException})
  int operator [](int i) => throw FormatException();

  void operator []=(int i, int v) {}
}

void f(A a) {
  a[0] += 1;
}''';
    await assertDiagnostics(code, [lint(code.indexOf('a[0]'), 4)]);
  }

  void test_reports_setter_once() async {
    const code = r'''import 'package:throws/throws.dart';
class A {
  @Throws(errors: {FormatException})
  set value(int v) => throw FormatException();
}

void f(A a) {
  a.value = 1;
}''';
    await assertDiagnostics(code, [lint(code.indexOf('a.value'), 7)]);
  }

  void test_reports_compound_assignment_getter_once() async {
    const code = r'''import 'package:throws/throws.dart';
class A {
  @Throws(errors: {FormatException})
  int get count => throw FormatException();
  set count(int v) {}
}

void f(A a) {
  a.count += 1;
}''';
    await assertDiagnostics(code, [lint(code.indexOf('a.count'), 7)]);
  }

  void test_reports_unawaited_future_in_try() async {
    const code = '''$_asyncBoom
Future<void> f() async {
  try {
    asyncBoom();
  } catch (_) {
    // handle
  }
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('asyncBoom'), 9)]);
  }

  void test_no_lint_for_awaited_future_in_try() async {
    await assertNoDiagnostics('''$_asyncBoom
Future<void> f() async {
  try {
    await asyncBoom();
  } on FormatException {
    // handle
  }
}''');
  }

  void test_no_lint_for_future_awaited_inside_wait() async {
    await assertNoDiagnostics('''$_asyncBoom
Future<void> f() async {
  try {
    await Future.wait([asyncBoom()]);
  } catch (_) {
    // handle
  }
}''');
  }

  void test_no_lint_when_catch_error_chained() async {
    await assertNoDiagnostics('''$_asyncBoom
void f() {
  asyncBoom().whenComplete(() {}).catchError((Object _) {});
}''');
  }

  void test_no_lint_when_then_has_on_error() async {
    await assertNoDiagnostics('''$_asyncBoom
void f() {
  asyncBoom().then((_) {}, onError: (Object _) {});
}''');
  }

  void test_reports_when_then_has_no_on_error() async {
    const code = '''$_asyncBoom
void f() {
  asyncBoom().then((_) {});
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('asyncBoom'), 9)]);
  }

  void test_on_error_handles_its_type_only() async {
    const code = '''$_asyncBoom$_onErrorStub
@Throws(errors: {FormatException, ArgumentError})
Future<void> twoErrors() async {
  throw FormatException();
}

void f() {
  asyncBoom().onError<FormatException>((_, _) {});
  twoErrors().onError<FormatException>((_, _) {});
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('twoErrors'), 9)]);
  }

  void test_reports_rethrows_call_with_throwing_closure() async {
    const code = '''$_boom$_run
void f() {
  run(() => boom());
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('run('), 3)]);
  }

  void test_no_lint_when_rethrows_call_caught() async {
    await assertNoDiagnostics('''$_boom$_run
void f() {
  try {
    run(() {
      boom();
    });
  } on FormatException {
    // handle
  } on ArgumentError {
    // handle
  }
}''');
  }

  void test_no_lint_when_closure_handles_errors() async {
    await assertNoDiagnostics('''$_boom$_run
void f() {
  run(() {
    try {
      boom();
    } catch (_) {
      // handle
    }
  });
}''');
  }

  void test_no_lint_for_rethrows_call_with_safe_closure() async {
    await assertNoDiagnostics('''$_boom$_run
void f() {
  run(() {});
}''');
  }

  void test_reports_rethrows_call_with_tear_off() async {
    const code = '''$_boom$_run
void f() {
  run(boom);
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('run('), 3)]);
  }

  void test_rethrows_combines_with_own_errors() async {
    const code = '''$_boom
class OwnError implements Exception {}

@rethrows
@Throws(errors: {OwnError})
void run(void Function() action) {
  if (action == run) throw OwnError();
  action();
}

void f() {
  run(() {});
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('run('), 3)]);
  }

  void test_rethrows_inherited_from_overridden_member() async {
    const code = '''$_boom
abstract class Runner {
  @rethrows
  void run(void Function() action);
}

class SyncRunner implements Runner {
  @override
  void run(void Function() action) => action();
}

void f(SyncRunner runner) {
  runner.run(boom);
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('run('), 3)]);
  }

  void test_no_lint_for_closure_to_plain_parameter() async {
    await assertNoDiagnostics('''$_boom
void later(void Function() action) {}

void f() {
  later(() => boom());
}''');
  }

  void test_async_closure_to_void_parameter_is_not_rethrown() async {
    await assertNoDiagnostics('''$_asyncBoom
@rethrows
void run(void Function() action) => action();

void f() {
  run(() async => await asyncBoom());
}''');
  }

  void test_async_closure_to_future_parameter_is_rethrown() async {
    const code = '''$_asyncBoom
@rethrows
Future<void> retry(Future<void> Function() action) => action();

Future<void> f() async {
  try {
    await retry(() async => await asyncBoom());
  } on FormatException {
    // handle
  }
  try {
    retry(() async => await asyncBoom());
  } on FormatException {
    // handle
  }
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('retry('), 5)]);
  }

  void test_rethrown_errors_reach_callers_of_local_function() async {
    const code = '''$_boom$_run
void helper() {
  run(() => boom());
}

void f() {
  helper();
}''';
    await assertDiagnostics(code, [
      lint(code.lastIndexOf('run('), 3),
      lint(code.lastIndexOf('helper()'), 6),
    ]);
  }

  void test_reports_closure_to_function_parameter() async {
    const code = '''$_asyncBoom
@rethrows
void handle(Function callback) {}

void f() {
  handle(() async => await asyncBoom());
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('handle('), 6)]);
  }

  void test_reports_rethrows_call_with_member_tear_offs() async {
    const code = '''$_boom$_run
class Parser {
  @Throws(errors: {FormatException})
  void parse() => throw FormatException();

  @Throws(errors: {FormatException})
  static void check<T>() => throw FormatException();
}

void f(Parser parser) {
  run(parser.parse);
  run(Parser().parse);
  run(Parser.check<int>);
}''';
    await assertDiagnostics(code, [
      lint(code.indexOf('run(parser'), 3),
      lint(code.indexOf('run(Parser()'), 3),
      lint(code.indexOf('run(Parser.check'), 3),
    ]);
  }

  void test_getter_argument_is_a_call_not_a_tear_off() async {
    const code = '''$_boom$_run
class Holder {
  @Throws(errors: {FormatException})
  void Function() get action => throw FormatException();
}

void f(Holder holder) {
  run(holder.action);
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('action'), 6)]);
  }

  void test_reports_configured_rethrows_member() async {
    newFile('$testPackageRootPath/throws.yaml', '''
throws:
  rethrows:
    package:test/test.dart: [Runner.run]
''');
    const code = '''$_boom
class Runner {
  void run(void Function() action) => action();
}

void f(Runner runner) {
  runner.run(() => boom());
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('run('), 3)]);
  }

  void test_reports_prebuilt_sdk_rethrows() async {
    newFile('$testPackageRootPath/throws.yaml', '''
throws:
  prebuilt:
    - dart
''');
    const code = '''$_boom
void f(List<int> values) {
  values.forEach((_) => boom());
}''';
    await assertDiagnostics(code, [lint(code.indexOf('forEach'), 7)]);
  }

  void test_sdk_rethrows_needs_prebuilt() async {
    await assertNoDiagnostics('''$_boom
void f(List<int> values) {
  values.forEach((_) => boom());
}''');
  }

  void test_reports_unawaited_then_with_throwing_callback() async {
    newFile('$testPackageRootPath/throws.yaml', '''
throws:
  prebuilt:
    - dart
''');
    const code = '''$_boom
Future<void> f(Future<int> value) async {
  try {
    await value.then((_) => boom());
    value.then((_) => boom());
  } catch (_) {
    // handle
  }
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('then'), 4)]);
  }

  void test_reports_await_for_without_try() async {
    const code = '''$_stream
Future<void> f() async {
  await for (final _ in numbers()) {}
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('numbers'), 7)]);
  }

  void test_no_lint_for_await_for_in_try() async {
    await assertNoDiagnostics('''$_stream
Future<void> f() async {
  try {
    await for (final _ in numbers()) {}
  } on FormatException {
    // handle
  }
}''');
  }

  void test_reports_stream_call_in_await_for_body() async {
    const code = '''$_stream
Future<void> f(Stream<int> other) async {
  try {
    await for (final _ in other) {
      numbers().listen(null);
    }
  } on FormatException {
    // handle
  }
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('numbers'), 7)]);
  }

  void test_reports_listened_stream_in_try() async {
    const code = '''$_stream
void f() {
  try {
    numbers().listen(null);
  } catch (_) {
    // handle
  }
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('numbers'), 7)]);
  }

  void test_no_lint_when_listen_has_on_error() async {
    await assertNoDiagnostics('''$_stream
void f() {
  numbers().listen(null, onError: (Object _) {});
}''');
  }

  void test_no_lint_when_handle_error_chained() async {
    await assertNoDiagnostics('''$_stream
void f() {
  numbers().handleError((Object _) {}).listen(null);
}''');
  }

  void test_stream_getter_future_needs_await() async {
    const code = '''$_stream
Future<void> f() async {
  try {
    await numbers().first;
    numbers().first;
  } on FormatException {
    // handle
  }
  numbers().first.catchError((Object _) => 0);
}''';
    await assertDiagnostics(code, [
      lint(code.lastIndexOf('numbers().first;'), 7),
    ]);
  }

  void test_try_around_yield_star_does_not_handle() async {
    const code = '''$_stream
Stream<int> more() async* {
  try {
    yield* numbers();
  } on FormatException {
    // handle
  }
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('numbers'), 7)]);
  }

  void test_sync_for_does_not_await_futures() async {
    const code = '''$_asyncBoom
Future<void> f() async {
  try {
    for (final _ in [asyncBoom()]) {}
  } on FormatException {
    // handle
  }
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('asyncBoom'), 9)]);
  }

  void test_yield_star_passes_errors_to_caller() async {
    await assertNoDiagnostics('''$_stream
@Throws(errors: {FormatException})
Stream<int> more() async* {
  yield* numbers();
}''');
  }

  void test_no_lint_for_stored_future_awaited_in_try() async {
    await assertNoDiagnostics('''$_asyncBoom
Future<void> f() async {
  final pending = asyncBoom();
  try {
    await pending;
  } on FormatException {
    // handle
  }
}''');
  }

  void test_reports_stored_future_at_unhandled_await() async {
    const code = '''$_asyncBoom
Future<void> f() async {
  final pending = asyncBoom();
  try {
    await pending;
  } on FormatException {
    // handle
  }
  await pending;
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('pending'), 7)]);
  }

  void test_no_lint_for_stored_future_with_catch_error() async {
    await assertNoDiagnostics('''$_asyncBoom
void f() {
  final pending = asyncBoom();
  pending.catchError((Object _) {});
}''');
  }

  void test_no_lint_for_stored_chain_awaited_in_try() async {
    await assertNoDiagnostics('''$_asyncBoom
Future<void> f() async {
  final pending = asyncBoom().then((_) => 1);
  try {
    await pending;
  } on FormatException {
    // handle
  }
}''');
  }

  void test_no_lint_for_stored_stream_in_await_for() async {
    await assertNoDiagnostics('''$_stream
Future<void> f() async {
  final values = numbers();
  try {
    await for (final _ in values) {}
  } on FormatException {
    // handle
  }
}''');
  }

  void test_reports_stored_future_at_call_when_not_awaited() async {
    const code = '''$_asyncBoom
void f() {
  final pending = asyncBoom();
  print(pending);
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('asyncBoom'), 9)]);
  }

  void test_reports_reassigned_future_at_call() async {
    const code = '''$_asyncBoom
Future<void> f() async {
  var pending = asyncBoom();
  pending = Future.value();
  try {
    await pending;
  } catch (_) {
    // handle
  }
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('asyncBoom'), 9)]);
  }

  void test_reports_future_read_in_closure_at_call() async {
    const code = '''$_asyncBoom
void later(void Function() action) {}

void f() {
  final pending = asyncBoom();
  later(() async {
    try {
      await pending;
    } catch (_) {
      // handle
    }
  });
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('asyncBoom'), 9)]);
  }

  void test_stored_subscription_is_not_a_stream() async {
    const code = '''$_stream
Future<void> f() async {
  try {
    final subscription = numbers().listen(null);
    await subscription.cancel();
  } catch (_) {
    // handle
  }
}''';
    await assertDiagnostics(code, [lint(code.lastIndexOf('numbers'), 7)]);
  }
}

const _stream = r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException})
Stream<int> numbers() async* {
  throw FormatException();
}
''';

const _run = r'''
@rethrows
void run(void Function() action) => action();
''';

const _asyncBoom = r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException})
Future<void> asyncBoom() async {
  throw FormatException();
}
''';

/// The mock SDK has no `Future.onError`; mirror its signature.
const _onErrorStub = r'''
extension FutureOnError<T> on Future<T> {
  Future<T> onError<E extends Object>(
    void Function(E error, StackTrace stackTrace) handleError,
  ) => this;
}
''';
