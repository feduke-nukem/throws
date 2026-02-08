import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:throws_plugin/src/data/function_summary.dart';
import 'package:throws_plugin/src/data/inherited_throws_info.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';
import 'package:throws_plugin/src/sdk_throws_map.dart';
import 'package:throws_plugin/src/utils/extensions/annotation_x.dart';
import 'package:throws_plugin/src/utils/extensions/expression_x.dart';
import 'package:throws_plugin/src/utils/throws_body_visitor.dart';
import 'package:throws_plugin/src/utils/throws_expected_errors_collector.dart';

bool matchesAnnotation(FunctionSummary summary) {
  if (!summary.hasThrowsAnnotation) {
    return true;
  }
  if (summary.allowAnyExpectedErrors) {
    return true;
  }
  final actual = summary.thrownErrors.toSet();
  final expected = summary.annotatedExpectedErrors;
  return actual.length == expected.length && actual.every(expected.contains);
}

InheritedThrowsInfo collectInheritedThrowsInfo(ExecutableElement element) {
  final enclosing = element.enclosingElement;
  if (enclosing is! InterfaceElement) {
    return const InheritedThrowsInfo(
      hasAnnotatedSuper: false,
      allowAny: false,
      expectedErrors: {},
    );
  }

  final name = element.displayName;
  final expectedErrors = <String>{};
  var hasAnnotatedSuper = false;
  var allowAny = false;

  final candidates = <ExecutableElement>{};
  if (element is MethodElement) {
    final nameObj = Name.forLibrary(element.library, element.name ?? name);
    candidates.addAll(enclosing.getOverridden(nameObj) ?? const []);
  } else if (element is PropertyAccessorElement) {
    final nameObj = Name.forLibrary(element.library, element.name ?? name);
    candidates.addAll(enclosing.getOverridden(nameObj) ?? const []);
    candidates.addAll(enclosing.getOverridden(nameObj.forGetter) ?? const []);
    candidates.addAll(enclosing.getOverridden(nameObj.forSetter) ?? const []);
  }

  final types = <InterfaceType>{};
  types.addAll(enclosing.allSupertypes);
  types.addAll(enclosing.interfaces);
  if (enclosing.supertype != null) {
    types.add(enclosing.supertype!);
  }
  types.addAll(enclosing.mixins);
  for (final type in types) {
    final typeElement = type.element;
    if (element is MethodElement) {
      final targetName = element.name ?? name;
      final member = typeElement.getMethod(targetName);
      if (member != null) {
        candidates.add(member);
      } else {
        for (final candidate in typeElement.methods) {
          if (candidate.name == targetName) {
            candidates.add(candidate);
          }
        }
      }
    } else if (element is PropertyAccessorElement) {
      final isSetter = element.name?.endsWith('=') ?? false;
      final targetName = element.name ?? name;
      final member = isSetter
          ? typeElement.getSetter(targetName)
          : typeElement.getGetter(targetName);
      if (member != null) {
        candidates.add(member);
      } else {
        final list = isSetter ? typeElement.setters : typeElement.getters;
        for (final candidate in list) {
          if (candidate.name == targetName) {
            candidates.add(candidate);
          }
        }
      }
    }
  }

  for (final member in candidates) {
    if (_hasThrowsAnnotationOnElement(member)) {
      hasAnnotatedSuper = true;
      final errors = _expectedErrorsFromAnnotationElement(member);
      if (errors.isEmpty) {
        allowAny = true;
      } else {
        expectedErrors.addAll(errors);
      }
    }
  }

  return InheritedThrowsInfo(
    hasAnnotatedSuper: hasAnnotatedSuper,
    allowAny: allowAny,
    expectedErrors: expectedErrors,
  );
}

bool _hasThrowsAnnotationOnElement(ExecutableElement element) {
  return element.metadata.annotations.any(_isThrowsAnnotation);
}

Set<String> expectedErrorsFromElementOrSdk(Element? element) {
  final executable = element is ExecutableElement ? element : null;
  if (executable == null) {
    return const {};
  }

  final errors = _expectedErrorsFromAnnotationElement(executable);
  if (errors.isNotEmpty) {
    return errors.toSet();
  }

  final sdkErrors = sdkThrowsForElement(executable);
  if (sdkErrors == null) {
    return const {};
  }
  return sdkErrors.toSet();
}

