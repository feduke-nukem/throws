## 2.0.0
- **Breaking:** throws.yaml v2: `track`, `prebuilt`, `include` and `members`
  (library URI, then member). Version 1 keys are no longer read.
- **Breaking:** constructors are keyed `Class.new` / `Class.named`.
- Compare errors as types with subtyping instead of by name.
- Add `track` option in throws.yaml to check `exception`, `error` or both.
- Propagate errors through chains of local unannotated functions.
- Report getters read through implicit `this`; ignore method tear-offs.
- Recognize only `@Throws`/`@throws` from package:throws.
- Read throws.yaml through the analyzer file system; it is re-read on the next analysis session.
- Quick fixes import the error types they insert.
- Removing an unused annotation no longer leaves an empty line.
- Require analyzer ^14.5.0 and Dart ^3.11.0.
- Regenerate prebuilt dart/flutter maps without names from doc examples and prose.

## 1.1.1
- Improve introduced_throws_in_override lint

## 1.1.0
- Cache per-file analysis results to reduce repeated AST traversals.
- Reuse local throwing info across lints and fixes for better performance.
- Improve stability of analyzer execution in large files.

## 1.0.0
- Stable release

## 1.0.0-alpha.10
- Improves quick fixes

## 1.0.0-alpha.9
- Improves missing clauses and try/catch
- Improves unhandled function linting

## 1.0.0-alpha.8
- Fix false linting of function within try/catch

## 1.0.0-alpha.7
- Adds new assists
- Fix missing clauses
- Fix try/catch resolving

## 1.0.0-alpha.6
- Adds support of Error.throwWithStackTrace
- 
## 1.0.0-alpha.5
- Fixes use_sdk_map read

## 1.0.0-alpha.4

- Fixes plugin name

## 1.0.0-alpha.3

- Adds supertype handling
- Sets useSdkMap to false by default

## 1.0.0-alpha.2

- Fix README.md
- 
## 1.0.0-alpha

- Initial version
