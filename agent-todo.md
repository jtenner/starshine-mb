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

- [x] P0: Harden validation and typed-conversion core before adding new pass features.
  - [x] `src/validate/env.mbt`: table-driven `instr_to_tinstr` error-path coverage (stack underflow/empty stack pops, `RecIdx` resolution, type-resolution failures).
  - [x] `src/validate/typecheck.mbt`: add negative-path tests for branch/label errors, `expand_blocktype` failures, and unreachable merge normalization.
  - [x] Add regression tests proving typed conversion and typecheck consistency on shared fixtures (`to_texpr` then `Typecheck::typecheck`).

- [x] P0: Close transformer traversal blind spots.
  - [x] `src/transformer/transformer.mbt`: add callback matrix tests for `Ok(None)`, `Ok(Some(...))`, and `Err(...)` across less-used ops (atomics, i31, extern/any converts, `throw_ref`, branch-on-cast variants).
  - [x] Add focused tests for index/heaptype remap propagation on nested instructions.

- [x] P0: Harden binary codec error handling.
  - [x] `src/binary/encode.mbt`: cover unsupported encodings (`DefTypeHeapType`, recursive index rejections), section payload error propagation, and LEB max-byte guards.
  - [x] `src/binary/decode.mbt`: expand malformed vectors for terminal-unused-bits checks, sign-extension edge cases, optional decode fallthrough, and OOB numeric loads.

- [x] P1: Raise IR SSA and analysis confidence on complex instruction families.
  - [x] `src/ir/ssa.mbt` + `src/ir/ssa_optimize.mbt`: cover local collection and phi handling for atomics, table ops, array ops, and `call_ref`/`return_call_ref`.
  - [x] `src/ir/liveness.mbt`, `src/ir/type_tracking.mbt`, `src/ir/usedef.mbt`: add edge tests involving branch-on-ref plus atomic instructions.

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

## 2) Requested Backlog Additions

### 2.1 Architectural & Refactoring Suggestions (High Impact: Improves Maintainability)

- [ ] Split the giant parser file (`parser.mbt`) into smaller modules:
  - [ ] `lexer.mbt`
  - [ ] `parser_types.mbt`
  - [ ] `parser_instructions.mbt`
  - [ ] `parser_folded.mbt`
  - [ ] `parser_gc.mbt`
  - [ ] `parser_tests.mbt`
  - Effort: `2–3 hours`
  - Rationale: Reduces complexity as the project grows.
- [ ] Split instruction decoder (`decode_instruction` in `decode.mbt`) into helpers:
  - [ ] `decode_core_opcode`
  - [ ] `decode_extended_0xFB`
  - [ ] `decode_extended_0xFC`
  - [ ] `decode_extended_0xFD`
  - [ ] `decode_extended_0xFE`
  - Effort: `1–2 hours`
  - Rationale: Mirrors existing encode helper pattern (for example `simd_inst`) and improves readability.
- [ ] Extract `write_section` helper in `encode.mbt` to unify section id/length/payload encoding.
  - Effort: `30 minutes`
  - Rationale: Cleans up encode-side symmetry.
- [ ] Turn validator into a `ModuleTransformer`:
  - [ ] Implement `Validator` struct with hooks such as `on_func_evt`, `on_tinstruction_evt`, and `on_global_evt`.
  - [ ] Add `validate_module(mod: Module) -> Result[Unit, ValidationError]`.
  - Effort: `2–3 hours`
  - Rationale: Reuses existing traversal and location context; improves composition with optimizers.
- [ ] Replace lexer backtracking (`save/restore_lexer_state`) with one-token lookahead:
  - [ ] Introduce `Parser { peeked: Token? }` or add zero-cost `peek()/consume()` to `WastLexer`.
  - Effort: `1 hour`
  - Rationale: Reduces fragility and parsing allocations.

### 2.2 Performance & Allocation Optimizations (Medium Impact: Scales to Large Modules)

- [ ] Add capacity reservations in hot paths (`parse_instructions`, expr decoding, and similar array builds).
  - Effort: `30 minutes`
  - Rationale: Avoids reallocations on large modules.
- [ ] Use unchecked indexing in core decode loops after upfront length validation.
  - Effort: `1 hour`
  - Rationale: Reduces bounds-check overhead in tight loops.
- [ ] Avoid temporary `Module` copies in decoder:
  - [ ] Use mutable builder flow or single record update at the end.
  - Effort: `30 minutes`
  - Rationale: Reduces copies of large structs.
- [ ] Create a `WastWriter` trait:
  - [ ] Support `StringBuilder`, `Vec<u8>`, and streaming sinks.
  - [ ] Reuse one `StringBuilder` across module rendering.
  - Effort: `1 hour`
  - Rationale: Improves writer efficiency and flexibility.
- [ ] Add `quick_mode: Bool` to generator to reduce types/locals/segments for fast fuzzing.
  - Effort: `30 minutes`
  - Rationale: Speeds test cycles while retaining useful coverage.

