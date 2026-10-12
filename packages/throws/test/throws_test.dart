import 'package:test/test.dart' hide Throws, throws;
import 'package:throws/throws.dart';

void main() {
  test('throws allows any error', () {
    expect(throws.reason, isNull);
    expect(throws.errors, isEmpty);
  });

  test('Throws keeps reason and errors', () {
    const annotation = Throws(
      reason: 'bad input',
      errors: {FormatException, RangeError},
    );
    expect(annotation.reason, 'bad input');
    expect(annotation.errors, {FormatException, RangeError});
  });
}
