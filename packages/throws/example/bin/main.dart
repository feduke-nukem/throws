import 'package:throws/throws.dart';

@Throws('reason', {RangeError})
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

@Throws('Delegates to parsePositiveInt', {RangeError})
int delegatedParse(String input) {
  return parsePositiveInt(input);
}

abstract interface class A {
  @Throws('', {ArgumentError})
  void doSome();
}

class B implements A {
  @override
  void doSome() {
    try {
      print(delegatedParse('7'));
    } on FormatException catch (e, stackTrace) {
      // TODO: handle error
    } on RangeError catch (e, stackTrace) {}
  }
}

@Throws('', {ArgumentError})
void main() {
  try {
    print(delegatedParse('7'));
  } catch (e, stackTrace) {
    throw ArgumentError();
  }
}

int getSingle() {
  final list = [];

  return list.single;
}

@Throws('reason', {Exception})
int errorThrowWithStackTrace() {
  Error.throwWithStackTrace(Exception(), StackTrace.current);
}

@Throws('reason', {ArgumentError})
int throwing() {
  throw ArgumentError();
}
