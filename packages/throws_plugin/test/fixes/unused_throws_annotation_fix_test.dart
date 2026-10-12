// ignore_for_file: non_constant_identifier_names

import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/lints/unused_throws_annotation.dart';

import '../correction_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UnusedThrowsAnnotationFixTest);
  });
}

@reflectiveTest
class UnusedThrowsAnnotationFixTest extends CorrectionTest {
  @override
  ProducerGenerator get generator => UnusedThrowsAnnotationFix.new;

  Future<void> test_removes_annotation() async {
    await assertHasCorrection(
      r'''
import 'package:throws/throws.dart';

@Throws(reason: 'r')
int ^f() {
  return 1;
}
''',
      r'''
import 'package:throws/throws.dart';

int f() {
  return 1;
}
''',
    );
  }

  Future<void> test_no_fix_without_annotation() async {
    await assertNoCorrection(r'''
int ^f() {
  return 1;
}
''');
  }

  Future<void> test_fixes_all_in_file() async {
    await assertHasCorrection(
      r'''
import 'package:throws/throws.dart';

@throws
int /*0*/a() => 1;

@Throws(reason: 'r')
int /*1*/b() => 2;
''',
      r'''
import 'package:throws/throws.dart';

int a() => 1;

int b() => 2;
''',
    );
  }
}
