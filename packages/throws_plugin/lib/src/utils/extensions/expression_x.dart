import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:throws_plugin/src/utils/extensions/compilation_unit_x.dart';
import 'package:throws_plugin/src/utils/throws_invocation_finder.dart';

extension ExpressionX on Expression {
  List<String>? expectedErrors(CompilationUnit unit) {
    final localInfo = unit.collectLocalThrowingInfo();
    final finder = ThrowsInvocationFinder(
      unit.collectAnnotatedTopLevelFunctions(),
      localInfo.elements,
      localInfo.expectedErrorsByElement,
    );
    accept(finder);
    return finder.expectedErrors;
  }

  String? get typeName {
    final expression = this;

    if (expression is TypeLiteral) {
      return expression.type.toSource();
    }
    if (expression is SimpleIdentifier) {
      final element = expression.element;
      if (element is ClassElement ||
          element is TypeAliasElement ||
          element is EnumElement ||
          element is ExtensionTypeElement) {
        return expression.name;
      }
    }
    if (expression is PrefixedIdentifier) {
      final element = expression.identifier.element;
      if (element is ClassElement ||
          element is TypeAliasElement ||
          element is EnumElement ||
          element is ExtensionTypeElement) {
        return expression.identifier.name;
      }
    }
    final staticType = expression.staticType;
    final staticName = staticType?.getDisplayString(withNullability: false);
    if (staticName != null && staticName != 'dynamic') {
      return staticName;
    }
    if (expression is SimpleIdentifier) {
      return expression.name;
    }
    if (expression is PrefixedIdentifier) {
      return expression.identifier.name;
    }
    return null;
  }
}
