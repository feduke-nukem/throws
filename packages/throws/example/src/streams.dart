import 'package:throws/throws.dart';

@Throws(errors: {FormatException})
Stream<int> parseLines(List<String> lines) async* {
  for (final line in lines) {
    yield int.parse(line);
  }
}

Future<int> sum(List<String> lines) async {
  var total = 0;
  try {
    await for (final value in parseLines(lines)) {
      total += value;
    }
  } on FormatException {
    return -1;
  }
  return total;
}

// No onError: a bad line is an unhandled error.
void printAll(List<String> lines) {
  parseLines(lines).listen(print);
}

@Throws(errors: {FormatException})
Future<int> parseLater(String input) async => int.parse(input);

// Started now, awaited later: the try handles it.
Future<int> startEarly(String input) async {
  final pending = parseLater(input);
  try {
    return await pending;
  } on FormatException {
    return 0;
  }
}
