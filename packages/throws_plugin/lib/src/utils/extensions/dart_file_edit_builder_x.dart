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
