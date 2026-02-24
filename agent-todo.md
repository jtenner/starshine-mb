# Agent Tasks

## Blockers

- `Unsubtyping` still produces invalid output for certain `try_table` `Catch::ref_` payload+`exnref` shapes; current parity fixture pins this as a stable failure (`type mismatch`) until full support lands.

## Audit Snapshot (2026-02-23)

- `moon check`: `Finished. moon: no work to do`
- `moon test`: `2268` passed, `0` failed
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

- [x] Add `RemoveUnused` descriptor-op coverage (`ref.get_desc`, `ref.test_desc`, `ref.cast_desc_eq`) across both `Instruction` and `TInstr`, including regression tests.
- [x] Add scheduler-level regression coverage for `default_global_optimization_pre_passes` to assert `AbstractTypeRefiningPassProps.traps_never_happen` is sourced from `OptimizeOptions`.
- [x] Extend `to_texpr` multi-value return-recovery tests for typed `loop` and `try_table` producers.
- [x] Add preset expansion semantics and tests proving optimize presets run before explicitly listed pass flags.
- [x] Add filesystem adapter tests for glob expansion once runtime integration layer is introduced.
- [x] Document and/or align non-standard section payload-length encoding for `StartSec`/`CodeSec`/`DataCntSec`.
  - [x] Add explicit codec tests and parity note if the current encoding shape is intentional.
- [x] Use `@moonbitlang/coreFixedArray` for fixed 16-lane shuffle data.
- [x] Add `derive(Show, Debug, Eq)` across structs/enums where missing.

## High Priority

### Correctness and Regressions

- [x] Audit exactness handling of descriptor ops in `passes/heap2local.mbt` and `passes/gufa.mbt`; `heap2local` now enforces exact descriptor matching and `gufa` has regression guards to prevent subtype-based folding for exact descriptor ops.
- [x] Audit `remove_unused_with_props` section-filter callbacks (`type_sec`, `import_sec`, `global_sec`, `elem_sec`, `data_sec`) to ensure nested index remaps are still applied after filtering, with targeted regression tests.
- [ ] Fix JS failure in `ir/ssa_optimize_tests.mbt:428` (`eval_ssa_unary i64 trunc_f32 handles values beyond i32 width`).
- [ ] Fix JS failure in `ir/ssa_optimize_tests.mbt:492` (`eval_ssa_unary float-to-int trunc bound and trap parity checks`).
- [ ] Fix JS failure in `passes/de_nan.mbt:1597` (`is_f32_nan correctly identifies NaN`).
- [ ] Fix JS failure in `passes/de_nan.mbt:1610` (`is_f32_nan correctly rejects non-NaN`).

### CLI Pipeline Completion

- [ ] Wire parsed pass flags and optimize presets into concrete optimizer pipeline scheduling (`ModulePass`) with strict unknown-pass diagnostics.
  - [ ] Consume `resolve_pass_flags(...)` output in CLI execution path and translate preset markers to concrete scheduler pipelines.
  - [ ] Thread `resolve_traps_never_happen(...)` into the CLI runtime optimize-options builder so `OptimizeOptions.traps_never_happen` is applied during real module runs.
  - [ ] Hook `expand_globs_with_adapter(...)` into the eventual runtime filesystem input-expansion path.
  - [ ] Decide and codify duplicate handling when preset-expanded passes overlap explicit pass flags (preserve repeats vs dedupe), with regression tests.
- [ ] Implement JSON config file loading/validation and precedence merge (`CLI args > env > config defaults`) on top of current schema.

### Multi-Value and Trap-Mode Safety

- [x] Broaden multi-value hoist parity and fallback safety.
  - [x] Add focused tests for hoisted multi-value try-tail wrappers when callers have parameters, ensuring typed-wrapper selection stays valid.
  - [x] Add focused tests that non-defaultable result types (for example non-null refs) stay on the non-hoist fallback path without validator errors.
