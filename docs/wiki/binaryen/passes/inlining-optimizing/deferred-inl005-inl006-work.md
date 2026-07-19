# INL005 / INL006 Closeout And Shared-Metadata Boundaries

Last updated: 2026-07-19.

This page supersedes the former v0.2.0 deferral. The Binaryen v131 inlining-family audit implemented `[INL]005`, closed the pass-owned portions of `[INL]006`, and removed the former EH tail-hoisting boundary.

## `[INL]005` partial inlining: closed

Starshine implements Binaryen's represented Pattern A and Pattern B families with the same policy gate: optimize level at least 3, shrink level 0, and positive `partialInliningIfs`.

Implemented details:

- leading simple Pattern A return guards;
- multiple Pattern B guarded bodies and optional simple final values;
- complete represented v131 Unary plus `RefIsNull` condition chains;
- terminal result arms for return, tail-call, trap, throw, and other represented terminal-unreachable forms;
- deterministic outlined helper naming;
- parameter forwarding;
- annotation and no-inline policy copy;
- `no-full-inline` allowing partial splitting;
- `no-partial-inline` and `no-inline` suppressing it;
- cleanup of internal splitter markers.

## `[INL]006` repair: pass-owned behavior closed

Implemented repair includes:

- scalar and multivalue result block typing;
- synthesized zero-param multivalue block types;
- direct/indirect/ref nested tail-call lowering at non-tail sites;
- direct/indirect/ref tail preservation at tail sites;
- EH-aware operand localization and tail-call hoisting from `try_table`;
- table32/table64 indirect target-local typing;
- function-target and catch-target branch-depth repair after hoist wrappers;
- defaultable and nondefaultable local handling;
- function and annotation remapping;
- valid caller local-name preservation;
- untouched label-name preservation and stale rewritten-label-map removal.

`inline-main` reuses the same repair path, including tail calls nested in `try_table`.

## Shared metadata boundaries

The remaining differences are not pass-owned wasm behavior gaps:

- copied callee local/label debug names are not synthesized into callers;
- expression-level `metadata.code.branch_hint` and other byte-offset code metadata are not represented locally;
- source-map offset repair is not modeled;
- legacy `try_delegate` is outside the current instruction representation.

These should reopen through the shared metadata, WAST, binary, or legacy-EH substrate—not through a new inlining transform slice.

## CLI and policy closeout

Binaryen's six tuning controls now flow through CLI parsing, short aliases, help, JSON config, `OptimizeOptions`, `HotPipelineOptions`, and the shared pass:

- `--always-inline-max-function-size` / `-aimfs`;
- `--one-caller-inline-max-function-size` / `-ocimfs`;
- `--flexible-inline-max-function-size` / `-fimfs`;
- `--inline-max-combined-binary-size` / `-imcbs`;
- `--inline-functions-with-loops` / `-ifwl`;
- `--partial-inlining-ifs` / `-pii`.

Released v131 `@binaryen.inline`, Starshine `no-inline*`, and `@metadata.code.inline` remain separate channels.

## Evidence

- CLI parser: `54/54`;
- command tests: `107/107`;
- focused inlining: `120/120`;
- white-box inlining: `14/14`;
- full repository: `9452/9452`;
- plain official-v131 GenValid: `.tmp/pass-fuzz-inlining-v131-closeout-10000`, `10000/10000` normalized matches, no failures;
- optimizing official-v131 GenValid: `.tmp/pass-fuzz-inlining-optimizing-v131-closeout-10000`, `10000/10000` normalized matches, no failures.
