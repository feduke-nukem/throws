import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/assists/add_throws_annotation_assist.dart';
import 'src/assists/remove_throws_annotation_assist.dart';
import 'src/assists/update_throws_annotation_assist.dart';
import 'src/assists/wrap_throws_call_in_try_catch_assist.dart';
import 'src/lints/introduced_throws_in_override_rule.dart';
import 'src/lints/missing_error_handling_rule.dart';
import 'src/lints/missing_throws_annotation_rule.dart';
import 'src/lints/throws_annotation_mismatch_rule.dart';
import 'src/lints/unused_throws_annotation_rule.dart';

final plugin = ThrowsAnalyzerPlugin();

class ThrowsAnalyzerPlugin extends Plugin {
  @override
  String get name => 'throws_plugin';

  @override
  void register(PluginRegistry registry) {
    registry.registerLintRule(MissingThrowsAnnotationRule());
    registry.registerLintRule(MissingErrorHandlingRule());
    registry.registerLintRule(ThrowsAnnotationMismatchRule());
    registry.registerLintRule(IntroducedThrowsInOverrideRule());
    registry.registerLintRule(UnusedThrowsAnnotationRule());
    registry.registerAssist(AddThrowsAnnotationAssist.new);
    registry.registerAssist(RemoveThrowsAnnotationAssist.new);
    registry.registerAssist(WrapThrowsCallInTryCatchAssist.new);
    registry.registerAssist(UpdateThrowsAnnotationAssist.new);
  }
}
