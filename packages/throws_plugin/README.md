# throws_plugin

Analyzer plugin for @Throws/@throws usage.

## Install

Add the plugin dependency to your pubspec.yaml and enable it in analysis_options.yaml.

analysis_options.yaml:

```yaml
plugins:
  throws_plugin:
    version: any
    diagnostics:
      missing_throws_annotation: error
      unhandled_throws_call: error
      unused_throws_annotation: error
      introduced_throws_in_override: error
```

## Lints

- missing_throws_annotation: functions that throw must be annotated with @Throws/@throws
- unhandled_throws_call: calls to throwing functions must be handled or annotated
- unused_throws_annotation: @Throws on functions that do not throw

Diagnostics are reported at the call site for unhandled throws.

## Assists

- Add `@Throws` annotation
- Remove`@Throws` annotation
- Wrap in `try/catch` (with inferred expectedErrors when available)

## throws.yaml

Place throws.yaml at the package root to extend or override known throwing members.

```yaml
throws:
  useSdkMap: true
  map:
    dart:core.Iterable.single:
      - StateError
```

If useSdkMap is false, only entries from throws.yaml are used.
useSdkMap is heuristic only and comes with no guarantees of completeness or accuracy.
