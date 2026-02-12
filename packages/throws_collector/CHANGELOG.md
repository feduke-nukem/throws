## 2.0.0

- Switch to config-only operation via throws_collector.yaml (no CLI args).
- Support multiple inputs: local path, git URL (shallow clone), and pub.dev package.
- Add git and pub cache handling, with progress logging and fallback download.
- Write outputs to throws_collector_gen/ with format inferred from file extension.
- Derive Dart map names from output filenames (camelCase).
- Normalize library URIs to package: paths for consistent keys.

## 1.0.0

- Initial release with CLI runner and modular collector pipeline.
