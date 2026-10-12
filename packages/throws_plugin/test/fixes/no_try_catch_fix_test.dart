// ignore_for_file: non_constant_identifier_names

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
  } on ArgumentError catch (e, stackTrace) {
    // TODO: handle error
  } on FormatException catch (e, stackTrace) {
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
  } on ArgumentError catch (e, stackTrace) {
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
  } on Object catch (e, stackTrace) {
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
  } on Object catch (e, stackTrace) {
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
