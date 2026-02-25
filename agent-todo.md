# Agent Tasks

## Blockers
- [x] Native default text lowering still depends on external tools (`wat2wasm` / `wasm-tools parse`); environments without either tool cannot lower `.wat` / `.wast` via `run_cmd`.
- [x] In-process fallback is blocked by missing lowering bridge from `@wast.Module` (text AST) to binary IR `@lib.Module` (required by `@binary.Encode` in `run_cmd` pipeline).

## Goal
Reach v0.1.0 “production-ready for MoonBit users” by end of March 2026: full native CLI, spec-test passing validator+optimizer, clean public API, and maintainable codebase.

## Metadata
- Last updated: `2026-02-25`
- Scope: Open tasks plus recently completed checkoffs
- Last audit run: `2026-02-25`
- `moon fmt`: `Finished. moon: ran 6 tasks, now up to date`
- `moon info`: `Finished. moon: ran 2 tasks, now up to date`
- `moon test`: `2419` passed, `0` failed
- `moon test src/cmd --target native`: `17` passed, `0` failed
- `moon build --target native`: `not run in this audit`
- `moon coverage analyze`: `11223` uncovered line(s) in `105` file(s)

## Priority 0 (Critical Path: ship blockers)

### CLI/runtime completion
- [x] Real native `CmdIO` wiring for env/files/stdout in `default_cmd_io()`.
- [x] Native runtime regression tests for default `run_cmd` IO path (read/write/env/stdout write-failure propagation).
- [x] Native default filesystem candidate enumeration for wildcard-glob expansion.
- [x] Native default `.wat`/`.wast` text-module lowering hook (native external-tool fallback).
- [ ] Add focused runtime error-path tests:
  - [x] config read failures.
  - [x] decode failures.
  - [x] input read failures.
- [x] Add scheduler-level tests that assert expanded `ModulePass` multiplicity for preset+explicit overlaps (not only resolved flag queue order).
- [x] Add focused env precedence tests for pass/option overlays after config-fallback changes.
- [x] Add `--help` and `--version` coverage/polish checks in CLI behavior tests.
- [ ] Add CLI integration coverage for `CmdError::EncodeFailed` (currently only pipeline helper path is exercised; no end-to-end fixture reaches encode failure after decode+optimize).

### Text frontend unblock
- [x] Add `src/wat` package with wat-named API parity backed by `src/wast`.
- [x] Expose wat APIs: `wat_to_module`, `module_to_wat`, `module_to_wat_with_context`, `wat_to_script`, `script_to_wat`, `script_to_wat_with_context`.
- [x] Mirror wast tests with wat-named entrypoints.
- [x] Backport `WastParser::check` token-family completeness fix to `src/wast/parser.mbt`.
- [x] Consolidate duplicated text frontend logic by making `src/wat` a thin wrapper.
- [ ] Add optional native in-process text lowering path (remove external tool dependency).
  - [x] Design/implement `wast -> lib` lowering bridge (name/index resolution + section construction) so `run_cmd` can encode parser output without shelling out.
  - [x] Add adapter-level fallback tests that run without `lower_text_module` and still lower `.wat` / `.wast` through the in-process bridge.
  - [ ] Extend `wast -> lib` lowering coverage for currently unsupported instruction families (SIMD lanes/prefixed op variants and advanced reference/exception forms) so in-process lowering can replace external tools for broader real-world text inputs.
  - [ ] Broaden grouped recursive type handling in lowering bridge function-signature resolution (currently conservative for grouped rec types).

### High-impact pass parity
- [ ] `Poppify`
- [ ] `Outlining`
- [ ] ReReloop hardening follow-ups:
  - [x] Preserve single-evaluation semantics for `br_table` dispatch indices during lowering.
  - [x] Extend CFG relayout to support non-special targets and merge-heavy flattened regions.
  - [ ] Add temp-local based single-eval lowering path for non-dup-safe `br_table` indices when targets are not directly label-resolvable.

### Public API gate
- [x] Expose clean public API surface for decode/optimize/encode workflows in package exports and README examples.

## Priority 1 (Release readiness: correctness + testing)

### Validation, decoding, and error model
- [x] Replace string decode errors with typed `DecodeError` enum.
- [ ] Mirror enum-based approach for `ValidationError`.
- [ ] Add richer `DecodeError` variants with source spans (`offset`, `length`) for malformed trailing/section contexts and thread them through `decode_module`.
- [ ] Add source spans (`offset + length`) to public error types where applicable.
- [ ] Switch negative tests from string matching to enum assertions.
- [x] Expose binary public APIs:
  - [x] `decode_module(bytes: Bytes) -> Result[Module, DecodeError]`
  - [x] `encode_module(mod: Module) -> Result[Bytes, EncodeError]`

