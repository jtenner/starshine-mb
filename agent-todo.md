# Agent Tasks

## 0) Highest Priority (Cross-Package Audit: 2026-02-20)

- [x] P0: Close validation/transformer core gaps before adding new pass features.
  - [x] `src/validate/env.mbt` targeted tests for `with_module`, recursive `TypeIdx/RecIdx` resolution, and `to_texpr` stack-error branches (`1375` uncovered lines).
  - [x] `src/validate/typecheck.mbt` targeted negative tests for descriptor ops, atomics, and multi-value/control-flow error paths (`618` uncovered lines).
  - [x] `src/transformer/transformer.mbt` expand `walk_*` callback dispatch/error propagation tests over less-used `TInstr` variants (`643` uncovered lines).
- [x] P1: Harden binary codec correctness under invalid input and unsupported encodings.
  - [x] `src/binary/decode.mbt` add EOF/invalid-byte/error-bubbling tests through `src/binary/tests.mbt` (`410` uncovered lines).
  - [x] `src/binary/encode.mbt` add unsupported-type/index rejection tests and section payload propagation tests (`444` uncovered lines).
- [x] P1: Add direct IR core analysis tests (currently mostly integration-driven coverage).
  - [x] Add dedicated tests for `src/ir/ssa.mbt`, `src/ir/ssa_destruction.mbt`, `src/ir/gvn.mbt`, `src/ir/liveness.mbt`, and `src/ir/type_tracking.mbt`.
  - [x] Add invariants/tests around `src/ir/usedef.mbt` and `src/ir/types.mbt` for def-use and typed index consistency.
- [x] P1: Keep scheduler parity delivery moving after core infra hardening.
  - [x] Implement + test missing `src/passes/optimize.mbt` parity modes: `ssa-nomerge`, `flatten`, `rereloop`, `tuple-optimization`, `cfp-reftest`, `unsubtyping`, `generate-global-effects`.

## 0.5) Low-Hanging Fruit (Fast Test Wins)

- [x] Add direct tests for high-impact modules with no dedicated test file.
  - [x] `src/transformer/transformer.mbt`: add `Err` propagation + `Ok(None)` fallthrough tests in `src/transformer/tests.mbt`.
  - [x] `src/lib/types.mbt` + `src/lib/texpr.mbt`: add constructor/match/roundtrip smoke tests.
  - [x] `src/wast/keywords.mbt` + `src/wast/types.mbt`: add keyword classification + parser boundary tests.
- [x] Expand existing harnesses rather than adding new infra.
  - [x] Extend `src/binary/tests.mbt` with table-driven invalid-decode vectors.
  - [x] Extend `src/validate/env_tests.mbt` with import/type-stack edge cases.
  - [x] Extend `src/wast/module_wast_tests.mbt` with malformed module fixtures.
- [ ] Add one actionable audit item per `src/*` package to prevent regressions.
  - [ ] `src/binary`: decode/encode negative-path coverage expansion.
  - [ ] `src/ir`: dedicated SSA/GVN/liveness unit tests.
  - [ ] `src/lib`: types/texpr/pretty-print direct tests.
  - [ ] `src/passes`: close remaining optimize parity TODO flags + branch tests.
  - [ ] `src/transformer`: walk-dispatch variant coverage.
  - [ ] `src/validate`: env/typecheck edge-case coverage.
  - [ ] `src/wast`: parser/keywords/pretty-print edge-case coverage.

## 1) Scheduler / Feature Parity Gaps (`src/passes/optimize.mbt`)

- [x] `ssa-nomerge`
- [x] `flatten`
- [x] `rereloop`
- [x] `tuple-optimization`
- [x] open-world `remove-unused-module-elements` mode exposure
- [x] `cfp-reftest` mode
- [x] `unsubtyping`
- [x] `generate-global-effects`

## 2) Coverage + Quality Work

- [ ] Raise coverage in core infrastructure hotspots.
  - [ ] `src/validate/env.mbt`
  - [ ] `src/transformer/transformer.mbt`
  - [ ] `src/binary/decode.mbt`
  - [ ] `src/binary/encode.mbt`

- [ ] Add coverage-driven targets for additional optimizer hotspots.
  - [ ] `src/passes/minimize_rec_groups.mbt`
  - [ ] `src/passes/local_cse.mbt`
  - [ ] `src/passes/optimize_instructions.mbt`
  - [ ] `src/passes/precompute.mbt`

