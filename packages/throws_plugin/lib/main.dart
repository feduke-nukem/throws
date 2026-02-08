import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/analyzer/throws_assists.dart';
import 'src/analyzer/throws_rules.dart';

final plugin = ThrowsAnalyzerPlugin();

class ThrowsAnalyzerPlugin extends Plugin {
  @override
  String get name => 'throws_plugin';

  @override
  void register(PluginRegistry registry) {
    for (final rule in throwsLintRules) {
      registry.registerLintRule(rule);
    }
    registry.registerAssist(AddThrowsAnnotationAssist.new);
    registry.registerAssist(RemoveThrowsAnnotationAssist.new);
    registry.registerAssist(WrapThrowsCallInTryCatchAssist.new);
    registry.registerAssist(UpdateThrowsAnnotationAssist.new);
  }
}
