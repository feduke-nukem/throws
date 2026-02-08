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
    if (arguments == null || arguments.isEmpty) {
      return const [];
    }

    Expression? expected;
    for (final argument in arguments) {
      if (argument is NamedExpression &&
          (argument.name.label.name == 'errors')) {
        expected = argument.expression;
        break;
      }
    }

    expected ??= arguments.length >= 2 ? arguments[1] : null;
    if (expected == null) {
      return const [];
    }
    if (expected is SetOrMapLiteral) {
      return expectedErrorsFromLiteralElements(expected.elements);
    }
    if (expected is ListLiteral) {
      return expectedErrorsFromLiteralElements(expected.elements);
    }
    return const [];
  }
}
