---
kind: tooling-note
status: active
last_reviewed: 2026-05-31
sources:
  - ../../../scripts/lib/fuzz-reducers.ts
  - ../../../scripts/test/fuzz-reducers.ts
  - ../../../src/cmd/fuzz_harness.mbt
  - ../../../src/cmd/fuzz_harness_wbtest.mbt
  - ../../../src/fuzz/invalid_repro.mbt
  - ../../../src/fuzz/invalid_repro_wbtest.mbt
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

`[FUZ]1043F` makes the built-in invalid-fuzz shrink path produce that evidence itself. `shrink_invalid_fuzz_failure_report(...)` still returns strategy-minimal replayable artifacts for AST, binary, inline-text, and spec-seed invalid reports, but now annotates the report with original/final byte sizes, a two-replay predicate-evaluation count, and a `strategy-minimal-repro` reduction step. This keeps supplied reduction evidence and locally generated shrink evidence in the same metadata/log contract while preserving the original artifact.

`[FUZ]1043G` adds a Moon text-token adapter over the shared sequence reducer through `reduce_fuzz_text_tokens_by_deletion(...)`. It splits WAT/WAST-like text into non-whitespace token units, runs the same predicate-preserving chunk deletion loop, rejoins surviving tokens with single spaces, and relabels reduction steps as `delete-text-token-range`. This gives future text, WAST, and module-artifact shrink paths an in-process reducer before they need parser-aware module-field deletion.

`[FUZ]1043H` wires that token-deletion shape into one concrete invalid-fuzz shrink path. `shrink_invalid_fuzz_failure_report(...)` now tries replay-predicate-preserving text-token deletion for inline text and spec-seed WAST reports before falling back to the existing strategy-minimal reducer. Successful token reductions preserve the original artifact, write a reduced WAST artifact, and record `delete-text-token-range` steps plus predicate-evaluation counts in the normal invalid-fuzz reduction metadata.

`[FUZ]1043I` adds the parser-aware Moon module-field adapter over the same sequence reducer through `reduce_fuzz_module_fields_by_deletion(...)`. Callers pass parsed WAST `ModuleField` arrays and a replay predicate; the adapter deletes contiguous field ranges while the predicate still reproduces, and relabels shrink steps as `delete-module-field-range`. This keeps parser-aware module reducers predicate-only and ready for future WAST/module shrink integrations without inventing a second reduction loop.

`[FUZ]1043J` wires that module-field reducer shape into invalid-fuzz inline text and spec-seed shrink reports. The shrink path now parses inline `assert_malformed`, `assert_invalid`, or `assert_unlinkable` modules, tries predicate-preserving module-field deletion first, emits a reduced WAST assertion when successful, and falls back to token deletion or strategy-minimal reduction when no inline-module field deletion reproduces. This makes WAST/module reductions structurally aware before the broader token reducer removes arbitrary lexical chunks.

`[FUZ]1043K` syncs the script-side GenValid pass-fuzz mismatch reducer with the shared reduction artifact contract. `reduceBinaryByByteSlicesWithReport(...)` now returns the reduced bytes together with original/final sizes, predicate-evaluation count, and `delete-byte-slice` steps. Fresh GenValid `pass-fuzz-compare` mismatches persist those steps in `reduction.txt` and `failure-metadata.json` beside `reduced-input.wasm`, while keeping the original `input.wasm` as the canonical replay artifact.

`[FUZ]1043L` extends that report-returning script-side contract to token deletion. `reduceTextByTokenDeletionWithReport(...)` returns the reduced text plus token-count original/final sizes, predicate-evaluation count, and `delete-text-token-range` steps, while `reduceTextByTokenDeletion(...)` remains the compatibility wrapper that returns only the reduced text. This gives future script-side WAT/WAST reducers the same shrink-log metadata shape already used for byte-slice GenValid reductions.