### 2.3 Testing & Fuzzing Enhancements (High Impact: Strengthens Reliability)

- [ ] Enhance generator with additional edge cases:
  - [ ] Recursive/self-referencing struct types
  - [ ] Deep `block`/`loop`/`if` nesting
  - [ ] Functions with `0–16` returns (multi-value)
  - [ ] Large local counts
  - Effort: `1–2 hours`
  - Rationale: Better stress for GC, exceptions, and encoding paths.
- [ ] Add more fuzz coverage to validate invalid modules.

### 2.4 Error Handling & API Improvements (Medium Impact: User-Friendliness)

- [ ] Replace string decode errors with a typed `DecodeError` enum:
  - [ ] Example variants: `UnexpectedEof { offset: Int, section: String }`, `InvalidOpcode { offset: Int, byte: Byte }`
  - [ ] Mirror the same enum-based approach for `ValidationError`.
  - Effort: `1 hour`
  - Rationale: Improves testability and downstream tooling with stable structured context.
- [ ] Expose binary public APIs:
  - [ ] `decode_module(bytes: Bytes) -> Result[Module, DecodeError]`
  - [ ] `encode_module(mod: Module) -> Result[Bytes, EncodeError]`
  - Effort: `30 minutes`
  - Rationale: Improves library usability.
- [ ] Add streaming/zero-copy decoder API via cursor-based `Decoder` struct.
  - Effort: `1 hour`
  - Rationale: Aligns with current index-passing design while reducing copies.
- [ ] Switch negative tests to enum-based error assertions instead of string matching.
  - Effort: `1 hour`
  - Rationale: Prevents brittle tests during message refactors.

### 2.5 Code Generation & Automation (Low Impact: Long-Term Maintainability)

- [ ] Generate keyword/opcode tables from a small DSL or MoonBit macros (with manual exception overrides).
  - Effort: `2 hours`
  - Rationale: Keeps mapping logic DRY as opcode surface evolves.
- [ ] Make max LEB constants compile-time (`MAX_LEB128_BYTES_32 = 5`, etc., including `1..64` table if useful).
  - Effort: `15 minutes`
  - Rationale: Removes runtime overhead.
- [ ] Use `@moonbitlang/coreFixedArray` for fixed 16-lane shuffle data.
  - Effort: `30 minutes`
  - Rationale: Better fixed-size performance than general arrays.
- [ ] Add `derive(Show, Debug, Eq)` across structs/enums where missing.
  - Effort: `15 minutes`
  - Rationale: Improves diagnostics and test debugging.

### 2.6 Roadmap & Next Steps (High Impact: Project Momentum)

- [ ] Build a tiny CLI (`moonbit-wasm`) with subcommands:
  - [ ] `wat2wasm`
  - [ ] `wasm2wat`
  - [ ] `opt --inline --dce`
  - [ ] `--validate`
  - Effort: `2–3 hours`
  - Rationale: Dogfoods and demonstrates the project.
- [ ] Implement one real optimizer pass using transformer (constant folding + DCE).
  - Effort: `1–2 hours`
  - Rationale: Validates architecture with practical results.
- [ ] Wire full text/binary roundtrip test:
  - [ ] `wast_to_module -> module_to_binary -> binary_to_module -> module_to_wast` plus normalization.
  - Effort: `1 hour`
  - Rationale: Provides end-to-end correctness coverage.
- [ ] Run and adapt the official WASM spec test suite in MoonBit pipeline.
  - Effort: `2 hours`
  - Rationale: Highest-confidence compatibility validation.

### 3) Compatibility Improvements

- [ ] JS Test Failure: [jtenner/starshine] test ir/ssa_optimize_tests.mbt:428 ("eval_ssa_unary i64 trunc_f32 handles values beyond i32 width") failed: ir/ssa_optimize_tests.mbt:431:3-434:4@jtenner/starshine FAILED: `Some(LitI64(3000000000)) != Some(LitI64(3000000000))`
- [ ] JS Test Failure: [jtenner/starshine] test ir/ssa_optimize_tests.mbt:492 ("eval_ssa_unary float-to-int trunc bound and trap parity checks") failed: ir/ssa_optimize_tests.mbt:531:3-534:4@jtenner/starshine FAILED: `Some(LitI64(9007199254740991)) != Some(LitI64(9007199254740991))`
- [ ] JS Test Failure: [jtenner/starshine] test passes/de_nan.mbt:1597 ("is_f32_nan correctly identifies NaN") failed: passes/de_nan.mbt:1600:3-1600:66@jtenner/starshine FAILED: Should detect quiet NaN
- [ ] JS Test Failure: [jtenner/starshine] test passes/de_nan.mbt:1610 ("is_f32_nan correctly rejects non-NaN") failed: passes/de_nan.mbt:1611:3-1611:63@jtenner/starshine FAILED: 0.0 is not NaN

---
Completed items are intentionally removed to keep this backlog actionable.
