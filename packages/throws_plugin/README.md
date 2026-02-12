# throws_plugin

Analyzer plugin for @Throws/@throws usage.

## Install

Add the plugin dependency to your pubspec.yaml and enable it in analysis_options.yaml.

analysis_options.yaml:

```yaml
plugins:
  throws_plugin:
    version: any
```

## What the plugin enforces

The plugin analyzes resolved AST and:
- Requires @Throws/@throws on functions that throw.
- Requires callers to handle throwing calls with try/catch or declare errors.
- Validates that declared errors match actual thrown errors.
- Accounts for overrides by walking the override chain.

## Lints

- missing_throws_annotation: functions that throw must be annotated with @Throws/@throws
- no_try_catch: calling a throwing function without a try/catch or annotation
- not_exhaustive_try_catch: try/catch does not cover all expected errors
- throws_annotation_mismatch: @Throws errors do not match actual thrown errors
- introduced_throws_in_override: overrides introduce new errors without annotation
- unused_throws_annotation: @Throws on functions that do not throw

Diagnostics are reported at the call site for unhandled throws.

## Assists and fixes

- Add @Throws or @throws annotations
- Wrap in try/catch with inferred errors
- Fixes for mismatch or missing annotations

## throws.yaml

Place throws.yaml at the package root to extend or override known throwing members.

```yaml
throws:
  include_prebuilt:
    - dart
    - flutter
  include_paths:
    - gen/flutter_errors.yaml
  custom_errors:
    dart:core.Iterable.single:
      - StateError
```

Notes:
- If include_prebuilt is empty, only entries from throws.yaml are used.
- Prebuilt maps are heuristic only and come with no guarantees of completeness
  or accuracy.
- include_paths may point to YAML files or directories containing YAML files
  (only .yaml/.yml files are read).
- Included files may contain a top-level map or a nested throws/map section.

## How errors are resolved

When evaluating a call, the plugin resolves expected errors in this order:
1. @Throws/@throws on the target element.
2. throws.yaml maps (custom_errors and include_paths).
3. Prebuilt maps (dart/flutter) if enabled.
4. Overrides (walks the override chain until a throwing element is found).

If none are found, the call is treated as non-throwing.

## Limitations

- Analysis is best-effort and depends on available type information.
- SDK/dependency coverage depends on map data (prebuilt or collected).
