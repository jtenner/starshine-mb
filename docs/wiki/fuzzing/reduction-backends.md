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
