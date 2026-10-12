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

Assists:
- Add `@Throws()` or `@throws` to a function.

Fixes:
- `missing_throws_annotation`: add `@Throws` with the inferred errors.
- `throws_annotation_mismatch`: update `@Throws` errors.
- `unused_throws_annotation`: remove the annotation.
- `no_try_catch`:
  - wrap the statement in try/catch, with a clause per error or one `on Object`
    clause (`final x = call();` becomes `late final T x; try { x = call(); }`);
  - add `await` to a future-returning call inside try/catch;
  - add the errors to the enclosing `@Throws`, or annotate the enclosing
    function.
- `not_exhaustive_try_catch`: add the missing catch clauses (subtypes before
  supertypes), a default `on Object` clause, or add the errors to `@Throws`.

The annotation fixes for `missing_throws_annotation`,
`throws_annotation_mismatch` and `unused_throws_annotation` can be applied to
every diagnostic in a file at once ("fix all in file" in the IDE). `dart fix`
does not apply analyzer plugin fixes.

## throws.yaml

Place throws.yaml at the package root to declare errors of members outside your
package (SDK or dependencies).

```yaml
throws:
  # Errors to check: exception (subtypes of Exception), error (subtypes of
  # Error), or both (default). Types that are neither are always checked.
  track: [exception, error]

  # Bundled maps: dart, flutter. Off by default.
  prebuilt: [dart]

  # YAML files, or directories of them, in the same format as `members`
  # (e.g. throws_collector output).
  include:
    - throws_collector_gen/

  # Library URI, then member: errors (a name or a list).
  members:
    dart:core:
      Iterable.single: [StateError]
      int.parse: FormatException
    package:http/http.dart:
      get: [ClientException]
      Client.new: [ArgumentError]
```

Member names follow Dart tear-off syntax: `function` for top-level functions,
`Class.member` for methods, getters and setters, `Class.new` and
`Class.named` for constructors.

Notes:
- Prebuilt maps are heuristic only and come with no guarantees of completeness
  or accuracy.
- Entries from `members` and `include` take precedence over prebuilt maps.
- Unknown keys are ignored. Version 1 keys (`include_prebuilt`,
  `include_paths`, `custom_errors`, `include_sdk_errors`) are no longer read.

## How errors are resolved

When evaluating a call, the plugin resolves expected errors in this order:
1. @Throws/@throws on the target element.
2. throws.yaml (`members` and `include`).
3. Prebuilt maps (dart/flutter) if enabled.
4. Overrides (walks the override chain until a throwing element is found).

If none are found, the call is treated as non-throwing.

Errors are compared as types, including subtypes: `on Exception` handles a
call that throws `FormatException`, and `@Throws(errors: {Exception})` covers a
thrown `FormatException`. Names from throws.yaml and prebuilt maps are resolved
in the scope of the library that declares the member; unresolved names count as
an unknown error, which any catch clause handles.

## Futures

Errors of a call that returns a `Future` arrive asynchronously:
- a surrounding try/catch handles them only if the call is awaited
  (`await f()`, `await Future.wait([f()])`);
- `.catchError`, `.ignore()` and `.then(..., onError: ...)` handle all of them,
  `.onError<E>` handles subtypes of `E`.

A future stored in a variable and awaited later is not tracked.

## Limitations

- Casts (`as`) and null checks (`!`) are not treated as throwing: they throw
  `TypeError`, a programming error.
- A `catch` that may `rethrow` (even conditionally) does not count as handling.

- Analysis is best-effort and depends on available type information.
- SDK/dependency coverage depends on map data (prebuilt or collected).
