import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:throws_plugin/src/assists/add_empty_throws_annotation.dart';
import 'package:throws_plugin/src/assists/add_throws_annotation.dart';
import 'package:throws_plugin/src/fixes/missing_throws_annotation_fix.dart';
import 'package:throws_plugin/src/fixes/throws_annotation_mismatch_fix.dart';

import 'src/lints/introduced_throws_in_override.dart';
import 'src/lints/missing_throws_annotation.dart';
import 'src/lints/no_try_catch.dart';
import 'src/lints/not_exhaustive_try_catch.dart';
import 'src/lints/throws_annotation_mismatch.dart';
import 'src/lints/unused_throws_annotation.dart';

final plugin = ThrowsAnalyzerPlugin();

class ThrowsAnalyzerPlugin extends Plugin {
  @override
  String get name => 'throws_plugin';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(MissingThrowsAnnotation());
    registry.registerFixForRule(
      MissingThrowsAnnotation.code,
      MissingThrowsAnnotationFix.new,
    );

    registry.registerWarningRule(NoTryCatch());
    registry.registerFixForRule(
      NoTryCatch.code,
      NoTryCatchWithDefaultFix.new,
    );
    registry.registerFixForRule(
      NoTryCatch.code,
      NoTryCatchFix.new,
    );
    registry.registerFixForRule(
      NoTryCatch.code,
      MissingThrowsAnnotationFix.new,
    );
    registry.registerFixForRule(
      NoTryCatch.code,
      ThrowsAnnotationMismatchFix.new,
    );

    registry.registerWarningRule(NotExhaustiveTryCatch());
    registry.registerFixForRule(
      NotExhaustiveTryCatch.code,
      NotExhaustiveTryCatchDefaultFix.new,
    );
    registry.registerFixForRule(
      NotExhaustiveTryCatch.code,
      NotExhaustiveTryCatchFix.new,
    );
    registry.registerFixForRule(
      NotExhaustiveTryCatch.code,
      ThrowsAnnotationMismatchFix.new,
    );

    registry.registerWarningRule(ThrowsAnnotationMismatch());
    registry.registerFixForRule(
      ThrowsAnnotationMismatch.code,
      ThrowsAnnotationMismatchFix.new,
    );

    registry.registerWarningRule(IntroducedThrowsInOverride());

    registry.registerWarningRule(UnusedThrowsAnnotation());
    registry.registerFixForRule(
      UnusedThrowsAnnotation.code,
      UnusedThrowsAnnotationFix.new,
    );

    registry.registerAssist(AddThrowsAnnotationAssist.new);
    registry.registerAssist(AddEmptyThrowsAnnotationAssist.new);
  }
}
