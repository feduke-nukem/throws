// ignore_for_file: non_constant_identifier_names

import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/assists/add_empty_throws_annotation.dart';
import 'package:throws_plugin/src/assists/add_throws_annotation.dart';

import '../correction_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AddThrowsAnnotationAssistTest);
    defineReflectiveTests(AddEmptyThrowsAnnotationAssistTest);
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
