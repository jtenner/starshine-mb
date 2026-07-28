---
kind: entity
status: strong
starshine_status: active
last_reviewed: 2026-07-28
sources:
  - ../../../raw/binaryen/2026-07-28-duplicate-import-elimination-v131-refresh.md
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/DuplicateImportElimination.cpp
  - ../../../../../src/passes/duplicate_import_elimination.mbt
  - ../../../../../src/passes/duplicate_import_elimination_test.mbt
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

## Role and status

`duplicate-import-elimination` is a late module pass that collapses duplicate imported **functions**. Starshine exposes it as an active direct pass, and the 2026-07-28 Binaryen-v131 renewal closes its behavior parity after the legacy-EH and raw-name repairs.

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

Starshine's numeric-index IR must additionally shift every later defined `FuncIdx` and repair structured function-name, local-name, label-name, and function-annotation ownership. It clears `raw_name_sec_payload` on the changed path so stale absolute function indices cannot be re-emitted.

## Full family coverage

The current `duplicate-import-elimination` GenValid aggregate owns five leaves:

- body references, including nested control and `return_call`;
- identity and representative policy;
- module-code references;
- legacy EH and `try_table`;
- all four non-function import kinds as negative scope.

The 10,000-case dedicated lane selected every leaf and all 13 case labels. Every case normalized exactly to Binaryen v131, with no validation, generator, property, command, or raw mismatch failures.

Focused pass tests also encode/decode every leaf and every identity/EH variant, require positive leaves to remove a duplicate function import, require the negative leaf to remain exactly unchanged, validate every output, and require idempotence.

## Closeout matrix

- regular GenValid: `100000/100000` exact normalized matches;
- dedicated aggregate: `10000/10000` exact normalized matches;
- random all-profiles: `9375` exact plus `625` classified pass-independent local-run representation gaps from `remove-unused-brs-control` modules with no imports;
- explicit wasm-smith: `9956` comparable, `9955` exact, one pass-independent unreachable-control-debris case, and 44 Binaryen/tool command failures;
- wasm-smith classification rerun: `9955` exact plus `1` cleanup-normalized, zero remaining mismatches.

See [`fuzzing.md`](./fuzzing.md) for exact commands, out dirs, cache counters, selected-family counts, and classifications.

## Representation verdict

All DIE-owned transform families match Binaryen's normalized representation. No Starshine-only output shape is retained as a claimed win. Starshine-specific metadata/index repair exists only to preserve Binaryen-equivalent behavior in Starshine's numeric-index module representation.

The random-all local-run family is a real one-byte Starshine size loss, but its inputs have no imports and both DIE implementations are no-ops. It remains owned by decoder/encoder local-run canonicalization rather than this pass.

## Performance

The pass implementation did not change during this renewal. Retained direct fixtures remain faster than Binaryen:

- import-heavy: `0.447 ms` versus `2.00646 ms` (`0.223x`);
- user-heavy: `0.2835 ms` versus `0.946297 ms` (`0.300x`).

## Page map

- [`binaryen-strategy.md`](./binaryen-strategy.md): upstream algorithm and scheduler role.
- [`implementation-structure-and-tests.md`](./implementation-structure-and-tests.md): owner/helper/test map.
- [`identity-and-rewrite-surface.md`](./identity-and-rewrite-surface.md): duplicate key and user-retargeting contract.
- [`wat-shapes.md`](./wat-shapes.md): positive and negative module shapes.
- [`starshine-strategy.md`](./starshine-strategy.md): local implementation, family verdicts, invariants, and reopening criteria.
- [`fuzzing.md`](./fuzzing.md): current profiles and full v131 closeout evidence.

## Reopening criteria

Reopen direct DIE if upstream widens scope or changes identity policy, a dedicated family stops matching exactly, a duplicate-import case fails validation, metadata/index/EH/module-code repair regresses, the unchanged path mutates, or direct pass-local timing exceeds Binaryen under the retained method.
