part of '../throws_assists.dart';

class RemoveThrowsAnnotationAssist extends ResolvedCorrectionProducer {
  static const AssistKind _assistKind = AssistKind(
    'throws.assist.removeThrowsAnnotation',
    30,
    'Remove @Throws annotation',
  );

  RemoveThrowsAnnotationAssist({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _assistKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    try {
      final annotation = _findThrowsAnnotation(node);
      if (annotation == null || annotation.isSynthetic) {
        return;
      }

      await builder.addDartFileEdit(file, (builder) {
        builder.addDeletion(range.node(annotation));
      });
    } catch (_) {
      return;
    }
  }
}