### Correctness test expansion
- [ ] Integrate official WebAssembly spec test suite in MoonBit pipeline.
- [ ] Add wasm-smith fuzzing harness (decode -> validate -> optimize -> encode -> roundtrip).
- [ ] Add differential testing vs `wasm-tools` / Binaryen.
- [ ] Wire full text/binary roundtrip test (`wast_to_module -> module_to_binary -> binary_to_module -> module_to_wast` + normalization).
- [ ] Add more fuzz coverage for invalid modules.
- [ ] Achieve >=75% line coverage on hot paths (decoder, IR lift, top passes).

## Priority 2 (Maintainability and architecture)

### Split oversized files
- [ ] `src/validate/typecheck.mbt`
- [ ] `src/validate/env.mbt`
- [ ] `src/transformer/transformer.mbt`
- [ ] `src/passes/optimize.mbt`
- [ ] `src/passes/remove_unused.mbt`
- [ ] `src/wast/parser.mbt` into:
  - [ ] `lexer.mbt`
  - [ ] `parser_types.mbt`
  - [ ] `parser_instructions.mbt`
  - [ ] `parser_folded.mbt`
  - [ ] `parser_gc.mbt`
  - [ ] `parser_tests.mbt`
- [ ] Split `decode_instruction` in `decode.mbt` into helpers:
  - [ ] `decode_core_opcode`
  - [ ] `decode_extended_0xFB`
  - [ ] `decode_extended_0xFC`
  - [ ] `decode_extended_0xFD`
  - [ ] `decode_extended_0xFE`

### Transformer and analysis refactors
- [ ] Turn validator into a `ModuleTransformer` (`Validator` hooks + `validate_module`).
- [ ] Expose `GlobalEffects` analysis outputs for downstream pass reuse (via `IRContext` cache or scheduler side-channel).
- [ ] Consolidate shallow-effect classifiers across passes (`local_cse`, `global_effects`, `loop_invariant_code_motion`, `heap_store_optimization`, `optimize_casts`, `monomorphize`).
- [ ] Replace parser lexer backtracking (`save/restore_lexer_state`) with one-token lookahead (`peeked: Token?` or lexer `peek()/consume()`).

## Priority 3 (Performance and pass breadth)

### Performance and allocation
- [ ] Add capacity reservations in hot paths (`parse_instructions`, expr decoding, similar array builds).
- [ ] Use unchecked indexing in core decode loops after upfront length validation.
- [ ] Avoid temporary `Module` copies in decoder (builder flow or single record update).
- [ ] Create a `WastWriter` trait:
  - [ ] support `StringBuilder`, `Vec<u8>`, streaming sinks
  - [ ] reuse one `StringBuilder` across module rendering
- [ ] Add `quick_mode: Bool` to generator for faster fuzzing.
- [ ] Build non-blocking optimizer perf baseline (compile time and output size) on representative modules.

### Generator/test depth improvements
- [ ] Add generator edge cases:
  - [ ] recursive/self-referencing struct types
  - [ ] deep `block` / `loop` / `if` nesting
  - [ ] functions with `0-16` returns
  - [ ] large local counts
- [ ] Implement one real optimizer pass using transformer (constant folding + DCE).

### Binaryen pass parity (medium)
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

## Priority 4 (Polish and long-term backlog)

### Productization and docs
- [ ] Expand `README.md` with architecture diagram, CLI examples, benchmark table, and rationale.
- [ ] Add `examples/` directory with real-world snippets.
- [ ] Publish first release + MoonBit registry package (`moon publish` + GitHub Release binaries).

### Platform/features backlog
- [ ] Component Model / WIT support.
- [ ] Streaming / zero-copy decoder API.
- [ ] Custom sections, name section, source maps.
- [ ] Plugin system for third-party passes.

### Binaryen pass parity (low)
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

### Vision (Q2-Q3 2026)
- [ ] Self-hosting: use Starshine to optimize the MoonBit compiler.
- [ ] Formal verification of validator.
- [ ] Benchmark suite vs wasm-opt target envelope.
- [ ] Security audit.
- [ ] Community foundation (`CONTRIBUTING.md`, issue templates, Discord/community channel).
