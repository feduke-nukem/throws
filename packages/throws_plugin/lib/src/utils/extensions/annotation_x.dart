import 'package:analyzer/dart/ast/ast.dart';
import 'package:throws_plugin/src/helpers.dart';

extension AnnotationX on Annotation {
  String? get maybeVerifiedName => switch (name) {
    SimpleIdentifier(:final name) => name,
    PrefixedIdentifier(:final identifier) => identifier.name,
    _ => null,
  };

  List<String> get expectedErrors {
    final arguments = this.arguments?.arguments;
    if (arguments == null || arguments.length < 2) {
      return const [];
    }

    final expected = arguments[1];
    if (expected is SetOrMapLiteral) {
      return expectedErrorsFromLiteralElements(expected.elements);
    }
    if (expected is ListLiteral) {
      return expectedErrorsFromLiteralElements(expected.elements);
    }
    return const [];
  }
}