List<String> _expectedErrorsFromAnnotationElement(ExecutableElement element) {
  for (final annotation in element.metadata.annotations) {
    if (_isThrowsAnnotation(annotation)) {
      final value = annotation.computeConstantValue();
      final errorsField = value?.getField('errors');
      final values = errorsField?.toSetValue();
      if (values == null) {
        return const [];
      }
      final names = <String>[];
      for (final entry in values) {
        final typeValue = entry.toTypeValue();
        final typeName = typeValue?.getDisplayString(withNullability: false);
        if (typeName != null) {
          names.add(typeName);
        }
      }
      return names;
    }
  }
  return sdkThrowsForElement(element) ?? const [];
}

String? _typeNameFromExpression(Expression expression) {
  if (expression is InstanceCreationExpression) {
    return expression.constructorName.type.name.lexeme;
  }
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
  if (expression is MethodInvocation && expression.target == null) {
    final name = expression.methodName.name;
    if (name.isNotEmpty && name[0] == name[0].toUpperCase()) {
      return name;
    }
  }
  if (expression is SimpleIdentifier) {
    return expression.name;
  }
  if (expression is PrefixedIdentifier) {
    return expression.identifier.name;
  }
  return null;
}

bool hasThrowsAnnotationOnNode(List<Annotation> metadata) {
  for (final annotation in metadata) {
    final name = annotation.maybeVerifiedName;
    if (name == ThrowsAnnotation.nameCapitalized ||
        name == ThrowsAnnotation.name) {
      return true;
    }
    final source = annotation.toSource();
    if (source.startsWith('@${ThrowsAnnotation.nameCapitalized}') ||
        source.startsWith('@${ThrowsAnnotation.name}')) {
      return true;
    }
  }
  return false;
}

List<String> expectedErrorsFromMetadata(List<Annotation> metadata) {
  for (final annotation in metadata) {
    final name = annotation.maybeVerifiedName;
    if (name == ThrowsAnnotation.nameCapitalized ||
        name == ThrowsAnnotation.name) {
      return annotation.expectedErrors;
    }
  }
  return const [];
}

bool isThrowsAnnotatedOrSdk(Element? element) {
  final executable = element is ExecutableElement ? element : null;
  if (executable == null) {
    return false;
  }

  if (executable.metadata.annotations.any(_isThrowsAnnotation)) {
    return true;
  }

  return isSdkThrowingElement(executable);
}

bool _isThrowsAnnotation(ElementAnnotation annotation) {
  final value = annotation.computeConstantValue();
  final type = value?.type;
  if (type?.element?.name == ThrowsAnnotation.nameCapitalized) {
    return true;
  }
  return annotation.element?.name == ThrowsAnnotation.name;
}

Set<String> expectedErrorsFromErrorThrowWithStackTrace(MethodInvocation node) {
  final typeName = typeNameFromErrorThrowWithStackTrace(node);
  if (typeName == null) {
    return const {};
  }
  return {typeName};
}

bool isAbstractOrExternalBody(FunctionBody body, Token? externalKeyword) {
  if (externalKeyword != null) {
    return true;
  }
  return body is EmptyFunctionBody;
}

String? typeNameFromErrorThrowWithStackTrace(MethodInvocation node) {
  final args = node.argumentList.arguments;
  if (args.isEmpty) {
    return null;
  }
  return _typeNameFromExpression(args.first);
}

bool needsThrowsAnnotation(FunctionBody body) {
  final visitor = ThrowsBodyVisitor();
  body.accept(visitor);
  return visitor.hasUnhandledThrow || visitor.hasUnhandledThrowingCall;
}

List<String> collectExpectedErrors(
  FunctionBody body, {
  required Map<Element, List<String>> localExpectedErrorsByElement,
}) {
  final collector = ThrowsExpectedErrorsCollector(
    localExpectedErrorsByElement: localExpectedErrorsByElement,
  );
  body.accept(collector);
  return collector.expectedErrors;
}

List<String> expectedErrorsFromLiteralElements(
  List<CollectionElement> elements,
) {
  final result = <String>[];
  for (final element in elements) {
    if (element is Expression) {
      final typeName = element.typeName;
      if (typeName != null) {
        result.add(typeName);
      }
    }
  }
  return result;
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
  if (target is Identifier && target.name == 'Error') {
    return true;
  }

  return false;
}

bool isCatchAllType(String typeName) {
  return typeName == 'Object' || typeName == 'dynamic';
}
