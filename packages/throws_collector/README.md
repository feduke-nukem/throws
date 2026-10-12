# throws_collector

CLI tool to collect thrown errors from Dart sources and emit map files.

This tool is optional. It is a heuristic helper for throws_plugin and is most
useful when you want more complete SDK/dependency coverage in throws.yaml.

## Install

Add as a dev dependency:

```yaml
dev_dependencies:
  throws_collector: any
```

## Usage

```bash
dart run throws_collector
```

## throws_collector.yaml

The tool reads throws_collector.yaml at the package root that lists
throws_collector under dev_dependencies.

Example:

```yaml
output_dir: throws_collector_gen
input:
  - dart_sdk:
    output: dart_errors.yaml
  - flutter_sdk:
    output: flutter_errors.yaml
  - flutter_errors_git.yaml:
    git: https://github.com/flutter/flutter/tree/3.41.0/packages/flutter/lib/src
    run_pub_get: true
  - dart_errors_git.yaml:
      git: https://github.com/dart-lang/sdk/tree/main/sdk/lib
    run_pub_get: false
  - bloc_errors.dart:
      package:
        name: bloc
        version: 9.2.0
  - dependencies:
      exclude: [meta]
```

Input types:
- dart_sdk: installed Dart SDK (output required)
- flutter_sdk: installed Flutter SDK (output required)
- path: local directory
- git: git URL (shallow clone)
- package: pub.dev package name and version
- dependencies: every package in pubspec.lock (shorthand: `- dependencies`)

## Dependencies

`dependencies` writes one `<package>.yaml` per locked package to the output
directory. Run `pub get` first: files are resolved through the project's
`.dart_tool/package_config.json`, so types from other packages resolve and the
dependencies need no `pub get` of their own.

- SDK packages (`flutter`, `flutter_test`, ...) are skipped; use `flutter_sdk`.
- `exclude` skips packages by name.
- Each file starts with a stamp (`# http 1.2.2`, plus the commit for git
  packages). A package whose stamp matches pubspec.lock is not collected
  again; path packages always are. Delete the output to force a run.

Include the whole directory in throws.yaml:

```yaml
throws:
  include:
    - throws_collector_gen/
```

## Output

Output is written to the throws_collector_gen/ directory in the package root.
The output file name is taken from the input keys. Output format is inferred
from the extension (.dart, .json, .yaml, .yml).

You can override the output directory with output_dir (relative to the package
root or absolute).

Package inputs are downloaded from pub.dev and cached under
.dart_tool/throws_collector/pub/ if they are not already in the global pub
cache.

Git inputs run `pub get` by default to improve type resolution. Disable with
run_pub_get: false for git inputs that cannot be resolved without extra setup.

For Dart output, the map name is inferred from the file name and camel-cased
(for example, flutter_errors.g.dart -> flutterErrors).

The tool writes a Dart/JSON/YAML file with thrown errors per library URI, then
per member, in the format of `members` in throws.yaml:

```yaml
'package:bloc/src/bloc.dart':
  'Bloc.add': ['StateError']
  'Bloc.new': ['ArgumentError']
```

Member names follow Dart tear-off syntax: `function`, `Class.member`,
`Class.new` and `Class.named`.

## Notes

- Uses resolved AST; results are best-effort and not guaranteed to be complete.
- Generated entries may include inferred types from static analysis.
- Collector output can be included in throws.yaml via `include`.
