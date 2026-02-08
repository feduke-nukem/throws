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
    print(delegatedParse('7'));
  }
}

void main() {
  try {
    print(delegatedParse('7'));
  } on RangeError catch (e, stackTrace) {
    // TODO: handle error
  } on Object catch (e, stackTrace) {
    // TODO: handle error
  }
}

int getSingle() {
  final list = [];

  return list.single;
}

@Throws(errors: {Exception})
int errorThrowWithStackTrace() {
  Error.throwWithStackTrace(Exception(), StackTrace.current);
}

@Throws(errors: {ArgumentError})
int throwing() {
  throw ArgumentError();
}
