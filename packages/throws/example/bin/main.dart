import 'package:throws/throws.dart';

@Throws('Parsing input failed', {FormatException, RangeError})
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

@Throws('Delegates to parsePositiveInt', {FormatException, RangeError})
int delegatedParse(String input) {
  return parsePositiveInt(input);
}

void main() {
  print(parsePositiveInt('42'));
  print(safeParsePositiveInt('oops'));
  print(delegatedParse('7'));
}
