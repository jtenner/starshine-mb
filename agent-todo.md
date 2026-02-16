# Agent Tasks

## 1) Core Project Prerequisites

- [ ] Stabilize IRContext + dataflow foundations
  - [ ] Migrate remaining passes to IRContext usage:
    - [ ] `src/passes/de_nan.mbt`
    - [ ] `src/passes/remove_unused.mbt`
  - [ ] Resolve underlying data-structure issues behind `src/passes/dataflow_opt.mbt` test instability

- [ ] Add wasm atomics/threading support (prerequisite for atomics-dependent parity)
  - [ ] Extend IR `TInstr` + validator surface for required atomic GC/memory operations
  - [ ] Add EH/control-flow-safe LocalGraph helpers needed by movement/synchronization checks
  - [ ] Re-enable atomics-dependent parity work in Heap2Local / HeapStoreOptimization when atomics are available

## 2) Parity Backlog For Implemented Binaryen Passes

- [ ] `Binaryen Pass: GlobalStructInference.cpp` parity hardening
  - [ ] Implement descriptor-cast mode behavior once descriptor ops exist in IR (flag is wired but currently no-op)
  - [ ] Add descriptor-mode parity tests when IR support lands

- [ ] `Binaryen Pass: GlobalTypeOptimization.cpp` parity hardening
  - [ ] Add additional parity tests around tricky type-hierarchy removal/reordering edge cases and public-type constraints

- [ ] `Binaryen Pass: Heap2Local.cpp` parity hardening
  - [ ] Descriptor-specific parity (`ref.cast_desc_eq`, `ref.get_desc`, descriptor-bearing `struct.new`) when/if descriptor ops are added to IR
  - [ ] Atomics-dependent parity (`struct/array rmw/cmpxchg`, synchronization-sensitive cases) after atomics support lands
  - [ ] Add more branch/CFG stress tests to validate escape/exclusivity precision on complex control flow

- [ ] `Binaryen Pass: Asyncify.cpp` parity follow-up
  - [ ] Catch-block unwind assertion parity (`AsyncifyAssertUnwindCorrectness` in explicit catch-body form) is limited by current IR `try_table` catch representation

## 3) Binaryen Passes Still To Implement

### A) Primary Optimization / Analysis Passes
- [x] Binaryen Pass: RemoveUnusedNames.cpp
- [x] Binaryen Pass: RemoveUnusedTypes.cpp
- [x] Binaryen Pass: ReorderFunctions.cpp
- [x] Binaryen Pass: ReorderGlobals.cpp
- [ ] Binaryen Pass: ReorderLocals.cpp
- [ ] Binaryen Pass: ReorderTypes.cpp
- [ ] Binaryen Pass: SSAify.cpp
- [ ] Binaryen Pass: SignaturePruning.cpp
- [ ] Binaryen Pass: SimplifyGlobals.cpp
- [ ] Binaryen Pass: SimplifyLocals.cpp
- [ ] Binaryen Pass: TypeFinalizing.cpp
- [ ] Binaryen Pass: TypeGeneralizing.cpp
- [ ] Binaryen Pass: TypeMerging.cpp
- [x] Binaryen Pass: TypeRefining.cpp
- [ ] Binaryen Pass: TypeSSA.cpp
- [ ] Binaryen Pass: Unsubtyping.cpp
- [ ] Binaryen Pass: Untee.cpp
- [ ] Binaryen Pass: Vacuum.cpp

### B) Lowering / Legalization / Platform Passes
- [ ] Binaryen Pass: LLVMMemoryCopyFillLowering.cpp
- [ ] Binaryen Pass: LLVMNontrappingFPToIntLowering.cpp
- [ ] Binaryen Pass: LegalizeJSInterface.cpp
- [ ] Binaryen Pass: Memory64Lowering.cpp
- [ ] Binaryen Pass: MultiMemoryLowering.cpp
- [ ] Binaryen Pass: RemoveMemoryInit.cpp
- [ ] Binaryen Pass: RemoveNonJSOps.cpp
- [ ] Binaryen Pass: SignExtLowering.cpp
- [ ] Binaryen Pass: StripEH.cpp
- [ ] Binaryen Pass: StripTargetFeatures.cpp
- [ ] Binaryen Pass: TranslateEH.cpp

