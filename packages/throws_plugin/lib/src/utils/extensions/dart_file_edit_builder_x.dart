import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:throws_plugin/src/data/throws_annotation.dart';

extension DartFileEditBuilderX on DartFileEditBuilder {
  String importThrows({
    bool isCapitalized = true,
  }) => _importWithPrefix(
    isCapitalized ? ThrowsAnnotation.nameCapitalized : ThrowsAnnotation.name,
    [
      Uri(
        scheme: 'package',
        path: 'throws/throws.dart',
      ),
    ],
  );

  String _importWithPrefix(String name, List<Uri> uris) {
    for (var i = 0; i < uris.length - 1; i++) {
      final uri = uris[i];
      if (importsLibrary(uri)) return _buildImport(uri, name);
    }

    final lastUri = uris.last;
    return _buildImport(lastUri, name);
  }

  String _buildImport(Uri uri, String name) {
    final import = importLibraryElement(uri);

    final prefix = import.prefix;
    if (prefix != null) return '$prefix.$name';

    return name;
  }
}

/// Writes [types] separated by commas, importing them where needed.
void writeTypeList(DartEditBuilder builder, List<DartType> types) {
  for (var i = 0; i < types.length; i++) {
    if (i > 0) {
      builder.write(', ');
    }
    builder.writeType(types[i]);
  }
}

/// The `{...}` set literal passed as `errors:` to [annotation].
SetOrMapLiteral? errorsLiteral(Annotation annotation) {
  for (final argument in annotation.arguments?.arguments ?? const []) {
    if (argument is NamedArgument && argument.name.lexeme == 'errors') {
      final expression = argument.argumentExpression;
      return expression is SetOrMapLiteral ? expression : null;
    }
  }
  return null;
}

/// Appends [types] to the `errors:` [literal].
void addToErrorsLiteral(
  DartFileEditBuilder builder,
  SetOrMapLiteral literal,
  List<DartType> types,
) {
  final elements = literal.elements;
  builder.addInsertion(
    elements.isEmpty ? literal.leftBracket.end : elements.last.end,
    (builder) {
      if (elements.isNotEmpty) {
        builder.write(', ');
      }
      writeTypeList(builder, types);
    },
  );
}
