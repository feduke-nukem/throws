import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:throws_plugin/src/data/error_set.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';

/// Whether [annotation] is `@Throws(...)` or `@throws` from package:throws.
bool isThrowsAnnotation(ElementAnnotation annotation) =>
    _isThrowsPackageAnnotation(annotation, ThrowsAnnotation.nameCapitalized);

/// Whether [annotation] is `@rethrows` from package:throws.
bool isRethrowsAnnotation(ElementAnnotation annotation) =>
    _isThrowsPackageAnnotation(annotation, ThrowsAnnotation.rethrowsClass);

bool _isThrowsPackageAnnotation(ElementAnnotation annotation, String name) {
  final element = annotation.computeConstantValue()?.type?.element;
  if (element == null || element.name != name) {
    return false;
  }
  final uri = element.library?.uri;
  return uri != null &&
      uri.scheme == 'package' &&
      uri.pathSegments.isNotEmpty &&
      uri.pathSegments.first == 'throws';
}

/// The `@Throws`/`@throws` annotation node in [metadata], if any.
Annotation? findThrowsAnnotation(List<Annotation> metadata) {
  for (final annotation in metadata) {
    final element = annotation.elementAnnotation;
    if (element != null && isThrowsAnnotation(element)) {
      return annotation;
    }
  }
  return null;
}

bool hasThrowsAnnotationOnNode(List<Annotation> metadata) =>
    findThrowsAnnotation(metadata) != null;

/// Own `@Throws` contract of [element], or null if it is not annotated.
ThrowsContract? annotationContract(Element element) {
  for (final annotation in element.metadata.annotations) {
    if (!isThrowsAnnotation(annotation)) {
      continue;
    }
    final values =
        annotation.computeConstantValue()?.getField('errors')?.toSetValue() ??
        const {};
    return ThrowsContract({
      for (final value in values) ?value.toTypeValue(),
    });
  }
  return null;
}

/// Members that [element] overrides, from all supertypes.
Iterable<ExecutableElement> overriddenMembers(
  ExecutableElement element,
) sync* {
  final enclosing = element.enclosingElement;
  final name = element.name;
  if (enclosing is! InterfaceElement || name == null || element.isStatic) {
    return;
  }
  for (final type in enclosing.allSupertypes) {
    final member = switch (element) {
      MethodElement() => type.element.getMethod(name),
      GetterElement() => type.element.getGetter(name),
      SetterElement() => type.element.getSetter(name),
      _ => null,
    };
    if (member != null) {
      yield member;
    }
  }
}

/// Union of `@Throws` contracts on members that [element] overrides.
ThrowsContract? inheritedContract(ExecutableElement element) {
  Set<DartType>? errors;
  for (final member in overriddenMembers(element)) {
    final contract = annotationContract(member);
    if (contract == null) {
      continue;
    }
    if (contract.allowsAny) {
      return contract;
    }
    (errors ??= {}).addAll(contract.errors);
  }
  return errors == null ? null : ThrowsContract(errors);
}

bool isAbstractOrExternalBody(FunctionBody body, bool isExternal) {
  return isExternal || body is EmptyFunctionBody;
}

bool isErrorThrowWithStackTrace(MethodInvocation node) {
  if (node.methodName.name != 'throwWithStackTrace') {
    return false;
  }

  final element = node.methodName.element;
  if (element is ExecutableElement) {
    final enclosing = element.enclosingElement;
    if (enclosing is InterfaceElement && enclosing.name == 'Error') {
      return true;
    }
  }

  final target = node.target;
  return target is Identifier && target.name == 'Error';
}

/// Whether [clause] catches everything (`catch (e)`, `on Object`, `on dynamic`).
bool catchesAll(CatchClause clause) {
  final type = clause.exceptionType?.type;
  return type == null || type is DynamicType || type.isDartCoreObject;
}

/// Whether [clause] contains a `rethrow`, so it may not handle the error.
bool alwaysRethrows(CatchClause clause) {
  final finder = _RethrowFinder();
  clause.body.accept(finder);
  return finder.found;
}

class _RethrowFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitRethrowExpression(RethrowExpression node) {
    found = true;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Ignore nested functions.
  }
}
