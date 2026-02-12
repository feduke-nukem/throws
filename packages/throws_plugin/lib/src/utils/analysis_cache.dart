import 'package:analyzer/dart/ast/ast.dart';
import 'package:throws_plugin/src/data/function_summary.dart';
import 'package:throws_plugin/src/data/local_throwing_info.dart';
import 'package:throws_plugin/src/utils/extensions/compilation_unit_x.dart';
import 'package:throws_plugin/src/utils/throws_analyzer.dart';

class AnalysisCache {
  static final Expando<List<FunctionSummary>> _summaries = Expando();
  static final Expando<LocalThrowingInfo> _localInfo = Expando();

  static List<FunctionSummary> throwsSummaries(CompilationUnit unit) {
    final cached = _summaries[unit];
    if (cached != null) {
      return cached;
    }
    final summaries = ThrowsAnalyzer().analyze(unit);
    _summaries[unit] = summaries;
    return summaries;
  }

  static LocalThrowingInfo localThrowingInfo(CompilationUnit unit) {
    final cached = _localInfo[unit];
    if (cached != null) {
      return cached;
    }
    final localInfo = unit.collectLocalThrowingInfo();
    _localInfo[unit] = localInfo;
    return localInfo;
  }
}
