import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:throws_plugin/src/assists/add_empty_throws_annotation.dart';
import 'package:throws_plugin/src/assists/add_throws_annotation.dart';
import 'package:throws_plugin/src/assists/specify_throws_errors.dart';
import 'package:throws_plugin/src/fixes/add_await_fix.dart';
import 'package:throws_plugin/src/fixes/add_to_overridden_throws_fix.dart';
import 'package:throws_plugin/src/fixes/add_to_throws_annotation_fix.dart';
import 'package:throws_plugin/src/fixes/missing_throws_annotation_fix.dart';
import 'package:throws_plugin/src/fixes/throws_annotation_mismatch_fix.dart';

import 'src/lints/introduced_throws_in_override.dart';
import 'src/lints/missing_throws_annotation.dart';
import 'src/lints/no_try_catch.dart';
import 'src/lints/no_try_catch_in_closure.dart';
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
    registry.registerFixForRule(NoTryCatch.code, AddAwaitFix.new);
    registry.registerFixForRule(NoTryCatch.code, AnnotateCallerFix.new);
    registry.registerFixForRule(
      NoTryCatch.code,
      AddToThrowsAnnotationFix.new,
    );

    registry.registerWarningRule(NoTryCatchInClosure());
    registry.registerFixForRule(
      NoTryCatchInClosure.code,
      NoTryCatchWithDefaultFix.new,
    );
    registry.registerFixForRule(NoTryCatchInClosure.code, NoTryCatchFix.new);
    registry.registerFixForRule(NoTryCatchInClosure.code, AddAwaitFix.new);

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
      AddToThrowsAnnotationFix.new,
    );

    registry.registerWarningRule(ThrowsAnnotationMismatch());
    registry.registerFixForRule(
      ThrowsAnnotationMismatch.code,
      ThrowsAnnotationMismatchFix.new,
    );

    registry.registerWarningRule(IntroducedThrowsInOverride());
    registry.registerFixForRule(
      IntroducedThrowsInOverride.code,
      AddToOverriddenThrowsFix.new,
    );
    registry.registerFixForRule(
      IntroducedThrowsInOverride.code,
      NoTryCatchFix.new,
    );

    registry.registerWarningRule(UnusedThrowsAnnotation());
    registry.registerFixForRule(
      UnusedThrowsAnnotation.code,
      UnusedThrowsAnnotationFix.new,
    );

    registry.registerAssist(AddThrowsAnnotationAssist.new);
    registry.registerAssist(AddEmptyThrowsAnnotationAssist.new);
    registry.registerAssist(SpecifyThrowsErrorsAssist.new);
  }
}
