part of '../throws_assists.dart';

class UpdateThrowsAnnotationAssist extends ResolvedCorrectionProducer {
  static const AssistKind _assistKind = AssistKind(
    'throws.assist.updateThrowsAnnotation',
    30,
    'Update @Throws expectedErrors',
  );

  UpdateThrowsAnnotationAssist({required super.context});

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
      Annotation? annotation;
      for (final entry in metadata) {
        final name = _annotationName(entry);
        if (name == 'Throws' || name == 'throws') {
          annotation = entry;
          break;
        }
      }
      if (annotation == null || annotation.isSynthetic) {
        return;
      }
      final targetAnnotation = annotation;

      final body = _getFunctionBody(functionNode);
      if (body == null) {
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
      if (expectedErrors.isEmpty) {
        return;
      }

      await builder.addDartFileEdit(file, (builder) {
        final arguments = targetAnnotation.arguments?.arguments ?? const [];
        if (arguments.isNotEmpty) {
          NamedExpression? namedExpected;
          for (final argument in arguments) {
            if (argument is NamedExpression &&
                argument.name.label.name == 'expectedErrors') {
              namedExpected = argument;
              break;
            }
          }
          if (namedExpected != null) {
            builder.addSimpleReplacement(
              range.node(namedExpected.expression),
              '{${expectedErrors.join(', ')}}',
            );
            return;
          }

          if (arguments.length >= 2) {
            builder.addSimpleReplacement(
              range.node(arguments[1]),
              '{${expectedErrors.join(', ')}}',
            );
            return;
          }

          builder.addInsertion(arguments.last.end, (builder) {
            builder.write(', {${expectedErrors.join(', ')}}');
          });
          return;
        }

        builder.addSimpleReplacement(
          range.node(targetAnnotation),
          '@Throws(\'reason\', {${expectedErrors.join(', ')}})',
        );
      });
    } catch (_) {
      return;
    }
  }
}
