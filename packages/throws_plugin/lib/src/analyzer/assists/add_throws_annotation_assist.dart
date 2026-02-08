part of '../throws_assists.dart';

class AddThrowsAnnotationAssist extends ResolvedCorrectionProducer {
  static const AssistKind _assistKind = AssistKind(
    'throws.assist.addThrowsAnnotation',
    30,
    'Add @throws annotation',
  );

  AddThrowsAnnotationAssist({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _assistKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    try {
      final functionNode = _findEnclosingFunction(node);
      if (functionNode == null) {
        return;
      }

      final metadata = _getMetadata(functionNode);
      if (_hasThrowsAnnotationOnNode(metadata)) {
        return;
      }

      final body = _getFunctionBody(functionNode);
      if (body == null || !_needsThrowsAnnotation(body)) {
        return;
      }

      final unit = functionNode.thisOrAncestorOfType<CompilationUnit>();
      if (unit == null) {
        return;
      }
      final localInfo = _collectLocalThrowingInfo(unit);
      final expectedErrors = _collectExpectedErrors(
        body,
        localExpectedErrorsByElement: localInfo.expectedErrorsByElement,
      );

      final offset = _annotationInsertOffset(functionNode, metadata);
      await builder.addDartFileEdit(file, (builder) {
        builder.addInsertion(offset, (builder) {
          if (expectedErrors.isNotEmpty) {
            builder.write(
              '@Throws(\'reason\', {',
            );
            builder.write(expectedErrors.join(', '));
            builder.write('})');
          } else {
            builder.write('@throws');
          }
          builder.writeln();
        });
      });
    } catch (_) {
      return;
    }
  }
}
