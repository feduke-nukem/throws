import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:throws_plugin/src/data/inherited_throws_info.dart';
import 'package:throws_plugin/src/helpers.dart';

class OverrideInfoCollector extends RecursiveAstVisitor<void> {
  final String _memberName;
  InheritedThrowsInfo _result = const InheritedThrowsInfo(
    hasAnnotatedSuper: false,
    allowAny: false,
    expectedErrors: {},
  );

  OverrideInfoCollector(this._memberName);

  InheritedThrowsInfo get result => _result;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        if (member.name.lexeme == _memberName &&
            hasThrowsAnnotationOnNode(member.metadata) &&
            member.body is EmptyFunctionBody) {
          final errors = expectedErrorsFromMetadata(member.metadata);
          if (errors.isEmpty) {
            _result = const InheritedThrowsInfo(
              hasAnnotatedSuper: true,
              allowAny: true,
              expectedErrors: {},
            );
          } else {
            _result = InheritedThrowsInfo(
              hasAnnotatedSuper: true,
              allowAny: false,
              expectedErrors: errors.toSet(),
            );
          }
        }
      }
    }
    super.visitClassDeclaration(node);
  }
}
