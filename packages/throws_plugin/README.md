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
- no_try_catch_in_closure: calling a throwing function in a closure whose
  errors nothing outside can catch (not passed to a `@rethrows` function)
- not_exhaustive_try_catch: try/catch does not cover all expected errors
- throws_annotation_mismatch: @Throws errors do not match actual thrown errors
- introduced_throws_in_override: overrides introduce new errors without annotation
- unused_throws_annotation: @Throws on functions that do not throw

Diagnostics are reported at the call site for unhandled throws.

## Assists and fixes

Assists:
- Add `@Throws()` or `@throws` to a function.
- Specify errors: turn `@throws` / `@Throws()` into `@Throws(errors: {...})`
  with the errors the function throws.

Fixes:
- `missing_throws_annotation`: add `@Throws` with the inferred errors.
- `throws_annotation_mismatch`: update `@Throws` errors.
- `unused_throws_annotation`: remove the annotation.
- `no_try_catch`:
  - wrap the statement in try/catch, with a clause per error or one `on Object`
    clause (`final x = call();` becomes `late final T x; try { x = call(); }`,
    `void f() => call();` becomes a block body);
  - add `await` to a future-returning call inside try/catch;
  - add the errors to the enclosing `@Throws`, or annotate the enclosing
    function.
- `no_try_catch_in_closure`: wrap the statement (or a `void` `=>` body) in
  try/catch inside the closure, or add `await`.
- `not_exhaustive_try_catch`: add the missing catch clauses (subtypes before
  supertypes), a default `on Object` clause, or add the errors to `@Throws`.
- `introduced_throws_in_override`: add the errors to `@Throws` of the
  overridden member (when it is in your package), or wrap the call in try/catch.

Generated code selects the `reason` and the catch bodies as linked edits.

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
  # (e.g. throws_collector output; its `dependencies` input writes a map
  # per package in pubspec.lock).
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

  # Library URI, then members that throw what their callbacks throw, like
  # `@rethrows`.
  rethrows:
    package:retry/retry.dart: [retry, RetryOptions.retry]
```

Member names follow Dart tear-off syntax: `function` for top-level functions,
`Class.member` for methods, getters and setters, `Class.new` and
`Class.named` for constructors.

Notes:
- Prebuilt maps are heuristic only and come with no guarantees of completeness
  or accuracy.
- Entries from `members` and `include` take precedence over prebuilt maps.
- `prebuilt: [dart]` also marks SDK higher-order members as rethrowing:
  `Iterable.forEach`/`map`/`where`/..., `List.sort`, `Map.putIfAbsent`,
  `Future.then`/`catchError`/`whenComplete`, `Future.new`/`sync`/`microtask`,
  `runZoned` and others.
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

## Closures and `@rethrows`

A closure is checked as a function of its own. What happens to its errors
depends on where it goes:
- passed to a parameter of a function annotated with `@rethrows` (or listed
  under `rethrows`), its errors are thrown by that call, so the caller handles
  or declares them:

  ```dart
  @rethrows
  T measure<T>(T Function() action) => action();

  @Throws(errors: {FormatException})
  int parse(String s) => measure(() => int.parse(s));
  ```

- anywhere else (`onPressed: () => save()`, `Timer(d, () => ...)`, a variable),
  nothing outside can catch them: `no_try_catch_in_closure` reports throwing
  calls inside it. An explicit `throw` in a closure is not reported.

A tear-off of a known function (`list.forEach(parse)`) is treated like a closure
that calls it. An `async` closure passed to a parameter that returns `void`
(`forEach((x) async => ...)`) loses its errors in a dropped future, so its errors
stay inside it.

`@rethrows` is inherited by overrides and combines with `@Throws` for the
function's own errors. Lazy members (`map`, `where`, ...) throw when iterated,
but their callback's errors are reported at the call.

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
- Function types carry no errors: a callback stored in a variable or field, or
  passed through an unannotated parameter, loses them. A `@rethrows` function
  rethrows all errors of its arguments, even those it catches itself.

- Analysis is best-effort and depends on available type information.
- SDK/dependency coverage depends on map data (prebuilt or collected).
