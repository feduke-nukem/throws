import 'package:throws/throws.dart';

@rethrows
T measure<T>(T Function() action) {
  final watch = Stopwatch()..start();
  try {
    return action();
  } finally {
    print(watch.elapsed);
  }
}

// The closure's FormatException is thrown by `measure`.
@Throws(errors: {FormatException})
int parseMeasured(String input) => measure(() => int.parse(input));

// `map` rethrows (prebuilt: [dart]), here with a tear-off: the caller must
// handle it.
List<int> parseAll(List<String> inputs) => inputs.map(int.parse).toList();

void onTap(void Function() callback) {}

// Nothing outside can catch errors of a closure passed to `onTap`.
void register(String input) {
  onTap(() => int.parse(input));
}
