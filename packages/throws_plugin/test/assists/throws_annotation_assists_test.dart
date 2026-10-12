// ignore_for_file: non_constant_identifier_names

import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/assists/add_empty_throws_annotation.dart';
import 'package:throws_plugin/src/assists/add_throws_annotation.dart';
import 'package:throws_plugin/src/assists/specify_throws_errors.dart';

import '../correction_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AddThrowsAnnotationAssistTest);
    defineReflectiveTests(AddEmptyThrowsAnnotationAssistTest);
    defineReflectiveTests(SpecifyThrowsErrorsAssistTest);
  });
}

@reflectiveTest
class AddThrowsAnnotationAssistTest extends CorrectionTest {
  @override
  ProducerGenerator get generator => AddThrowsAnnotationAssist.new;

  Future<void> test_adds_annotation() async {
    await assertHasCorrection(
      r'''
void ^f() {}
''',
      r'''
import 'package:throws/throws.dart';

@Throws(reason: 'reason', errors: {})
void f() {}
''',
    );
  }

  Future<void> test_no_assist_when_annotated() async {
    await assertNoCorrection(r'''
import 'package:throws/throws.dart';

@throws
void ^f() {}
''');
  }
}

@reflectiveTest
class AddEmptyThrowsAnnotationAssistTest extends CorrectionTest {
  @override
  ProducerGenerator get generator => AddEmptyThrowsAnnotationAssist.new;

  Future<void> test_adds_annotation_to_method() async {
    await assertHasCorrection(
      r'''
class A {
  void ^m() {}
}
''',
      r'''
import 'package:throws/throws.dart';

class A {
  @throws
  void m() {}
}
''',
    );
  }

  Future<void> test_no_assist_outside_function() async {
    await assertNoCorrection(r'''
int ^x = 1;
''');
  }
}

@reflectiveTest
class SpecifyThrowsErrorsAssistTest extends CorrectionTest {
  @override
  ProducerGenerator get generator => SpecifyThrowsErrorsAssist.new;

  Future<void> test_specifies_errors_of_empty_annotation() async {
    await assertHasCorrection(
      r'''
import 'package:throws/throws.dart';

@throws
void ^f(bool b) {
  if (b) throw ArgumentError();
  throw FormatException();
}
''',
      r'''
import 'package:throws/throws.dart';

@Throws(errors: {ArgumentError, FormatException})
void f(bool b) {
  if (b) throw ArgumentError();
  throw FormatException();
}
''',
    );
  }

  Future<void> test_keeps_reason() async {
    await assertHasCorrection(
      r'''
import 'package:throws/throws.dart';

@Throws(reason: 'bad input')
void ^f() {
  throw FormatException();
}
''',
      r'''
import 'package:throws/throws.dart';

@Throws(reason: 'bad input', errors: {FormatException})
void f() {
  throw FormatException();
}
''',
    );
  }

  Future<void> test_no_assist_when_errors_specified() async {
    await assertNoCorrection(r'''
import 'package:throws/throws.dart';

@Throws(errors: {FormatException})
void ^f() {
  throw FormatException();
}
''');
  }

  Future<void> test_no_assist_for_unknown_errors() async {
    await assertNoCorrection(r'''
import 'package:throws/throws.dart';

@throws
void ^f(dynamic e) {
  throw e;
}
''');
  }
}
