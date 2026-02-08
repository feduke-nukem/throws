import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:throws_plugin/src/data/local_throwing_info.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/throws_body_visitor.dart';

extension CompilationUnitX on CompilationUnit {
  Map<String, List<String>> collectAnnotatedTopLevelFunctions() {
    final names = <String, List<String>>{};
    for (final declaration in declarations) {
      if (declaration is FunctionDeclaration) {
        if (hasThrowsAnnotationOnNode(declaration.metadata)) {
          names[declaration.name.lexeme] = expectedErrorsFromMetadata(
            declaration.metadata,
          );
        }
      }
    }
    return names;
  }

  LocalThrowingInfo collectLocalThrowingInfo() {
    final elements = <Element>{};
    final expectedErrorsByElement = <Element, List<String>>{};
    for (final declaration in declarations) {
      if (declaration is FunctionDeclaration) {
        final body = declaration.functionExpression.body;
        final visitor = ThrowsBodyVisitor();
        body.accept(visitor);
        if (visitor.hasUnhandledThrow || visitor.hasUnhandledThrowingCall) {
          final element = declaration.declaredFragment?.element;
          if (element != null) {
            final base = element.baseElement;
            elements.add(base);
            final expected = collectExpectedErrors(
              body,
              localExpectedErrorsByElement: const {},
            );
            expectedErrorsByElement[base] = expected;
          }
        }
      } else if (declaration is ClassDeclaration) {
        for (final member in declaration.members) {
          if (member is MethodDeclaration) {
            final visitor = ThrowsBodyVisitor();
            member.body.accept(visitor);
            if (visitor.hasUnhandledThrow || visitor.hasUnhandledThrowingCall) {
              final element = member.declaredFragment?.element;
              if (element != null) {
                final base = element.baseElement;
                elements.add(base);
                final expected = collectExpectedErrors(
                  member.body,
                  localExpectedErrorsByElement: const {},
                );
                expectedErrorsByElement[base] = expected;
              }
            }
          }
        }
      }
    }
    return LocalThrowingInfo(elements, expectedErrorsByElement);
  }
}
