import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';
import 'package:throws_collector/src/throw_collectors.dart';

Comment _docOf(String code) {
  final unit = parseString(content: code).unit;
  return (unit.declarations.first as FunctionDeclaration).documentationComment!;
}

void main() {
  group('errorsFromComment', () {
    test('finds Error and Exception type names', () {
      final comment = _docOf('''
/// Throws a [StateError] when empty and FormatException on bad input.
/// Mentions Errors and exceptions in prose.
void f() {}
''');
      expect(errorsFromComment(comment), {'StateError', 'FormatException'});
    });

    test('returns nothing for comments without errors', () {
      expect(
        errorsFromComment(_docOf('/// Plain docs.\nvoid f() {}')),
        isEmpty,
      );
    });
  });

  test('documentationCommentsParser strips the /// prefix', () {
    final comment = _docOf('/// first\n///\n/// second\nvoid f() {}');
    expect(documentationCommentsParser(comment.tokens), [
      ' first',
      '',
      ' second',
    ]);
    expect(documentationCommentsParser(null), isEmpty);
  });
}
