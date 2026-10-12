import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';

/// Writes `on [type] {` with a TODO body. Without a catch variable, so the
/// generated code has no unused-variable warnings.
void writeCatchClause(
  DartEditBuilder builder,
  DartType? type,
  String indent,
) {
  builder.write('on ');
  if (type == null) {
    builder.write('Object');
  } else {
    builder.writeType(type);
  }
  builder.writeln(' {');
  builder.writeln('$indent  // TODO: handle error');
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
