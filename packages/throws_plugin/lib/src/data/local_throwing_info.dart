import 'package:analyzer/dart/element/element.dart';

class LocalThrowingInfo {
  final Set<Element> elements;
  final Map<Element, List<String>> expectedErrorsByElement;

  LocalThrowingInfo(this.elements, this.expectedErrorsByElement);
}