### C) Instrumentation / Metrics / Diagnostics
- [ ] Binaryen Pass: InstrumentBranchHints.cpp
- [ ] Binaryen Pass: InstrumentLocals.cpp
- [ ] Binaryen Pass: InstrumentMemory.cpp
- [ ] Binaryen Pass: Metrics.cpp
- [ ] Binaryen Pass: RandomizeBranchHints.cpp
- [ ] Binaryen Pass: TraceCalls.cpp

### D) JS / Tooling / Specialty Passes
- [ ] Binaryen Pass: Intrinsics.cpp
- [ ] Binaryen Pass: J2CLItableMerging.cpp
- [ ] Binaryen Pass: J2CLOpts.cpp
- [ ] Binaryen Pass: LimitSegments.cpp
- [ ] Binaryen Pass: MinifyImportsAndExports.cpp
- [ ] Binaryen Pass: NoInline.cpp
- [ ] Binaryen Pass: OptimizeForJS.cpp
- [ ] Binaryen Pass: Outlining.cpp
- [ ] Binaryen Pass: Poppify.cpp
- [ ] Binaryen Pass: ReReloop.cpp
- [ ] Binaryen Pass: RemoveImports.cpp
- [ ] Binaryen Pass: RoundTrip.cpp
- [ ] Binaryen Pass: SafeHeap.cpp
- [ ] Binaryen Pass: SeparateDataSegments.cpp
- [ ] Binaryen Pass: SetGlobals.cpp
- [ ] Binaryen Pass: SignatureRefining.cpp
- [ ] Binaryen Pass: Souperify.cpp
- [ ] Binaryen Pass: SpillPointers.cpp
- [ ] Binaryen Pass: StackCheck.cpp
- [ ] Binaryen Pass: StringLifting.cpp
- [ ] Binaryen Pass: StringLowering.cpp
- [ ] Binaryen Pass: Strip.cpp
- [ ] Binaryen Pass: TrapMode.cpp
- [ ] Binaryen Pass: TupleOptimization.cpp

## 4) Supporting Non-Pass Work

- [ ] Improve `src/lib/show.mbt` trait definitions for pretty-printing module outputs

- [ ] Complete `src/wast/*.mbt` support
  - [ ] Add complete tests
  - [ ] Fix module pretty-printing to match wasm s-expression text format
  - [ ] Implement WAST -> WAT conversion helpers
  - [ ] Implement WAST -> wasm types conversion helpers (via `TExpr` where appropriate)

- [ ] Complete `src/wat/*.mbt` support (wasm 3.0 text format)
  - [ ] Lexer + tests
  - [ ] Parser + tests
  - [ ] Printer + tests
  - [ ] WAT -> WAST conversion helpers
  - [ ] WAT -> wasm types conversion helpers

- [ ] Add CI gate for `moon check` warning regression

## 5) Recently Completed

- [x] Implemented `src/passes/remove_unused_names.mbt` using `ModuleTransformer[IRContext]` and wired it via `ModulePass::RemoveUnusedNames` in `src/passes/optimize.mbt`.
- [x] Added pass-level tests covering nested-block merging, label-depth retargeting, and loop-to-block rewrite behavior.
- [x] Added scheduler-level dispatch test in `src/passes/optimize.mbt` and documented the pass in `README.md`.
- [x] Implemented `src/passes/type_refining.mbt` and wired it via `ModulePass::TypeRefining` in `src/passes/optimize.mbt`.
- [x] Added pass-level tests for direct-callsite parameter refinement and param-fixup local rewriting when refined params are assigned less-specific values.
- [x] Implemented `src/passes/remove_unused_types.mbt` and wired it via `ModulePass::RemoveUnusedTypes` in `src/passes/optimize.mbt`.
- [x] Added tests for dropping unreachable GC types, keeping transitive type dependencies, and remapping `TypeIdx` uses after deletions.
- [x] Implemented `src/passes/reorder_functions.mbt` and wired it via `ModulePass::ReorderFunctions` and `ModulePass::ReorderFunctionsByName` in `src/passes/optimize.mbt`.
- [x] Added pass-level and scheduler-level tests for static-use-count ordering and `FuncIdx` remapping across calls/start/exports/elements.
- [x] Implemented `src/passes/reorder_globals.mbt` and wired it via `ModulePass::ReorderGlobals` and `ModulePass::ReorderGlobalsAlways` in `src/passes/optimize.mbt`.
- [x] Added pass-level and scheduler-level tests for dependency-constrained global ordering and `GlobalIdx` remapping.
