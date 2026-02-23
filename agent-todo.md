# Agent Tasks

## Audit Snapshot (2026-02-23)

- `moon check`: `Finished. moon: no work to do`
- `moon test`: `2247` passed, `0` failed
- `moon coverage analyze`: `11078` uncovered line(s) in `103` file(s)
- Delta vs `2026-02-21` snapshot:
  - Tests: `2060 -> 2247` (`+187`)
  - Uncovered lines: `10980 -> 11078` (`+98`)
  - Files with uncovered lines: `96 -> 103` (`+7`)
- Largest uncovered hotspots:
  - `src/validate/env.mbt` (`1307`)
  - `src/transformer/transformer.mbt` (`593`)
  - `src/validate/typecheck.mbt` (`559`)
  - `src/binary/encode.mbt` (`403`)
  - `src/binary/decode.mbt` (`371`)
  - `src/passes/heap2local.mbt` (`366`)
  - `src/lib/types.mbt` (`329`)
  - `src/passes/merge_blocks.mbt` (`286`)
  - `src/lib/show.mbt` (`271`)
  - `src/ir/ssa.mbt` (`252`)

## Low Hanging Fruit

- [ ] Add scheduler-level regression coverage for `default_global_optimization_pre_passes` to assert `AbstractTypeRefiningPassProps.traps_never_happen` is sourced from `OptimizeOptions`.
- [ ] Extend `to_texpr` multi-value return-recovery tests for typed `loop` and `try_table` producers.
- [ ] Add preset expansion semantics and tests proving optimize presets run before explicitly listed pass flags.
- [ ] Add filesystem adapter tests for glob expansion once runtime integration layer is introduced.
- [ ] Document and/or align non-standard section payload-length encoding for `StartSec`/`CodeSec`/`DataCntSec`.
  - [ ] Add explicit codec tests and parity note if the current encoding shape is intentional.
- [ ] Use `@moonbitlang/coreFixedArray` for fixed 16-lane shuffle data.
- [ ] Add `derive(Show, Debug, Eq)` across structs/enums where missing.

## High Priority

### Correctness and Regressions

- [ ] Fix JS failure in `ir/ssa_optimize_tests.mbt:428` (`eval_ssa_unary i64 trunc_f32 handles values beyond i32 width`).
- [ ] Fix JS failure in `ir/ssa_optimize_tests.mbt:492` (`eval_ssa_unary float-to-int trunc bound and trap parity checks`).
- [ ] Fix JS failure in `passes/de_nan.mbt:1597` (`is_f32_nan correctly identifies NaN`).
- [ ] Fix JS failure in `passes/de_nan.mbt:1610` (`is_f32_nan correctly rejects non-NaN`).

### CLI Pipeline Completion

- [ ] Wire parsed pass flags and optimize presets into concrete optimizer pipeline scheduling (`ModulePass`) with strict unknown-pass diagnostics.
- [ ] Implement JSON config file loading/validation and precedence merge (`CLI args > env > config defaults`) on top of current schema.

### Multi-Value and Trap-Mode Safety

- [ ] Broaden multi-value hoist parity and fallback safety.
  - [ ] Add focused tests for hoisted multi-value try-tail wrappers when callers have parameters, ensuring typed-wrapper selection stays valid.
  - [ ] Add focused tests that non-defaultable result types (for example non-null refs) stay on the non-hoist fallback path without validator errors.
- [ ] Add user-facing optimize option plumbing (`TrapMode`/CLI flags) for `OptimizeOptions.traps_never_happen` so scheduler trap mode is configurable in end-to-end tool flows.
- [ ] Clarify and codify `br_on_cast` exact-flag semantics in IR docs/types (separate from nullability) and add mixed exact/non-exact branch parity fixtures.

### Binaryen Pass Parity (High)

- [ ] `TypeFinalizing`
- [ ] `Unsubtyping`
- [ ] `GlobalEffects`
- [ ] `Poppify`
- [ ] `ReReloop`
- [ ] `Outlining`

## Medium Priority

### Architecture and Refactoring

- [ ] Split oversized files for maintainability and faster targeted testing.
  - [ ] `src/validate/typecheck.mbt`
  - [ ] `src/validate/env.mbt`
  - [ ] `src/transformer/transformer.mbt`
  - [ ] `src/passes/optimize.mbt`
  - [ ] `src/passes/remove_unused.mbt`
- [ ] Split the giant parser file (`parser.mbt`) into smaller modules.
  - [ ] `lexer.mbt`
  - [ ] `parser_types.mbt`
  - [ ] `parser_instructions.mbt`
  - [ ] `parser_folded.mbt`
  - [ ] `parser_gc.mbt`
  - [ ] `parser_tests.mbt`
- [ ] Split instruction decoder (`decode_instruction` in `decode.mbt`) into helpers.
  - [ ] `decode_core_opcode`
  - [ ] `decode_extended_0xFB`
  - [ ] `decode_extended_0xFC`
  - [ ] `decode_extended_0xFD`
  - [ ] `decode_extended_0xFE`
