// ignore_for_file: non_constant_identifier_names

import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:throws_plugin/src/lints/not_exhaustive_try_catch.dart';

import '../correction_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NotExhaustiveTryCatchFixTest);
    defineReflectiveTests(NotExhaustiveTryCatchDefaultFixTest);
  });
}

@reflectiveTest
class NotExhaustiveTryCatchFixTest extends CorrectionTest {
  @override
  ProducerGenerator get generator => NotExhaustiveTryCatchFix.new;

  Future<void> test_adds_missing_clauses() async {
    await assertHasCorrection(
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

void f() {
  try {
    ^boom();
  } on FormatException {
    // handle
  }
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
  } on FormatException {
    // handle
  } on ArgumentError {
    // TODO: handle error
  }
}
''',
    );
  }

  Future<void> test_adds_missing_clauses_in_closure() async {
    await assertHasCorrection(
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

void later(void Function() action) {}

void f() {
  later(() {
    try {
      ^boom();
    } on FormatException {
      // handle
    }
  });
}
''',
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

void later(void Function() action) {}

void f() {
  later(() {
    try {
      boom();
    } on FormatException {
      // handle
    } on ArgumentError {
      // TODO: handle error
    }
  });
}
''',
    );
  }

  Future<void> test_no_fix_when_all_caught_by_supertype() async {
    await assertNoCorrection(r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

void f() {
  try {
    ^boom();
  } on FormatException {
    // handle
  } on Error {
    // handle
  }
}
''');
  }

  Future<void> test_inserts_before_rethrowing_supertype_clause() async {
    await assertHasCorrection(
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
int boom() {
  throw FormatException();
}

void f() {
  try {
    ^boom();
  } on ArgumentError {
    // handle
  } on Exception {
    rethrow;
  }
}
''',
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
int boom() {
  throw FormatException();
}

void f() {
  try {
    boom();
  } on ArgumentError {
    // handle
  } on FormatException {
    // TODO: handle error
  } on Exception {
    rethrow;
  }
}
''',
    );
  }
}

@reflectiveTest
class NotExhaustiveTryCatchDefaultFixTest extends CorrectionTest {
  @override
  ProducerGenerator get generator => NotExhaustiveTryCatchDefaultFix.new;

  Future<void> test_adds_object_clause() async {
    await assertHasCorrection(
      r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

void f() {
  try {
    ^boom();
  } on FormatException {
    // handle
  }
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
  } on FormatException {
    // handle
  } on Object {
    // TODO: handle error
  }
}
''',
    );
  }

  Future<void> test_no_fix_when_catch_all_exists() async {
    await assertNoCorrection(r'''import 'package:throws/throws.dart';

@Throws(errors: {FormatException, ArgumentError})
void boom() {
  throw FormatException();
}

void f() {
  try {
    ^boom();
  } catch (_) {
    // handle
  }
}
''');
  }
}
