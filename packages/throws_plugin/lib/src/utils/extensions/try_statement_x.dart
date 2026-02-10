import 'package:analyzer/dart/ast/ast.dart';
import 'package:throws_plugin/src/utils/extensions/type_annotation_x.dart';
import 'package:throws_plugin/src/utils/throw_finder.dart';

extension TryStatementX on TryStatement {
  bool get providesHandling {
    if (catchClauses.isEmpty) {
      return false;
    }

    for (final clause in catchClauses) {
      if (!_catchAlwaysRethrows(clause)) {
        return true;
      }
    }
    return false;
  }

  bool catchesAllExpected(Set<String> expectedErrors) {
    if (catchClauses.isEmpty) {
      return false;
    }

    final covered = <String>{};

    for (final clause in catchClauses) {
      final typeName = clause.exceptionType?.typeName;
      if (typeName == null) {
        return true;
      }
      if (typeName == 'Object' || typeName == 'dynamic') {
        return true;
      }

      covered.add(typeName);
    }

    return expectedErrors.every(covered.contains);
  }

  Set<String> handledErrors(Set<String> expectedErrors) {
    if (catchClauses.isEmpty || expectedErrors.isEmpty) {
      return const {};
    }

    final handled = <String>{};

    for (final clause in catchClauses) {
      if (_catchAlwaysRethrows(clause)) {
        continue;
      }

      final typeName = clause.exceptionType?.typeName;
      if (typeName == null || typeName == 'Object' || typeName == 'dynamic') {
        return expectedErrors.toSet();
      }

      if (expectedErrors.contains(typeName)) {
        handled.add(typeName);
      }
    }

    return handled;
  }
}

bool _catchAlwaysRethrows(CatchClause clause) {
  final visitor = RethrowFinder();
  clause.body.accept(visitor);
  return visitor.foundRethrow;
}
