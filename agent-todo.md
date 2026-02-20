# Agent Tasks

## 0) Immediate High-Value Changes (Repo Audit)

- [ ] Add CI quality gates for `moon info && moon fmt`, `moon check`, and `moon test` on PRs/main.
  - [ ] Add warning-regression gating for `moon check`.
  - [ ] Keep Copilot setup workflow separate from validation/test workflows.

- [ ] Expose open-world `remove_unused` mode in default scheduler wiring.
  - [ ] Add option/path in `default_global_optimization_pre_passes(...)` to schedule open-world behavior.
  - [ ] Add scheduler-level tests for closed-world vs open-world dispatch.

- [ ] Fix SSA truncation constant-folding semantics and test coverage.
  - [ ] Audit `I64TruncF32S/U` and adjacent float-to-int folds in `src/ir/ssa_optimize.mbt`.
  - [ ] Add edge-case tests (NaN, infinities, signed/unsigned bounds, trap semantics parity).

- [ ] Complete `AlignmentLowering` parity for V128 extending loads.
  - [ ] Finish lowering support in `src/passes/alignment_lowering.mbt`.
  - [ ] Add signed/unsigned regression tests for all V128 extending-load variants.

- [ ] Add targeted pass coverage in high-uncovered/high-risk optimizer files.
  - [ ] `src/passes/heap2local.mbt`
  - [ ] `src/passes/merge_blocks.mbt`
  - [ ] `src/passes/remove_unused.mbt`
  - [ ] `src/passes/signature_refining.mbt`

## 1) Core Project Prerequisites

- [ ] Stabilize IRContext + dataflow foundations.
  - [ ] Migrate remaining passes to IRContext usage:
    - [ ] `src/passes/de_nan.mbt`
    - [ ] `src/passes/remove_unused.mbt`

- [x] Add wasm atomics/threading support (threads proposal core instruction surface).
  - [x] Extend IR/typed instruction + validator + binary + transformer support for full threads atomics instruction set (wait/notify/fence/load/store/rmw/cmpxchg).
  - [x] Add IR/optimizer compatibility coverage for atomic instruction variants (SSA, alignment lowering, local CSE, merge/dead-code/simplification pipelines).
  - [ ] Re-enable atomics-dependent parity work in Heap2Local / HeapStoreOptimization (now unblocked by core instruction support).

## 2) Parity Backlog For Implemented Binaryen Passes

- [x] `Binaryen Pass: GlobalStructInference.cpp` parity hardening.
  - [x] Implemented descriptor-mode `ref.cast` optimization path (conservative singleton-global lowering in current IR surface).
  - [x] Added descriptor-mode parity tests for rewrite and safety gating behavior.
  - [x] Complete full descriptor parity (IR enablement + opcode parity).
    - [x] Extend core IR model with descriptor operations:
      - [x] Add typed instruction variants for descriptor reads (`ref.get_desc`) and descriptor-equality casts (`ref.cast_desc_eq` / `ref.test_desc`) in `src/lib/types.mbt`.
      - [x] Add corresponding constructors/helpers and traversal hooks in `src/lib/types.mbt`, `src/lib/texpr.mbt`, and `src/transformer/transformer.mbt`.
    - [x] Extend validator/typechecker for descriptor op semantics:
      - [x] Add typing rules and stack effects in `src/validate/typecheck.mbt`.
      - [x] Add environment/type-resolution helpers needed for descriptor typing in `src/validate/env.mbt`.
      - [x] Add subtyping/matching coverage updates in `src/validate/match.mbt` as needed.
    - [x] Extend binary and text-format support for descriptor ops:
      - [x] Decode/encode opcodes and immediates in `src/binary/decode.mbt` and `src/binary/encode.mbt`.
      - [x] Add WAST parser/printer/keywords support in `src/wast/*.mbt`.
      - [x] Add binary roundtrip and parser/printer regression tests.
    - [x] Implement full `GlobalStructInferenceDescCast` parity on top of new IR ops:
      - [x] Optimize `ref.cast` -> descriptor-equality cast when descriptor global is singleton and subtype constraints allow.
      - [x] Optimize descriptor reads (`ref.get_desc`) using global-struct inference (including constant/select grouping behavior).
      - [x] Preserve exact-cast / strict-subtype safety and null-trap behavior parity.
    - [x] Integrate cross-pass compatibility for new IR surface:
      - [x] Audit/update major passes that pattern-match `TInstr` (for example `optimize_casts`, `gufa`, `merge_blocks`, `local_cse`) to either preserve or reason about descriptor ops.
      - [x] Add scheduler-level regression coverage in `src/passes/optimize.mbt` for descriptor-mode pipelines.

- [ ] `Binaryen Pass: Heap2Local.cpp` parity hardening.
  - [ ] Descriptor-specific parity (`ref.cast_desc_eq`, `ref.get_desc`, descriptor-bearing `struct.new`) when descriptor ops are available.
  - [ ] Atomics-dependent parity (`struct/array rmw/cmpxchg`, synchronization-sensitive cases) now that threads atomics support has landed.

- [ ] `Binaryen Pass: SignatureRefining.cpp` parity hardening follow-up.
  - [ ] Add targeted coverage for uncovered paths and external-observability edge cases.

## 3) Scheduler / Feature Parity Gaps (`src/passes/optimize.mbt`)

- [ ] `ssa-nomerge`
- [ ] `flatten`
- [ ] `rereloop`
- [ ] `tuple-optimization`
- [ ] open-world `remove-unused-module-elements` mode exposure
- [ ] `cfp-reftest` mode
- [ ] `unsubtyping`
- [ ] `generate-global-effects`

## 4) Coverage + Quality Work

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

## 5) Refactorability / Maintainability

- [ ] Split very large files into focused units with colocated tests.
  - [ ] `src/validate/typecheck.mbt`
  - [ ] `src/validate/env.mbt`
  - [ ] `src/transformer/transformer.mbt`
  - [ ] `src/passes/optimize.mbt`
  - [ ] `src/passes/remove_unused.mbt`

- [ ] Standardize shared helpers for repeated unreachable-analysis patterns across passes.

## 6) Supporting Non-Pass Work

- [ ] Complete `src/wast/*.mbt` support.
  - [ ] Close remaining pretty-print parity gaps vs canonical wasm s-expression text output.

- [ ] Complete `src/wat/*.mbt` support (wasm 3.0 text format).
  - [ ] Lexer + tests
  - [ ] Parser + tests
  - [ ] Printer + tests
  - [ ] WAT -> WAST conversion helpers
  - [ ] WAT -> wasm types conversion helpers

## 7) Long-Tail Binaryen Backlog (Lower Priority)

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

Completed items were intentionally removed from this file to keep it actionable and current.
