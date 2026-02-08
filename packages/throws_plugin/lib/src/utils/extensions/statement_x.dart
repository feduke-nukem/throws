import 'package:analyzer/dart/ast/ast.dart';

extension StatementX on Statement {
  Expression? get expression => switch (this) {
    ExpressionStatement(:final expression) => expression,
    ReturnStatement(:final expression) => expression,
    VariableDeclarationStatement(:final variables)
        when variables.variables.length == 1 =>
      variables.variables.first.initializer,
    _ => null,
  };
}
