---
kind: tooling-note
status: active
last_reviewed: 2026-05-25
sources:
  - ../../../scripts/lib/fuzz-reducers.ts
  - ../../../scripts/test/fuzz-reducers.ts
  - ../../../src/cmd/fuzz_harness.mbt
  - ../../../src/cmd/fuzz_harness_wbtest.mbt
  - ../../../agent-todo.md
---

# Fuzz Reduction Backends

`[FUZ]1043B` added the first reusable script-side reduction backends in `scripts/lib/fuzz-reducers.ts`:

- `reduceModuleFieldsByDeletion(...)` deletes contiguous module-field chunks while a caller-supplied predicate still reproduces the interesting condition.
- `reduceBinaryByByteSlices(...)` applies the same chunk-deletion loop to raw wasm bytes and returns a `Uint8Array`.
- `reduceTextByTokenDeletion(...)` tokenizes WAT/WAST-like text and deletes token chunks while preserving the predicate.

The reducers are deliberately predicate-only and format-light. They do not validate wasm, reparse text, or decide interestingness themselves; callers own those checks so the same backends can serve pass-fuzz mismatches, invalid-fuzz repros, and future corpus tooling.

The initial unit coverage in `scripts/test/fuzz-reducers.ts` proves each backend removes irrelevant material, preserves required predicate tokens/bytes/fields, and leaves input unchanged when no deletion preserves the predicate.

`[FUZ]1043C` adds the same predicate-only deletion loop to the Moon command fuzz harness through `reduce_fuzz_sequence_by_deletion(...)` and `reduce_fuzz_bytes_by_slice_deletion(...)`. The sequence reducer now backs `minimize_fuzz_passes(...)`, so pass-list minimization, future GenValid/module-field minimizers, byte repro reducers, and command-harness failure minimization can share one chunk-deletion contract with explicit reduction-step metadata and predicate-evaluation counts.

`[FUZ]1043D` connects those Moon reduction reports to command-harness repro persistence. `FuzzFailureReport` can now carry a reduced wasm artifact plus the original/final sizes, predicate-evaluation count, and applied deletion steps; `persist_fuzz_failure_report(...)` writes the original `.wasm`, reduced `.reduced.wasm`, and `.reduction.txt` shrink log side by side and records the reduced-artifact/log paths in the metadata. This keeps the original failure input immutable while making the minimized reproducer and shrink trace discoverable for later replay or corpus promotion.

`[FUZ]1043E` extends the same artifact contract to invalid-fuzz repro bundles. `InvalidFuzzFailureReport` now records optional reduction original/final sizes, predicate-evaluation count, and deletion-step metadata alongside existing reduced artifacts; `persist_invalid_fuzz_failure_report(...)` writes a `reduction.txt` shrink log in the deterministic suite/strategy/seed repro directory and records `reduction_log=reduction.txt` plus `reduction_step=kind|start|len|before|after` metadata. Parsing roundtrips the reduction fields without loading the log, so corpus tooling can discover shrink evidence while replay still chooses original versus reduced artifacts explicitly.
