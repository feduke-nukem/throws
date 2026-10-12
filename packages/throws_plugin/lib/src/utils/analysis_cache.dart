import 'package:analyzer/dart/ast/ast.dart';
import 'package:throws_plugin/src/utils/throws_analyzer.dart';

class AnalysisCache {
  static final Expando<ThrowsAnalysis> _analyses = Expando();

  /// Analysis of [unit], shared by all lints and fixes.
  static ThrowsAnalysis analysis(CompilationUnit unit) =>
      _analyses[unit] ??= ThrowsAnalyzer.analyze(unit);
}
