---
kind: entity
status: strong
starshine_status: active
last_reviewed: 2026-09-22
sources:
  - https://webassembly.github.io/spec/js-api/#read-the-imports
  - ../../../raw/binaryen/2026-07-28-duplicate-import-elimination-v131-refresh.md
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/DuplicateImportElimination.cpp
  - ../../../../../src/passes/duplicate_import_elimination.mbt
  - ../../../../../src/passes/duplicate_import_elimination_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../tests/optimizer/regressions/host-identity.test.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ./fuzzing.md
  - ../late-pipeline-dispatch.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./identity-and-rewrite-surface.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./fuzzing.md
  - ../duplicate-function-elimination/index.md
  - ../simplify-globals-optimizing/index.md
  - ../remove-unused-module-elements/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `duplicate-import-elimination`

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

## Role and status

`duplicate-import-elimination` remains a registered late module pass, but current Starshine preserves repeated imported-function slots. The WebAssembly JavaScript API's [read-the-imports algorithm](https://webassembly.github.io/spec/js-api/#read-the-imports) iterates every module import, performs `Get(importObject, moduleName)` and `Get(moduleObject, componentName)` for each entry, and appends each resolved external value independently. A repeated property getter can therefore return different functions. Collapsing two same-name/type imports changes lookup count, function identity, and execution.

The historical planner and the 2026-07-28 Binaryen-v131 parity evidence remain documented below. A 2026-09-22 safety guard now returns the original module when a function `(module, base)` lookup repeats, before type comparison, remapping, metadata invalidation, or import removal. Since those are the only Binaryen-style opportunities, direct Starshine DIE is a compatibility no-op for valid opportunities and intentionally diverges from Binaryen 132.

Binaryen's canonical late neighborhood is:

`duplicate-function-elimination -> duplicate-import-elimination -> simplify-globals-optimizing -> remove-unused-module-elements`

Exact public O4z preset reconciliation remains separate under `[O4Z-PRESET]001`; direct DIE is no longer an active `[V131-LEGACY-EH]001` blocker.

## Released Binaryen v131 contract

The v131 owner, rewrite helper, and dedicated input fixture are byte-identical to v130. The algorithm remains:

1. inspect imported functions only;
2. bucket by exact `(module, base)` strings;
3. compare against the current bucket representative's exact function type;
4. keep a type mismatch and make it the new representative;
5. rewrite a type match through `OptUtils::replaceFunctions`;
6. remove the later imported function.

The source still carries `TODO: non-function imports too`; duplicate globals, tables, memories, and tags remain outside the pass.

## Rewrite surface

Binaryen's helper covers:

- direct `call`;
- `ref.func`;
- function references in module-code expression trees;
- `start`;
- function exports.

The historical Starshine numeric-index planner additionally had to shift every later defined `FuncIdx` and repair structured function-name, local-name, label-name, and function-annotation ownership. It cleared `raw_name_sec_payload` on the changed path so stale absolute function indices could not be re-emitted.

## Full family coverage

The current `duplicate-import-elimination` GenValid aggregate owns five leaves:

- body references, including nested control and `return_call`;
- identity and representative policy;
- module-code references;
- legacy EH and `try_table`;
- all four non-function import kinds as negative scope.

The 10,000-case dedicated lane selected every leaf and all 13 case labels. Every case normalized exactly to Binaryen v131, with no validation, generator, property, command, or raw mismatch failures.

Focused pass tests encode/decode every historical leaf and identity/EH variant, require every input to remain exactly unchanged, validate every output, and require idempotence. Direct and pipeline reduced repros preserve two calls at indices `0` and `1`; the active command-adapter regression preserves both declarations and the second call target.

## Closeout matrix

- regular GenValid: `100000/100000` exact normalized matches;
- dedicated aggregate: `10000/10000` exact normalized matches;
- random all-profiles: `9375` exact plus `625` classified pass-independent local-run representation gaps from `remove-unused-brs-control` modules with no imports;
- explicit wasm-smith: `9956` comparable, `9955` exact, one pass-independent unreachable-control-debris case, and 44 Binaryen/tool command failures;
- wasm-smith classification rerun: `9955` exact plus `1` cleanup-normalized, zero remaining mismatches.

See [`fuzzing.md`](./fuzzing.md) for exact commands, out dirs, cache counters, selected-family counts, and classifications.

## Representation verdict

The historical v131 matrix below established the old merge implementation's Binaryen parity. It no longer describes current Starshine output on repeated imports. Current preservation is a semantic safety divergence backed by the JS API algorithm and executable Node evidence: the fixture's getter runs twice and `run()` returns `3` before and after direct DIE. The old merge performed one lookup and returned `2`.

The random-all local-run family is a real one-byte Starshine size loss, but its inputs have no imports and both DIE implementations are no-ops. It remains owned by decoder/encoder local-run canonicalization rather than this pass.

## Performance

These retained timings measure the historical merge implementation, before the host-safety guard made its valid merge opportunities unreachable:

- import-heavy: `0.447 ms` versus `2.00646 ms` (`0.223x`);
- user-heavy: `0.2835 ms` versus `0.946297 ms` (`0.300x`).

## Page map

- [`binaryen-strategy.md`](./binaryen-strategy.md): upstream algorithm and scheduler role.
- [`implementation-structure-and-tests.md`](./implementation-structure-and-tests.md): owner/helper/test map.
- [`identity-and-rewrite-surface.md`](./identity-and-rewrite-surface.md): duplicate key and user-retargeting contract.
- [`wat-shapes.md`](./wat-shapes.md): positive and negative module shapes.
- [`starshine-strategy.md`](./starshine-strategy.md): local implementation, family verdicts, invariants, and reopening criteria.
- [`fuzzing.md`](./fuzzing.md): current profiles and historical v131 closeout evidence.

## Reopening criteria

Reopen direct DIE if a host-independent proof makes two import entries interchangeable, an explicit closed-world import-binding contract is added, repeated imports are removed or reordered, any preservation fixture changes, or the unchanged path mutates bytes or metadata. Upstream merge changes remain historical comparison work and cannot override the host-resolution contract.
