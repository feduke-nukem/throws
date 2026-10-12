## 3.1.0
- New `dependencies` input: one map per package in pubspec.lock, resolved
  through the project's package config. Unchanged packages are skipped.

## 3.0.0
- **Breaking:** output groups errors by library URI, then member, matching
  `members` in throws.yaml v2. Dart output is `Map<String, Map<String, List<String>>>`.
- **Breaking:** constructors are keyed `Class.new` / `Class.named`.
- Require analyzer ^14.5.0 and Dart ^3.11.0.
- Record the static type of thrown variables instead of the variable name.
- Doc comments count only `[References]` the analyzer resolves to `Error` or
  `Exception` subtypes, in sentences about throwing or failing futures.
- `run` and `parseArgs` accept an optional `workingDirectory`.

## 2.2.0+1

- Remove deprecated analyzer usage
- Fix pub.dev scoring

## 2.2.0

- Add `dart_sdk` and `flutter_sdk` inputs with explicit output files.
- Add `run_pub_get` input option for git sources (default true).
- Resolve installed Dart/Flutter SDK paths for SDK inputs.
- Improve Flutter pub get handling for git checkouts.

## 2.1.0

- Support output directory
- Improve errors collecting

## 2.0.0

- Switch to config-only operation via throws_collector.yaml (no CLI args).
- Support multiple inputs: local path, git URL (shallow clone), and pub.dev package.
- Add git and pub cache handling, with progress logging and fallback download.
- Write outputs to throws_collector_gen/ with format inferred from file extension.
- Derive Dart map names from output filenames (camelCase).
- Normalize library URIs to package: paths for consistent keys.

## 1.0.0

- Initial release with CLI runner and modular collector pipeline.
