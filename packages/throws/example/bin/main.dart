import 'dart:math';

import 'package:throws/throws.dart';

@Throws(errors: {RangeError})
int parsePositiveInt(String input) {
  final value = int.parse(input);
  if (value < 0) {
    throw RangeError('Value must be non-negative');
  }

  return value;
}

int safeParsePositiveInt(String input) {
  try {
    return parsePositiveInt(input);
  } catch (_) {
    return 0;
  }
}

@Throws(reason: 'Delegates to parsePositiveInt', errors: {RangeError})
int delegatedParse(String input) {
  return parsePositiveInt(input);
}

abstract interface class A {
  @Throws(errors: {ArgumentError})
  void doSome();
}

class B implements A {
  @override
  void doSome() {
    try {
      throwing();
    } on ArgumentError catch (e, stackTrace) {
      // TODO: handle error
    } on Exception catch (e, stackTrace) {}
  }
}

@Throws(errors: {Exception})
void main() {
  try {
    throwing();
  } on ArgumentError catch (e, stackTrace) {
    // TODO: handle error
  } on Exception catch (e, stackTrace) {}
}

int getSingle() {
  final list = [];

  return list.single;
}

@Throws(errors: {Exception})
int errorThrowWithStackTrace() {
  Error.throwWithStackTrace(Exception(), StackTrace.current);
}

@Throws(errors: {ArgumentError, Exception})
int throwing() {
  if (Random().nextBool()) throw ArgumentError();

  throw Exception();
}
