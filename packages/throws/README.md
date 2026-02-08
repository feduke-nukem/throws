# throws

Annotations for documenting and enforcing throwing functions.

## Install

Add the dependency to your pubspec.yaml.

## Usage

Annotate functions that can throw:

```dart
@Throws('Parsing input failed', {FormatException, RangeError})
int parsePositiveInt(String input) {
	final value = int.parse(input);
	if (value < 0) {
		throw RangeError('Value must be non-negative');
	}
	return value;
}
```

You can also use the shorthand constant:

```dart
@throws
void mightThrow() {
	throw Exception('x');
}
```

## expectedErrors

Use expectedErrors to declare the error types callers should handle. This is a set of Type literals.

```dart
@Throws('Reason', {StateError})
int singleValue(Iterable<int> values) => values.single;
```