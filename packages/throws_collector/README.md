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
input:
  - dart_errors.yaml:
      path: /path/to/sdk/lib
  - dart_errors_git.yaml:
      git: https://github.com/dart-lang/sdk/tree/main/sdk/lib
  - bloc_errors.dart:
      package:
        name: bloc
        version: 9.2.0
```

Input types:
- path: local directory
- git: git URL (shallow clone)
- package: pub.dev package name and version

## Output

Output is written to the throws_collector_gen/ directory in the package root.
The output file name is taken from the input keys. Output format is inferred
from the extension (.dart, .json, .yaml, .yml).

Package inputs are downloaded from pub.dev and cached under
.dart_tool/throws_collector/pub/ if they are not already in the global pub
cache.

For Dart output, the map name is inferred from the file name and camel-cased
(for example, flutter_errors.g.dart -> flutterErrors).

The tool writes a Dart/JSON/YAML file containing a map of thrown errors.
Keys are <library-uri>.<enclosing>.<member> or <library-uri>.<member>.

## Notes

- Uses resolved AST; results are best-effort and not guaranteed to be complete.
- Generated entries may include inferred types from static analysis.
- Collector output can be included in throws.yaml via include_paths.
