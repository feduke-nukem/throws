// ignore_for_file: non_constant_identifier_names

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/fixes/missing_throws_annotation_fix.dart';

import '../correction_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MissingThrowsAnnotationFixTest);
    defineReflectiveTests(AnnotateCallerFixTest);
  });
}

@reflectiveTest
class MissingThrowsAnnotationFixTest extends CorrectionTest {
  @override
  ProducerGenerator get generator => MissingThrowsAnnotationFix.new;

  Future<void> test_adds_annotation_with_errors() async {
    await assertHasCorrection(
      r'''
void ^f(bool b) {
  if (b) throw FormatException();
  throw ArgumentError();
}
''',
      r'''
import 'package:throws/throws.dart';

@Throws(reason: 'reason', errors: {ArgumentError, FormatException})
void f(bool b) {
  if (b) throw FormatException();
  throw ArgumentError();
}
''',
    );
  }

  Future<void> test_adds_empty_annotation_for_unknown_error() async {
    await assertHasCorrection(
      r'''
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

  Future<void> test_imports_error_type_from_other_library() async {
    newFile('$testPackageLibPath/errors.dart', r'''
class MyError extends Error {}

MyError makeError() => MyError();
''');
    await assertHasCorrection(
      r'''
import 'errors.dart' as e;

void ^f() {
  throw e.makeError();
}
''',
      r'''
import 'package:throws/throws.dart';

import 'errors.dart' as e;

@Throws(reason: 'reason', errors: {e.MyError})
void f() {
  throw e.makeError();
}
''',
    );
  }

  Future<void> test_annotates_method_after_doc_comment() async {
    await assertHasCorrection(
      r'''
class A {
  /// Docs.
  void ^m() {
    throw FormatException();
  }
}
''',
      r'''
import 'package:throws/throws.dart';

class A {
  /// Docs.
  @Throws(reason: 'reason', errors: {FormatException})
  void m() {
    throw FormatException();
  }
}
''',
    );
  }

  Future<void> test_no_fix_when_annotated() async {
    await assertNoCorrection(r'''
import 'package:throws/throws.dart';

@throws
void ^f() {
  throw FormatException();
}
''');
  }

  Future<void> test_no_fix_when_not_throwing() async {
    await assertNoCorrection(r'''
void ^f() {}
''');
  }

  Future<void> test_fixes_all_in_file() async {
    await assertHasCorrection(
      r'''
void /*0*/a() {
  throw FormatException();
}

void /*1*/b() {
  throw ArgumentError();
}
''',
      r'''
import 'package:throws/throws.dart';

@Throws(reason: 'reason', errors: {FormatException})
void a() {
  throw FormatException();
}

@Throws(reason: 'reason', errors: {ArgumentError})
void b() {
  throw ArgumentError();
}
''',
    );
  }

  Future<void> test_selects_reason() async {
    final result = await apply(r'''
void ^f() {
  throw FormatException();
}
''');
    expect(linkedTexts(result!), ["'reason'"]);
  }
}

@reflectiveTest
class AnnotateCallerFixTest extends CorrectionTest {
  @override
  ProducerGenerator get generator => AnnotateCallerFix.new;

  Future<void> test_annotates_calling_function() async {
    await assertHasCorrection(
      r'''
import 'package:throws/throws.dart';

@Throws(errors: {FormatException})
void boom() {
  throw FormatException();
}

void f() {
  ^boom();
}
''',
      r'''
import 'package:throws/throws.dart';

@Throws(errors: {FormatException})
void boom() {
  throw FormatException();
}

@Throws(reason: 'reason', errors: {FormatException})
void f() {
  boom();
}
''',
    );
  }

  Future<void> test_is_single_location() async {
    await assertNoCorrection(r'''
void ^f() {}
''');
    final producer = generator(context: StubCorrectionProducerContext.instance);
    expect(producer.canBeAppliedAcrossSingleFile, isFalse);
  }
}
