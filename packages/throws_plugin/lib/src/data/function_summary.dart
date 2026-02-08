import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';

class FunctionSummary {
  final Token nameToken;
  final FunctionBody body;
  final bool hasThrowsAnnotation;
  final Set<String> annotatedExpectedErrors;
  final bool allowAnyExpectedErrors;
  final bool isAbstractOrExternal;
  final Set<String> thrownErrors = {};
  Element? element;
  bool hasUnhandledThrow = false;
  bool hasUnhandledThrowingCall = false;
  final List<AstNode> unhandledThrowingCallNodes = [];

  FunctionSummary({
    required this.nameToken,
    required this.body,
    required this.hasThrowsAnnotation,
    required this.annotatedExpectedErrors,
    required this.allowAnyExpectedErrors,
    required this.isAbstractOrExternal,
  });
}
