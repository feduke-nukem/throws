import 'package:analyzer/dart/ast/ast.dart';

extension TypeAnnotationX on TypeAnnotation {
  String? get typeName {
    final type = this.type;
    if (type != null) {
      return type.getDisplayString(withNullability: false);
    }
    return toSource();
  }
}
