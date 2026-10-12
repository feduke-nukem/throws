import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:throws_plugin/src/utils/analysis_cache.dart';

/// Adds `await` to a future-returning call inside try/catch in an async
/// function, so the try/catch handles its errors.
class AddAwaitFix extends ResolvedCorrectionProducer {
  static const FixKind _fixKind = FixKind(
    'throws.fix.addAwait',
    DartFixKindPriority.standard + 1,
    "Add 'await'",
  );

  AddAwaitFix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final analysis = AnalysisCache.analysis(unit);
    final summary = analysis.summaries
        .where((summary) => summary.body.isAsynchronous)
        .where((summary) => summary.sitesWithin(node).isNotEmpty)
        .firstOrNull;
    final site = summary?.sites
        .where((site) => site.isUnawaitedFuture && site.node == node)
        .firstOrNull;
    if (summary == null || site == null) {
      return;
    }

    final call = _futureExpression(node);
    if (call == null || !_isInTryWithCatch(call, summary.body)) {
      return;
    }
    final parent = call.parent;
    // `await f().then(...)` would await the chain, not `f()`.
    if ((parent is MethodInvocation && parent.target == call) ||
        (parent is PropertyAccess && parent.target == call)) {
      return;
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(call.offset, 'await ');
    });
  }

  /// The call expression around the reported [node] that returns a future.
  static Expression? _futureExpression(AstNode node) {
    for (
      AstNode? current = node;
      current is Expression;
      current = current.parent
    ) {
      final type = current.staticType;
      if (type != null &&
          (type.isDartAsyncFuture || type.isDartAsyncFutureOr)) {
        return current;
      }
    }
    return null;
  }

  static bool _isInTryWithCatch(AstNode node, FunctionBody body) {
    for (
      var current = node.parent;
      current != null && current != body;
      current = current.parent
    ) {
      if (current is TryStatement &&
          current.catchClauses.isNotEmpty &&
          node.offset >= current.body.offset &&
          node.end <= current.body.end) {
        return true;
      }
    }
    return false;
  }
}
