# Agent Tasks

## Blockers

- Native default text lowering now calls external tools (`wat2wasm`/`wasm-tools parse`); environments without either tool still cannot lower `.wat`/`.wast` via `run_cmd`.

## Metadata

- Last updated: `2026-02-24`
- Scope: Open tasks plus recently completed checkoffs
- Last audit run: `2026-02-24`
  - `moon fmt`: `Finished. moon: ran 1 task, now up to date`
  - `moon info`: `Finished. moon: no work to do`
  - `moon test`: `2400` passed, `0` failed
  - `moon test src/cmd --target native`: `17` passed, `0` failed
  - `moon build --target native`: `not run in this audit`
  - `moon coverage analyze`: `11223` uncovered line(s) in `105` file(s)

## Priority 0 (Critical Path)

### CLI Pipeline Completion

- [x] Wire parsed pass flags and optimize presets into concrete optimizer pipeline scheduling (`ModulePass`) with strict unknown-pass diagnostics.
  - [x] Consume `resolve_pass_flags(...)` output in the CLI execution path and translate preset markers to concrete scheduler pipelines.
  - [x] Include explicit string-to-`ModulePass` mapping coverage for `global-effects` when the runtime pipeline wiring lands.
  - [x] Thread `resolve_traps_never_happen(...)` into the CLI runtime optimize-options builder so `OptimizeOptions.traps_never_happen` is applied during real module runs.
  - [x] Hook `expand_globs_with_adapter(...)` into the eventual runtime filesystem input-expansion path.
  - [x] Decide and codify duplicate handling when preset-expanded passes overlap explicit pass flags (preserve repeats vs dedupe), with regression tests.
- [x] Implement JSON config file loading/validation and precedence merge (`CLI args > env > config defaults`) on top of current schema.
- [x] Add inline JSON config ingestion to `run_cmd_with_adapter(...)` so callers can pass `argv` and config content in one call.
- [x] Add explicit CLI optimization-option flags (`--optimize-level`, `--shrink-level`, `--monomorphize-min-benefit`, `--low-memory-unused`, `--no-low-memory-unused`, `--low-memory-bound`) and precedence tests against config `options`.
- [ ] Finish native runtime plumbing for `cmd`.
  - [x] Real native `CmdIO` wiring for env/files/stdout in `default_cmd_io()`.
  - [x] Native runtime regression tests for default `run_cmd` IO path (read/write/env/stdout write-failure propagation).
  - [x] Add native default filesystem candidate enumeration for wildcard-glob expansion.
  - [x] Add native default `.wat`/`.wast` text-module lowering hook (native external-tool fallback).
- [ ] Add focused CLI/runtime tests for:
  - [x] optimize/shrink preset expansion behavior under non-zero `-O*` levels.
  - [x] duplicate pass handling policy (preserve repeats vs dedupe) and deterministic scheduling order.
  - [ ] runtime error propagation/exit signaling for config read failures, decode failures, and output write failures.
    - [x] native `run_cmd --stdout` output-write failure propagation when stdout fd is closed.
    - [ ] config read failures.
    - [ ] decode failures.
  - [ ] assert expanded `ModulePass` multiplicity for preset+explicit overlaps at scheduler level (not only resolved flag queue order).
  - [ ] add focused env precedence tests for pass/option overlays after config-fallback changes.

### Text Frontend (WAT)

- [x] Add a new `src/wat` package with wat-named APIs and behavior parity backed by `src/wast`.
- [x] Expose wat-named text APIs: `wat_to_module`, `module_to_wat`, `module_to_wat_with_context`, `wat_to_script`, `script_to_wat`, `script_to_wat_with_context`.
- [x] Add wat package test coverage mirroring wast keyword/module/pretty/fuzz behavior with wat-named entrypoints.
- [x] Backport the `WastParser::check` token-family completeness fix from `src/wat/parser.mbt` to `src/wast/parser.mbt` so script commands (`register`, `assert_*`, etc.) parse through `expect(...)`.
- [x] Consolidate duplicated text frontend code between `src/wast` and `src/wat` (make `src/wat` a thin wrapper over `src/wast`).
- [ ] Add optional native in-process text lowering path (remove external `wat2wasm`/`wasm-tools` dependency for `.wat/.wast` inputs).

### Binaryen Pass Parity (High)

- [x] `GlobalEffects`
- [x] `ReReloop`
- [ ] `Poppify`
- [ ] `Outlining`
- [ ] ReReloop hardening follow-ups.
  - [x] Replace current `ReReloop -> merge_blocks` fallback with a dedicated CFG + relooper reconstruction implementation for flattened control flow.
  - [x] Add explicit `ReReloop` precondition checks and diagnostics for unsupported EH instructions (`try`/`throw`/`rethrow`) to match Binaryen behavior.
  - [x] Add explicit flatness precondition checks so non-flat control-flow trees are rejected with actionable diagnostics.
  - [x] Add integration tests covering `--optimize` (`-O4`) default pipeline ordering with `Flatten -> LocalCSE -> ReReloop`.
  - [x] Expand ReReloop CFG reconstruction coverage beyond current flattened conditional-break blocks (`br_if` shells) to include `br_on*`, `br_table`, and branch-value flows.
  - [x] Add focused ReReloop loop-region reconstruction tests (flattened `loop` + backedge patterns) and implement matching CFG relayout support.
  - [ ] Preserve single-evaluation semantics for `br_table` dispatch indices during ReReloop lowering (avoid repeated index expression evaluation in nested-if expansion).
  - [ ] Extend ReReloop CFG relayout to support non-special branch targets and merge-heavy flattened regions (current lowering focuses on break/continue-to-special-target shells).

## Priority 1 (High Leverage)

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
- [ ] Expose `GlobalEffects` analysis results for downstream pass consumption (for example via `IRContext` cache or scheduler-owned side channel) instead of recomputing and discarding.
- [ ] Consolidate duplicated shallow-effect classifiers across passes into shared helpers to reduce drift (`local_cse`, `global_effects`, `loop_invariant_code_motion`, `heap_store_optimization`, `optimize_casts`, `monomorphize`).
- [ ] Replace lexer backtracking (`save/restore_lexer_state`) with one-token lookahead.
  - [ ] Introduce `Parser { peeked: Token? }` or add zero-cost `peek()/consume()` to `WastLexer`.

### Error Handling and Public APIs

- [ ] Replace string decode errors with a typed `DecodeError` enum.
  - [ ] Add variants such as `UnexpectedEof { offset: Int, section: String }` and `InvalidOpcode { offset: Int, byte: Byte }`.
  - [ ] Mirror the same enum-based approach for `ValidationError`.
- [ ] Expose binary public APIs.
  - [ ] `decode_module(bytes: Bytes) -> Result[Module, DecodeError]`
  - [ ] `encode_module(mod: Module) -> Result[Bytes, EncodeError]`
- [ ] Add streaming/zero-copy decoder API via cursor-based `Decoder` struct.
- [ ] Switch negative tests to enum-based error assertions instead of string matching.

## Priority 2 (Quality and Performance)

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

## Priority 3 (Backlog)

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