- [ ] Add a lightweight optimizer perf baseline.
  - [ ] Track compile time and output size on representative modules.
  - [ ] Start as non-blocking CI report, then graduate to threshold gating.

## 3) Refactorability / Maintainability

- [ ] Split very large files into focused units with colocated tests.
  - [ ] `src/validate/typecheck.mbt`
  - [ ] `src/validate/env.mbt`
  - [ ] `src/transformer/transformer.mbt`
  - [ ] `src/passes/optimize.mbt`
  - [ ] `src/passes/remove_unused.mbt`

- [ ] Standardize shared helpers for repeated unreachable-analysis patterns across passes.

## 4) Supporting Non-Pass Work

- [ ] Complete `src/wast/*.mbt` support.
  - [ ] Close remaining pretty-print parity gaps vs canonical wasm s-expression text output.

- [ ] Complete `src/wat/*.mbt` support (wasm 3.0 text format).
  - [ ] Lexer + tests
  - [ ] Parser + tests
  - [ ] Printer + tests
  - [ ] WAT -> WAST conversion helpers
  - [ ] WAT -> wasm types conversion helpers

## 5) Long-Tail Binaryen Backlog (Lower Priority)

- [ ] InstrumentBranchHints.cpp
- [ ] InstrumentLocals.cpp
- [ ] InstrumentMemory.cpp
- [ ] Intrinsics.cpp (toolchain-specific intrinsics handling)
- [ ] J2CLItableMerging.cpp
- [ ] J2CLOpts.cpp
- [ ] LegalizeJSInterface.cpp
- [ ] LimitSegments.cpp (special constraints / tool output shaping)
- [ ] LLVMMemoryCopyFillLowering.cpp
- [ ] LLVMNontrappingFPToIntLowering.cpp
- [ ] Memory64Lowering.cpp
- [ ] Metrics.cpp
- [ ] MinifyImportsAndExports.cpp (size/tooling)
- [ ] MultiMemoryLowering.cpp
- [ ] NoInline.cpp (policy pass)
- [ ] OptimizeForJS.cpp (JS environment heuristics)
- [ ] Outlining.cpp (size/codeshape; specialty)
- [ ] Poppify.cpp (codeshape / specialty)
- [ ] RandomizeBranchHints.cpp
- [ ] RemoveImports.cpp (tooling / linking pipeline)
- [ ] RemoveMemoryInit.cpp
- [ ] RemoveNonJSOps.cpp
- [ ] ReReloop.cpp (control-flow restructuring; specialty/structural)
- [ ] RoundTrip.cpp (testing/tooling)
- [ ] SafeHeap.cpp (hardening/instrumentation-ish; specialty)
- [ ] SeparateDataSegments.cpp (layout/tooling)
- [ ] SetGlobals.cpp (tooling / transformation utility)
- [ ] SignExtLowering.cpp
- [ ] Souperify.cpp (external superoptimizer integration; specialty)
- [ ] SpillPointers.cpp (GC/pointer mgmt strategy; niche)
- [ ] StackCheck.cpp (instrumentation / safety)
- [ ] StringLifting.cpp (feature transform; string/GC proposal adjacent)
- [ ] StringLowering.cpp (lowering counterpart)
- [ ] Strip.cpp (tooling; remove names/debug/sections)
- [ ] StripEH.cpp
- [ ] StripTargetFeatures.cpp
- [ ] TraceCalls.cpp
- [ ] TranslateEH.cpp
- [ ] TrapMode.cpp (policy/environment constraints)
- [ ] TupleOptimization.cpp (feature-specific; multivalue/tuple patterns)
- [ ] TypeFinalizing.cpp (final/open toggling; workflow / canonicalization; GC-specific)
- [ ] TypeGeneralizing.cpp (type relaxation/widening; type-system transform)
- [ ] TypeMerging.cpp (structural merging; type graph rewrite)
- [ ] TypeSSA.cpp (SSA-like form for types; enabling for type passes; niche)
- [ ] Unsubtyping.cpp (removes subtyping relations / flattens lattice; type graph rewrite)

---

Completed items are intentionally removed from this file to keep it actionable and current.
