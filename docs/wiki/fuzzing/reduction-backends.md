---
kind: tooling-note
status: active
last_reviewed: 2026-05-25
sources:
  - ../../../scripts/lib/fuzz-reducers.ts
  - ../../../scripts/test/fuzz-reducers.ts
  - ../../../agent-todo.md
---

# Fuzz Reduction Backends

`[FUZ]1043B` added the first reusable script-side reduction backends in `scripts/lib/fuzz-reducers.ts`:

- `reduceModuleFieldsByDeletion(...)` deletes contiguous module-field chunks while a caller-supplied predicate still reproduces the interesting condition.
- `reduceBinaryByByteSlices(...)` applies the same chunk-deletion loop to raw wasm bytes and returns a `Uint8Array`.
- `reduceTextByTokenDeletion(...)` tokenizes WAT/WAST-like text and deletes token chunks while preserving the predicate.

The reducers are deliberately predicate-only and format-light. They do not validate wasm, reparse text, or decide interestingness themselves; callers own those checks so the same backends can serve pass-fuzz mismatches, invalid-fuzz repros, and future corpus tooling.

The initial unit coverage in `scripts/test/fuzz-reducers.ts` proves each backend removes irrelevant material, preserves required predicate tokens/bytes/fields, and leaves input unchanged when no deletion preserves the predicate.
