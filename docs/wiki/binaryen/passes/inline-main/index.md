---
kind: entity
status: supported
last_reviewed: 2026-07-19
sources:
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/passes/Inlining.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/test/lit/passes/inline-main.wast
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./special-case-contract-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./fuzzing.md
  - ../inlining/index.md
---

# `inline-main`

## Status

`inline-main` is an active, supported Starshine module pass aligned with Binaryen v131's special-case contract. It is intentionally absent from default optimize/shrink presets.

## Contract

The pass:

1. resolves functions named exactly `main` and `__original_main`;
2. requires both to be defined;
3. recursively counts direct `call` and `return_call` uses of `__original_main` inside `main`;
4. requires exactly one matching call;
5. inlines that call with the shared body-copy engine;
6. retains `__original_main`.

Missing/imported endpoints and wrappers with zero or multiple matching calls are no-ops. Profitability and ordinary no-inline heuristics do not participate.

## Shared repair behavior

Because `inline-main` reuses the ordinary inliner, successful rewrites include:

- operand storage and local remapping;
- defaultable/nondefaultable local handling;
- scalar and multivalue result blocks;
- return-to-branch rewriting;
- nested direct/indirect/ref tail-call repair;
- EH-aware hoisting when the matching `return_call` is inside `try_table`;
- branch-depth repair for generated wrappers;
- valid name-map preservation and stale label-map avoidance.

The original helper is retained even after success, matching upstream.

## Distinctions

- `inline-main`: exact wrapper special case, no profitability, helper retained.
- `inlining`: module-wide profitability-driven direct inliner.
- `monomorphize`: callsite-context specialization through cloning.

Do not add `inline-main` to presets merely because ordinary inlining is scheduled.

## Evidence

Focused tests cover:

- ordinary direct call;
- matching `return_call`;
- `return_call` nested in `try_table`;
- exactly-one-call enforcement;
- missing/imported endpoints;
- helper retention;
- unrelated-call preservation.

The shared inlining suite is `120/120`, white-box invariants are `14/14`, and full `moon test` is `9452/9452`.

Generic random fuzzing is only protocol smoke because exact names are rare. Meaningful generated evidence must author `main` / `__original_main` and record whether the exact call was selected; see [`fuzzing.md`](./fuzzing.md).

## Shared boundaries

Expression-level branch hints, source maps, copied callee debug-name synthesis, and legacy `try_delegate` are shared representation/metadata concerns rather than `inline-main` chooser or rewrite gaps.