- [ ] Turn validator into a `ModuleTransformer`.
  - [ ] Implement `Validator` struct with hooks such as `on_func_evt`, `on_tinstruction_evt`, and `on_global_evt`.
  - [ ] Add `validate_module(mod: Module) -> Result[Unit, ValidationError]`.
- [ ] Replace lexer backtracking (`save/restore_lexer_state`) with one-token lookahead.
  - [ ] Introduce `Parser { peeked: Token? }` or add zero-cost `peek()/consume()` to `WastLexer`.

### Performance and Allocation

- [ ] Add capacity reservations in hot paths (`parse_instructions`, expr decoding, and similar array builds).
- [ ] Use unchecked indexing in core decode loops after upfront length validation.
- [ ] Avoid temporary `Module` copies in decoder.
  - [ ] Use mutable builder flow or single record update at the end.
- [ ] Create a `WastWriter` trait.
  - [ ] Support `StringBuilder`, `Vec<u8>`, and streaming sinks.
  - [ ] Reuse one `StringBuilder` across module rendering.
- [ ] Add `quick_mode: Bool` to generator to reduce types/locals/segments for fast fuzzing.
- [ ] Build a non-blocking optimizer perf baseline (compile time and output size) on representative modules.

### Testing, Fuzzing, and Reliability

- [ ] Enhance generator with additional edge cases.
  - [ ] Recursive/self-referencing struct types.
  - [ ] Deep `block`/`loop`/`if` nesting.
  - [ ] Functions with `0-16` returns (multi-value).
  - [ ] Large local counts.
- [ ] Add more fuzz coverage to validate invalid modules.
- [ ] Implement one real optimizer pass using transformer (constant folding + DCE).
- [ ] Wire full text/binary roundtrip test.
  - [ ] `wast_to_module -> module_to_binary -> binary_to_module -> module_to_wast` plus normalization.
- [ ] Run and adapt the official WASM spec test suite in the MoonBit pipeline.

### Error Handling and Public APIs

- [ ] Replace string decode errors with a typed `DecodeError` enum.
  - [ ] Add variants such as `UnexpectedEof { offset: Int, section: String }` and `InvalidOpcode { offset: Int, byte: Byte }`.
  - [ ] Mirror the same enum-based approach for `ValidationError`.
- [ ] Expose binary public APIs.
  - [ ] `decode_module(bytes: Bytes) -> Result[Module, DecodeError]`
  - [ ] `encode_module(mod: Module) -> Result[Bytes, EncodeError]`
- [ ] Add streaming/zero-copy decoder API via cursor-based `Decoder` struct.
- [ ] Switch negative tests to enum-based error assertions instead of string matching.

### Binaryen Pass Parity (Medium)

- [ ] `DeAlign`
- [ ] `EncloseWorld`
- [ ] `ExtractFunction`
- [ ] `FuncCastEmulation`
- [ ] `GenerateDynCalls`
- [ ] `LimitSegments`
- [ ] `Memory64Lowering`
- [ ] `MultiMemoryLowering`
- [ ] `NoInline`
- [ ] `RemoveImports`
- [ ] `RemoveMemoryInit`
- [ ] `RemoveRelaxedSIMD`
- [ ] `SafeHeap`
- [ ] `SeparateDataSegments`
- [ ] `SetGlobals`
- [ ] `SignExtLowering`
- [ ] `Souperify`
- [ ] `SpillPointers`
- [ ] `StringLifting`
- [ ] `StringLowering`
- [ ] `StripEH`
- [ ] `TranslateEH`
- [ ] `TrapMode`
- [ ] `MinifyImportsAndExports`

## Low Priority

- [ ] Generate keyword/opcode tables from a small DSL or MoonBit macros (with manual exception overrides).
- [ ] Continue long-tail Binaryen parity only after core coverage hotspots are reduced.

### Binaryen Pass Parity (Low)

- [ ] `DWARF`
- [ ] `DebugLocationPropagation`
- [ ] `InstrumentBranchHints`
- [ ] `InstrumentLocals`
- [ ] `InstrumentMemory`
- [ ] `Intrinsics`
- [ ] `J2CLItableMerging`
- [ ] `J2CLOpts`
- [ ] `LLVMMemoryCopyFillLowering`
- [ ] `LLVMNontrappingFPToIntLowering`
- [ ] `LegalizeJSInterface`
- [ ] `LogExecution`
- [ ] `Metrics`
- [ ] `NameList`
- [ ] `NameTypes`
- [ ] `OptimizeForJS`
- [ ] `PostEmscripten`
- [ ] `Print`
- [ ] `PrintCallGraph`
- [ ] `PrintFeatures`
- [ ] `PrintFunctionMap`
- [ ] `RandomizeBranchHints`
- [ ] `RemoveNonJSOps`
- [ ] `RoundTrip`
- [ ] `StackCheck`
- [ ] `Strip`
- [ ] `StripTargetFeatures`
- [ ] `StripToolchainAnnotations`
- [ ] `TraceCalls`

---
Completed tasks were removed to keep this list focused on open work.
