// ignore_for_file: non_constant_identifier_names

import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/fixes/throws_annotation_mismatch_fix.dart';

import '../correction_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ThrowsAnnotationMismatchFixTest);
  });
}

@reflectiveTest
class ThrowsAnnotationMismatchFixTest extends CorrectionTest {
  @override
  ProducerGenerator get generator => ThrowsAnnotationMismatchFix.new;

  Future<void> test_replaces_errors_and_keeps_reason() async {
    await assertHasCorrection(
      r'''
import 'package:throws/throws.dart';

@Throws(reason: "it's bad", errors: {ArgumentError})
void ^f() {
  throw FormatException();
}
''',
      r'''
import 'package:throws/throws.dart';

@Throws(reason: 'it\'s bad', errors: {FormatException})
void f() {
  throw FormatException();
}
''',
    );
  }

  Future<void> test_uses_empty_annotation_for_unknown_error() async {
    await assertHasCorrection(
      r'''
import 'package:throws/throws.dart';

@Throws(errors: {ArgumentError})
void ^f(dynamic error) {
  throw error;
}
''',
      r'''
import 'package:throws/throws.dart';

@throws
void f(dynamic error) {
  throw error;
}
''',
    );
  }

  Future<void> test_includes_errors_of_called_functions() async {
    await assertHasCorrection(
      r'''
import 'package:throws/throws.dart';

@Throws(errors: {ArgumentError})
void boom() {
  throw ArgumentError();
}

@Throws(errors: {FormatException})
void ^f() {
  boom();
}
''',
      r'''
import 'package:throws/throws.dart';

@Throws(errors: {ArgumentError})
void boom() {
  throw ArgumentError();
}

@Throws(errors: {ArgumentError})
void f() {
  boom();
}
''',
    );
  }

  Future<void> test_no_fix_without_annotation() async {
    await assertNoCorrection(r'''
void ^f() {
  throw FormatException();
}
''');
  }

  Future<void> test_fixes_all_in_file() async {
    await assertHasCorrection(
      r'''
import 'package:throws/throws.dart';

@Throws(errors: {ArgumentError})
void /*0*/a() {
  throw FormatException();
}

@Throws(errors: {FormatException})
void /*1*/b() {
  throw ArgumentError();
}
''',
      r'''
import 'package:throws/throws.dart';

@Throws(errors: {FormatException})
void a() {
  throw FormatException();
}

@Throws(errors: {ArgumentError})
void b() {
  throw ArgumentError();
}
''',
    );
  }
}
