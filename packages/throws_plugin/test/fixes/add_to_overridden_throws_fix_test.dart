// ignore_for_file: non_constant_identifier_names

import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/fixes/add_to_overridden_throws_fix.dart';

import '../correction_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AddToOverriddenThrowsFixTest);
  });
}

const _base = r'''
import 'package:throws/throws.dart';

abstract class A {
  @Throws(errors: {FormatException})
  void m();
}
''';

@reflectiveTest
class AddToOverriddenThrowsFixTest extends CorrectionTest {
  @override
  ProducerGenerator get generator => AddToOverriddenThrowsFix.new;

  Future<void> test_adds_to_member_in_other_file() async {
    final base = newFile('$testPackageLibPath/a.dart', _base);
    final result = await apply(r'''
import 'a.dart';

class B implements A {
  @override
  void m() {
    ^throw ArgumentError();
  }
}
''');
    expect(result, isNull, reason: 'the test file is not changed');
    expect(changedFile(base.path, _base), r'''
import 'package:throws/throws.dart';

abstract class A {
  @Throws(errors: {FormatException, ArgumentError})
  void m();
}
''');
  }

  Future<void> test_adds_errors_of_call() async {
    await assertHasCorrection(
      r'''
import 'package:throws/throws.dart';

@Throws(errors: {ArgumentError})
void boom() {
  throw ArgumentError();
}

abstract class A {
  @Throws(errors: {FormatException})
  void m();
}

class B extends A {
  @override
  void m() {
    ^boom();
  }
}
''',
      r'''
import 'package:throws/throws.dart';

@Throws(errors: {ArgumentError})
void boom() {
  throw ArgumentError();
}

abstract class A {
  @Throws(errors: {FormatException, ArgumentError})
  void m();
}

class B extends A {
  @override
  void m() {
    boom();
  }
}
''',
    );
  }

  Future<void> test_no_fix_when_base_allows_any() async {
    await assertNoCorrection(r'''
import 'package:throws/throws.dart';

abstract class A {
  @throws
  void m();
}

class B implements A {
  @override
  void m() {
    ^throw ArgumentError();
  }
}
''');
  }
}
