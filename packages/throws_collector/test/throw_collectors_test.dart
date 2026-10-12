import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:throws_collector/src/throw_collectors.dart';

import 'helpers.dart';

/// Errors found in the doc comment of the only function in [code].
Future<Set<String>> _docErrors(String code) async {
  final root = await createPackage({'a.dart': code});
  final result =
      await resolveFile(path: p.join(root, 'lib', 'a.dart'))
          as ResolvedUnitResult;
  final function = result.unit.declarations.whereType<FunctionDeclaration>();
  return errorsFromComment(function.single.documentationComment!);
}

void main() {
  group('errorsFromComment', () {
    test('takes resolved references in throwing sentences', () async {
      expect(
        await _docErrors('''
/// Returns the value.
///
/// Throws a [StateError] when empty. A [FormatException] is thrown
/// on bad input.
void f() {}
'''),
        {'StateError', 'FormatException'},
      );
    });

    test('takes errors that complete the returned future', () async {
      expect(
        await _docErrors('''
/// Completes the future with a [FormatException] if the input is bad.
/// The future may complete with a [StateError]. Fails with [ArgumentError].
void f() {}
'''),
        {'FormatException', 'StateError', 'ArgumentError'},
      );
    });

    test('ignores references outside throwing sentences', () async {
      expect(
        await _docErrors('''
/// Unlike [StateError], this never fails. See [ArgumentError].
void f() {}
'''),
        isEmpty,
      );
    });

    test('ignores unresolved names and code examples', () async {
      expect(
        await _docErrors('''
/// Throws [RetryException] or SomeException.
///
/// ```dart
/// throw StateError('x');
/// ```
void f() {}
'''),
        isEmpty,
      );
    });

    test('ignores types that are not errors or exceptions', () async {
      expect(
        await _docErrors('''
/// Throws a [String] message.
void f() {}
'''),
        isEmpty,
      );
    });

    test('accepts user error types', () async {
      expect(
        await _docErrors('''
class MyError extends Error {}

/// Throws [MyError] if called.
void f() {}
'''),
        {'MyError'},
      );
    });
  });
}
