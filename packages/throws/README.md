# throws

![add_throws](https://github.com/user-attachments/assets/e46f89cd-5a7e-4217-80bf-f29d9820a10c)
![try_catch](https://github.com/user-attachments/assets/a55c2f57-2bf7-4842-b735-024cea3b61e3)


Annotations for documenting and enforcing throwing functions.

This package is the annotation layer. It works with:
- [throws_plugin](https://pub.dev/packages/throws_plugin): analyzer plugin that enforces annotations and call handling.
- [throws_collector](https://pub.dev/packages/throws_collector): optional heuristic tool that can generate maps for external APIs to improve plugin accuracy.

## Install

Add the dependency to your pubspec.yaml.

## Usage

Annotate functions that can throw:

```dart
@Throws(reason: 'Parsing input failed', errors: {FormatException, RangeError})
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

## Expected errors

Use errors to declare the error types callers should handle. This is a set of
Type literals.

```dart
@Throws(reason: 'Reason', errors: {StateError})
int singleValue(Iterable<int> values) => values.single;
```

## Examples

### Missing annotation

Bad (missing @Throws):

```dart
int parsePositiveInt(String input) {
  final value = int.parse(input);
  if (value < 0) {
    throw RangeError('Value must be non-negative');
  }
  return value;
}
```

Good:

```dart
@Throws(reason: 'Parsing input failed', errors: {RangeError})
int parsePositiveInt(String input) {
  final value = int.parse(input);
  if (value < 0) {
    throw RangeError('Value must be non-negative');
  }
  return value;
}
```

### Calling a throwing function without handling

Bad (no try/catch and no @Throws on caller):

```dart
@Throws(reason: 'May throw', errors: {StateError})
int singleValue(Iterable<int> values) => values.single;

int readOne(Iterable<int> values) {
  return singleValue(values);
}
```

Good (handle it):

```dart
@Throws(reason: 'May throw', errors: {StateError})
int singleValue(Iterable<int> values) => values.single;

int readOne(Iterable<int> values) {
  try {
    return singleValue(values);
  } on StateError {
    return -1;
  }
}
```

Good (or declare it):

```dart
@Throws(reason: 'May throw', errors: {StateError})
int singleValue(Iterable<int> values) => values.single;

@Throws(reason: 'Pass-through', errors: {StateError})
int readOne(Iterable<int> values) => singleValue(values);
```

### Annotation mismatch

Bad (declared errors do not match):

```dart
@Throws(reason: 'Wrong error set', errors: {ArgumentError})
void risky() {
  throw StateError('boom');
}
```

Good:

```dart
@Throws(reason: 'Right error set', errors: {StateError})
void risky() {
  throw StateError('boom');
}
```

## How it all works together

1. You annotate functions with @Throws or @throws.
2. throws_plugin inspects your code and:
   - Requires annotations on functions that throw.
   - Requires try/catch or annotations when calling throwing functions.
   - Validates that declared errors match what is thrown.
3. throws_plugin can also read a throws.yaml file at your package root to learn
   about throwing members outside your package (SDK or dependencies).
4. throws_collector can generate those maps, but it is optional and best-effort.

This package does not perform analysis itself. It only provides the annotations
and shared types for the plugin.
