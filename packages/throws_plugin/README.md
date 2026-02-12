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

## Lints

- missing_throws_annotation: functions that throw must be annotated with @Throws/@throws
- unhandled_throws_call: calls to throwing functions must be handled or annotated
- unused_throws_annotation: @Throws on functions that do not throw

Diagnostics are reported at the call site for unhandled throws.

## Assists

- Add `@Throws` annotation
- Remove`@Throws` annotation
- Wrap in `try/catch` (with inferred errors when available)

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

If include_prebuilt is empty, only entries from throws.yaml are used.
Prebuilt maps are heuristic only and come with no guarantees of completeness or accuracy.

You can also include additional YAML sources (like the output from throws_collector).
Included files may contain a top-level map or a nested throws/map section.
