import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';

/// Writes `on [type] {` with a TODO body selected as a linked edit. Without a
/// catch variable, so the generated code has no unused-variable warnings.
///
/// [index] keeps linked edit groups of several clauses apart.
void writeCatchClause(
  DartEditBuilder builder,
  DartType? type,
  String indent, {
  int index = 0,
}) {
  final group = 'HANDLE_$index';
  builder.write('on ');
  if (type == null) {
    builder.write('Object');
  } else {
    builder.writeType(type);
  }
  builder.writeln(' {');
  builder.write('$indent  ');
  builder.addSimpleLinkedEdit(group, '// TODO: handle error');
  builder.writeln();
  builder.write('$indent}');
}

/// [types] ordered so that subtypes come before their supertypes, as catch
/// clauses must be.
List<DartType> subtypesFirst(Iterable<DartType> types) {
  int depth(DartType type) =>
      type is InterfaceType ? type.allSupertypes.length : 0;
  return types.toList()..sort((a, b) {
    final byDepth = depth(b).compareTo(depth(a));
    return byDepth != 0
        ? byDepth
        : a.getDisplayString().compareTo(b.getDisplayString());
  });
}

/// The first clause of [statement] that would catch [type] before a clause
/// for [type] itself.
CatchClause? clauseCatching(
  TryStatement statement,
  DartType type,
  TypeSystem typeSystem,
) {
  for (final clause in statement.catchClauses) {
    final caught = clause.exceptionType?.type;
    if (caught == null || typeSystem.isSubtypeOf(type, caught)) {
      return clause;
    }
  }
  return null;
}
