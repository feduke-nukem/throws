// ignore_for_file: non_constant_identifier_names

import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/lints/no_try_catch.dart';

import '../correction_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoTryCatchFixTest);
    defineReflectiveTests(NoTryCatchWithDefaultFixTest);
  });
}

@reflectiveTest
class NoTryCatchFixTest extends CorrectionTest {
  @override
  ProducerGenerator get generator => NoTryCatchFix.new;

  Future<void> test_wraps_with_clause_per_error() async {
    await assertHasCorrection(
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

void f() {
  ^boom();
}
''',
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

void f() {
  try {
    boom();
  } on ArgumentError {
    // TODO: handle error
  } on FormatException {
    // TODO: handle error
  }
}
''',
    );
  }

  Future<void> test_skips_errors_declared_by_caller() async {
    await assertHasCorrection(
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

@Throws(errors: {FormatException})
void f() {
  ^boom();
}
''',
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

@Throws(errors: {FormatException})
void f() {
  try {
    boom();
  } on ArgumentError {
    // TODO: handle error
  }
}
''',
    );
  }

  Future<void> test_wraps_unknown_error_with_object() async {
    await assertHasCorrection(
      r'''
import 'package:throws/throws.dart';

@throws
void boom() {}

void f() {
  ^boom();
}
''',
      r'''
import 'package:throws/throws.dart';

@throws
void boom() {}

void f() {
  try {
    boom();
  } on Object {
    // TODO: handle error
  }
}
''',
    );
  }

  Future<void> test_no_fix_for_unawaited_future() async {
    await assertNoCorrection(r'''
import 'package:throws/throws.dart';

@Throws(errors: {FormatException})
Future<void> boom() async {
  throw FormatException();
}

void f() {
  ^boom();
}
''');
  }

  Future<void> test_wraps_awaited_future() async {
    await assertHasCorrection(
      r'''
import 'package:throws/throws.dart';

@Throws(errors: {FormatException})
Future<void> boom() async {
  throw FormatException();
}

Future<void> f() async {
  await ^boom();
}
''',
      r'''
import 'package:throws/throws.dart';

@Throws(errors: {FormatException})
Future<void> boom() async {
  throw FormatException();
}

Future<void> f() async {
  try {
    await boom();
  } on FormatException {
    // TODO: handle error
  }
}
''',
    );
  }

  Future<void> test_no_fix_inside_try() async {
    await assertNoCorrection(r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

void f() {
  try {
    ^boom();
  } finally {}
}
''');
  }

  Future<void> test_no_fix_when_caller_allows_any() async {
    await assertNoCorrection(r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

@throws
void f() {
  ^boom();
}
''');
  }

  Future<void> test_keeps_final_variable_in_scope() async {
    await assertHasCorrection(
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
int boom() {
  throw FormatException();
}

void f() {
  final value = ^boom();
  print(value);
}
''',
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
int boom() {
  throw FormatException();
}

void f() {
  late final int value;
  try {
    value = boom();
  } on ArgumentError {
    // TODO: handle error
  } on FormatException {
    // TODO: handle error
  }
  print(value);
}
''',
    );
  }

  Future<void> test_keeps_typed_var_variable_in_scope() async {
    await assertHasCorrection(
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
int boom() {
  throw FormatException();
}

void f() {
  num value = ^boom();
  print(value);
}
''',
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
int boom() {
  throw FormatException();
}

void f() {
  late num value;
  try {
    value = boom();
  } on ArgumentError {
    // TODO: handle error
  } on FormatException {
    // TODO: handle error
  }
  print(value);
}
''',
    );
  }

  Future<void> test_orders_subtypes_first() async {
    await assertHasCorrection(
      r'''
import 'package:throws/throws.dart';

class MyException implements Exception {}

@Throws(errors: {Exception, MyException})
void boom() {
  throw MyException();
}

void f() {
  ^boom();
}
''',
      r'''
import 'package:throws/throws.dart';

class MyException implements Exception {}

@Throws(errors: {Exception, MyException})
void boom() {
  throw MyException();
}

void f() {
  try {
    boom();
  } on MyException {
    // TODO: handle error
  } on Exception {
    // TODO: handle error
  }
}
''',
    );
  }

  Future<void> test_selects_handler_bodies() async {
    final result = await apply(r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

void f() {
  ^boom();
}
''');
    expect(linkedTexts(result!), [
      '// TODO: handle error',
      '// TODO: handle error',
    ]);
    expect(lastChange.linkedEditGroups, hasLength(2));
  }

  Future<void> test_wraps_void_expression_body() async {
    await assertHasCorrection(
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

class A {
  void f() => ^boom();
}
''',
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

class A {
  void f() {
    try {
      boom();
    } on ArgumentError {
      // TODO: handle error
    } on FormatException {
      // TODO: handle error
    }
  }
}
''',
    );
  }

  Future<void> test_wraps_async_void_expression_body() async {
    await assertHasCorrection(
      r'''
import 'package:throws/throws.dart';

@Throws(errors: {FormatException})
Future<void> boom() async {
  throw FormatException();
}

Future<void> f() async => await ^boom();
''',
      r'''
import 'package:throws/throws.dart';

@Throws(errors: {FormatException})
Future<void> boom() async {
  throw FormatException();
}

Future<void> f() async {
  try {
    await boom();
  } on FormatException {
    // TODO: handle error
  }
}
''',
    );
  }

  Future<void> test_no_fix_for_non_void_expression_body() async {
    await assertNoCorrection(r'''
import 'package:throws/throws.dart';

@Throws(errors: {FormatException})
int boom() => throw FormatException();

int f() => ^boom();
''');
  }
}

@reflectiveTest
class NoTryCatchWithDefaultFixTest extends CorrectionTest {
  @override
  ProducerGenerator get generator => NoTryCatchWithDefaultFix.new;

  Future<void> test_wraps_with_object_clause() async {
    await assertHasCorrection(
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

void f() {
  ^boom();
}
''',
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

void f() {
  try {
    boom();
  } on Object {
    // TODO: handle error
  }
}
''',
    );
  }

  Future<void> test_no_fix_for_non_throwing_call() async {
    await assertNoCorrection(r'''
void boom() {}

void f() {
  ^boom();
}
''');
  }
}
