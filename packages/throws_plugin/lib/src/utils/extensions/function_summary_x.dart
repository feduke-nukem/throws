import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:throws_plugin/src/data/function_summary.dart';
import 'package:throws_plugin/src/data/inherited_throws_info.dart';
import 'package:throws_plugin/src/helpers.dart';
import 'package:throws_plugin/src/utils/overriding_info_collector.dart';

extension FunctionSummaryX on FunctionSummary {
  InheritedThrowsInfo? get inheritedThrowsInfo {
    final summary = this;
    final element = summary.element;
    if (element is! ExecutableElement) {
      return null;
    }

    var info = collectInheritedThrowsInfo(element);
    if (!info.hasAnnotatedSuper) {
      info = _findUnitOverrideInfo();
    }
    return info.hasAnnotatedSuper ? info : null;
  }

  bool get hasAnnotatedSuper {
    final summary = this;

    final element = summary.element;
    if (element is! ExecutableElement) {
      return false;
    }
    final info = collectInheritedThrowsInfo(element);
    if (info.hasAnnotatedSuper) {
      return true;
    }
    return _findUnitOverrideInfo().hasAnnotatedSuper;
  }

  bool get isCoveredByInheritedThrows {
    final summary = this;
    final info = inheritedThrowsInfo;
    if (info == null) {
      return false;
    }
    if (info.allowAny) {
      return true;
    }
    if (summary.thrownErrors.isEmpty) {
      return false;
    }

    return summary.thrownErrors.every(info.expectedErrors.contains);
  }

  bool get introducesNewErrors {
    final summary = this;
    final info = inheritedThrowsInfo;
    if (info == null || info.allowAny) {
      return false;
    }
    if (summary.thrownErrors.isEmpty) {
      return false;
    }

    return summary.thrownErrors.any(
      (error) => !info.expectedErrors.contains(error),
    );
  }

  InheritedThrowsInfo _findUnitOverrideInfo() {
    final summary = this;
    final element = summary.element;
    if (element is! ExecutableElement) {
      return const InheritedThrowsInfo(
        hasAnnotatedSuper: false,
        allowAny: false,
        expectedErrors: {},
      );
    }

    final session = element.session;
    final library = element.library;
    if (session == null) {
      return const InheritedThrowsInfo(
        hasAnnotatedSuper: false,
        allowAny: false,
        expectedErrors: {},
      );
    }

    final parsed = session.getParsedLibraryByElement(library);
    if (parsed is! ParsedLibraryResult) {
      return const InheritedThrowsInfo(
        hasAnnotatedSuper: false,
        allowAny: false,
        expectedErrors: {},
      );
    }

    final collector = OverrideInfoCollector(summary.nameToken.lexeme);
    for (final unit in parsed.units) {
      unit.unit.accept(collector);
      if (collector.result.hasAnnotatedSuper) {
        break;
      }
    }
    return collector.result;
  }
}
