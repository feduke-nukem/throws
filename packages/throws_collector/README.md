# throws_collector

CLI tool to collect thrown errors from Dart sources and emit a Dart map.

## Install

Add as a dev dependency:

```yaml
dev_dependencies:
  throws_collector: any
```

## Usage

```bash
dart run throws_collector --root <path> --out <file>
```

Examples:

```bash
dart run throws_collector --root /path/to/sdk --out tool/throws_map_generated.dart
```

Or use a config file with no args:

```bash
dart run throws_collector
```

## throws_collector.yaml

The tool reads `throws_collector.yaml` at the package root that lists
`throws_collector` under `dev_dependencies`. CLI args override config values.

Example:

```yaml
root: .
out: tool/throws_map_generated.dart
sdk_root: /path/to/sdk
format: dart
```

## Options

- `--root <path>`: root directory to analyze.
- `--out <file>`: output file path.
- Dart output map name is inferred from the output file name and camel-cased (e.g. `flutter_errors.g.dart` -> `flutterErrors`).
- `--sdk-root <path>`: optional Dart SDK root to map `dart:` URIs.
- `--format <value>`: output format (`dart`, `json`, `yaml`). If omitted, the tool infers it from the file extension (`.dart`, `.json`, `.yaml`, `.yml`).
- `-h`, `--help`: show help.

## Output

The tool writes a Dart/JSON/YAML file containing a map of thrown errors.
Keys are `<library-uri>.<enclosing>.<member>` or `<library-uri>.<member>`.

## Notes

- Uses resolved AST; results are best-effort and not guaranteed to be complete.
- Generated entries may include inferred types from static analysis.
