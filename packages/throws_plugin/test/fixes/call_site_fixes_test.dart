// ignore_for_file: non_constant_identifier_names

import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/fixes/add_await_fix.dart';
import 'package:throws_plugin/src/fixes/add_to_throws_annotation_fix.dart';

import '../correction_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AddAwaitFixTest);
    defineReflectiveTests(AddToThrowsAnnotationFixTest);
  });
}

const _asyncBoom = r'''
import 'package:throws/throws.dart';

@Throws(errors: {FormatException})
Future<int> boom() async {
  throw FormatException();
}
''';

@reflectiveTest
class AddAwaitFixTest extends CorrectionTest {
  @override
  ProducerGenerator get generator => AddAwaitFix.new;

  Future<void> test_awaits_call_in_try() async {
    await assertHasCorrection(
      '''$_asyncBoom
Future<void> f() async {
  try {
    final value = ^boom();
    print(value);
  } on FormatException {
    // handle
  }
}
''',
      '''$_asyncBoom
Future<void> f() async {
  try {
    final value = await boom();
    print(value);
  } on FormatException {
    // handle
  }
}
''',
    );
  }

  Future<void> test_no_fix_outside_try() async {
    await assertNoCorrection('''$_asyncBoom
Future<void> f() async {
  ^boom();
}
''');
  }

  Future<void> test_no_fix_in_sync_function() async {
    await assertNoCorrection('''$_asyncBoom
void f() {
  try {
    ^boom();
  } on FormatException {
    // handle
  }
}
''');
  }

  Future<void> test_awaits_future_from_stream_getter() async {
    await assertHasCorrection(
      '''$_numbers
Future<void> f() async {
  try {
    ^numbers().first;
  } on FormatException {
    // handle
  }
}
''',
      '''$_numbers
Future<void> f() async {
  try {
    await numbers().first;
  } on FormatException {
    // handle
  }
}
''',
    );
  }

  Future<void> test_no_fix_for_listened_stream() async {
    await assertNoCorrection('''$_numbers
Future<void> f() async {
  try {
    ^numbers().listen(null);
  } on FormatException {
    // handle
  }
}
''');
  }

  Future<void> test_no_fix_for_chained_call() async {
    await assertNoCorrection('''$_asyncBoom
Future<void> f() async {
  try {
    ^boom().then((_) {});
  } on FormatException {
    // handle
  }
}
''');
  }
}

const _numbers = r'''
import 'package:throws/throws.dart';

@Throws(errors: {FormatException})
Stream<int> numbers() async* {
  throw FormatException();
}
''';

const _boom = r'''
import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}
''';

@reflectiveTest
class AddToThrowsAnnotationFixTest extends CorrectionTest {
  @override
  ProducerGenerator get generator => AddToThrowsAnnotationFix.new;

  Future<void> test_adds_uncovered_errors() async {
    await assertHasCorrection(
      '''$_boom
@Throws(reason: 'r', errors: {FormatException})
void f() {
  ^boom();
}
''',
      '''$_boom
@Throws(reason: 'r', errors: {FormatException, ArgumentError})
void f() {
  boom();
}
'''
          .replaceFirst('^', ''),
    );
  }

  Future<void> test_adds_errors_left_after_catch() async {
    await assertHasCorrection(
      '''$_boom
@Throws(errors: {UnsupportedError})
void f() {
  try {
    ^boom();
  } on FormatException {
    // handle
  }
}
''',
      '''$_boom
@Throws(errors: {UnsupportedError, ArgumentError})
void f() {
  try {
    boom();
  } on FormatException {
    // handle
  }
}
''',
    );
  }

  Future<void> test_no_fix_without_annotation() async {
    await assertNoCorrection('''$_boom
void f() {
  ^boom();
}
''');
  }

  Future<void> test_no_fix_when_annotation_allows_any() async {
    await assertNoCorrection('''$_boom
@throws
void f() {
  ^boom();
}
''');
  }
}