- [x] Add user-facing optimize option plumbing (`TrapMode`/CLI flags) for `OptimizeOptions.traps_never_happen` so scheduler trap mode is configurable in end-to-end tool flows.
- [x] Clarify and codify `br_on_cast` exact-flag semantics in IR docs/types (separate from nullability) and add mixed exact/non-exact branch parity fixtures.
- [x] Extend multi-value hoist wrapper recovery to synthesize a private zero-param signature when no compatible existing `TypeIdx` is available.
- [x] Add mirrored mixed exact/non-exact `br_on_cast_fail` parity fixtures in `abstract_type_refining.mbt` to guard rewrite behavior across both branch opcodes.
- [x] Defer synthetic hoist-wrapper type insertion until a hoist rewrite is confirmed, so failed rewrites cannot leave unused private signatures.
- [x] Add full-pass (`run_abstract_type_refining_pass`) parity fixtures that assert mixed exact/non-exact `br_on_cast` and `br_on_cast_fail` behavior survives end-to-end traversal.
- [x] Add multi-caller same-iteration coverage for synthesized hoist wrappers to verify deferred commit index sequencing across successive type insertions.
- [x] Add nested value-tree full-pass ATR fixtures (for example branch-cast nodes inside `local.set`/`drop` trees) to lock in recursive traversal guarantees.
- [x] Add a mixed multi-caller reuse fixture where later callers reuse an earlier synthesized wrapper signature instead of adding duplicates.
- [x] Add deep nested ATR fixtures across `if`/`block`/`try_table` value positions to guard recursive traversal beyond `local.set`/`drop`.
- [x] Add a mixed-reuse negative fixture where one later caller cannot reuse the earlier synthesized wrapper (different result arity/types), proving no accidental over-reuse.
- [x] Add ATR deep-nesting fixtures with non-empty `try_table` catches and nested cast nodes in both `then` and `else` trees to lock in traversal across handler-bearing control flow.
- [x] Add validator-clean handler-bearing ATR fixtures (with label/catch typing that validates) so deep nested catch-path traversal is covered under `validate_module == Ok(())`.
- [x] Add handler-bearing ATR fixtures with real `throw` paths to ensure cast rewrites remain stable when catches are actually taken.
- [x] Add handler-bearing ATR fixture variants that use typed tag catches (`Catch::new` / `Catch::ref_`) with non-empty payload signatures, validating rewrite stability under typed exception parameters.
- [x] Add a targeted regression test for exact `ref_cast` rewrites under `drop` contexts in traps-never-happen mode (either preserving validator-clean lowering or documenting unsupported shape explicitly).
- [x] Align `try_table` catch label lookup with depth-based `Env::get_label_types(...)` semantics (currently direct index access), and add regression tests to pin catch-vs-branch label index parity.
- [x] Add a dedicated `Env` helper for catch-label type lookup and migrate both validator/typecheck and pass consumers to it (remove duplicated ad-hoc index conversion logic).

### Binaryen Pass Parity (High)

- [x] `TypeFinalizing`
- [x] `Unsubtyping`
- [x] Extend `Unsubtyping` subtype-constraint discovery to cover branch/label flow constraints (`br`, `br_if`, `br_table`, typed `block/loop/if` joins) with focused regression tests.
- [x] Add `Unsubtyping` trap-mode parity fixtures for `call_indirect` / `return_call_indirect` to lock in `traps_never_happen` behavior against Binaryen expectations.
- [x] Add descriptor-edge parity for exact descriptor ops by preserving required subtype constraints in `Unsubtyping` (typed + untyped `ref.test_desc` / `ref.cast_desc_eq` fixtures).
- [x] Extend `Unsubtyping` control-flow subtype discovery to `try_table` catch bodies and catch-target label flows, with parity fixtures.
- [x] Add `Unsubtyping` regression coverage for implicit function-label branch flows (`br` / `br_if` targeting outermost function label).
- [x] Generalize `Unsubtyping` typed-join subtype discovery beyond single-result joins (multi-value `block` / `loop` / `if`).
- [x] Add `Unsubtyping` parity fixtures for `try_table` `Catch::ref_` / `Catch::all_ref` flows to pin payload+`exnref` handling and prevent regressions.
  - [ ] Follow-up: make `Catch::ref_` payload+`exnref` fixtures pass end-to-end in `unsubtyping` (current fixture intentionally pins stable invalid-output failure mode).
- [x] Add `RemoveUnused` pipeline-level regression (through `optimize_module` scheduling) proving descriptor-target-only types survive remapping in mixed typed/untyped function bodies.
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
