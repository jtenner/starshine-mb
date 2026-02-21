# Agent Tasks

## Audit Snapshot (2026-02-21)

- `moon check`: passes (1 warning)
- `moon test`: `2060` passed, `0` failed
- `moon coverage analyze`: `10980` uncovered lines in `96` files
- Largest uncovered hotspots:
  - validate: `src/validate/env.mbt` (`1328`), `src/validate/typecheck.mbt` (`579`)
  - transformer: `src/transformer/transformer.mbt` (`624`)
  - binary: `src/binary/encode.mbt` (`423`), `src/binary/decode.mbt` (`374`)
  - passes: `src/passes/heap2local.mbt` (`366`), `src/passes/merge_blocks.mbt` (`306`), `src/passes/asyncify.mbt` (`242`)
  - IR: `src/ir/ssa.mbt` (`267`), `src/ir/ssa_optimize.mbt` (`216`)

## 0) Highest Priority

- [ ] P0: Harden validation and typed-conversion core before adding new pass features.
  - [ ] `src/validate/env.mbt`: table-driven `instr_to_tinstr` error-path coverage (stack underflow/empty stack pops, `RecIdx` resolution, type-resolution failures).
  - [ ] `src/validate/typecheck.mbt`: add negative-path tests for branch/label errors, `expand_blocktype` failures, and unreachable merge normalization.
  - [ ] Add regression tests proving typed conversion and typecheck consistency on shared fixtures (`to_texpr` then `Typecheck::typecheck`).

- [ ] P0: Close transformer traversal blind spots.
  - [ ] `src/transformer/transformer.mbt`: add callback matrix tests for `Ok(None)`, `Ok(Some(...))`, and `Err(...)` across less-used ops (atomics, i31, extern/any converts, `throw_ref`, branch-on-cast variants).
  - [ ] Add focused tests for index/heaptype remap propagation on nested instructions.

- [ ] P0: Harden binary codec error handling.
  - [ ] `src/binary/encode.mbt`: cover unsupported encodings (`DefTypeHeapType`, recursive index rejections), section payload error propagation, and LEB max-byte guards.
  - [ ] `src/binary/decode.mbt`: expand malformed vectors for terminal-unused-bits checks, sign-extension edge cases, optional decode fallthrough, and OOB numeric loads.

- [ ] P1: Raise IR SSA and analysis confidence on complex instruction families.
  - [ ] `src/ir/ssa.mbt` + `src/ir/ssa_optimize.mbt`: cover local collection and phi handling for atomics, table ops, array ops, and `call_ref`/`return_call_ref`.
  - [ ] `src/ir/liveness.mbt`, `src/ir/type_tracking.mbt`, `src/ir/usedef.mbt`: add edge tests involving branch-on-ref plus atomic instructions.

- [ ] P1: Attack high-uncovered optimization passes (`>= 150` uncovered lines).
  - [ ] `src/passes/heap2local.mbt`
  - [ ] `src/passes/merge_blocks.mbt`
  - [ ] `src/passes/asyncify.mbt`
  - [ ] `src/passes/i64_to_i32_lowering.mbt`
  - [ ] `src/passes/global_type_optimization.mbt`
  - [ ] `src/passes/minimize_rec_groups.mbt`
  - [ ] `src/passes/remove_unused.mbt`
  - [ ] `src/passes/local_cse.mbt`
  - [ ] `src/passes/optimize_instructions.mbt`
  - [ ] `src/passes/precompute.mbt`
  - [ ] For each pass above: add one invariant test proving module validity and stable index remapping.

- [ ] P1: Resolve known feature and architecture debt.
  - [ ] `src/passes/i64_to_i32_lowering.mbt`: remove unsupported cases (`multi-value i64 results`, imported i64 globals, non-canonical i64 global-init roots) or gate pass preconditions at scheduler entry.
  - [ ] `src/passes/asyncify.mbt`: handle tail calls (or add explicit required lowering prepass with diagnostics).
  - [ ] Migrate `de_nan` and `remove_unused` to IRContext-shaped integration.

## 0.5) Low-Hanging Fruit

- [ ] Remove current warning: drop unused `ExtractLaneOp` import in `src/passes/imports.mbt`.
- [ ] Add small constructor/util coverage tests for common helpers in `src/lib/types.mbt` (`Limits::mem_addr_bits`, `min_addr`, `has_default`, constructor shorthands).
- [ ] Add `Show`/pretty-print smoke tests for `src/lib/show.mbt` and `src/lib/pretty_print_impls.mbt`.
- [ ] Add targeted tests for `asyncify_apply_arguments` parser branches (`blacklist`/`whitelist`, secondary-memory-size parsing, conflicting `onlylist` combinations).
- [ ] Add targeted tests for `MBEffects` helper logic in `src/passes/merge_blocks.mbt` (`merge`, `invalidates`, `mb_collect_shallow_effects`).
- [ ] Add one test covering `TypeIdx`/`RecIdx` resolution fallback in `src/validate/env.mbt` when `rec_stack` is empty.
- [ ] Add a tiny coverage-report script that emits top uncovered files from `moon coverage analyze` and tracks deltas in CI.

## 1) Secondary Backlog

- [ ] Split oversized files for maintainability and faster targeted testing:
  - [ ] `src/validate/typecheck.mbt`
  - [ ] `src/validate/env.mbt`
  - [ ] `src/transformer/transformer.mbt`
  - [ ] `src/passes/optimize.mbt`
  - [ ] `src/passes/remove_unused.mbt`
- [ ] Build a non-blocking optimizer perf baseline (compile time and output size) on representative modules.
- [ ] Continue long-tail Binaryen parity only after core coverage hotspots are reduced.

---
Completed items are intentionally removed to keep this backlog actionable.
