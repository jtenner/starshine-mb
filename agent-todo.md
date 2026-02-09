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

- [x] `Binaryen Pass: DeNaN.cpp` parity hardening
  - [x] Expand NaN-producing expression coverage beyond current scalar-op subset (loads/select/call results/local/global flows)
  - [x] Implement idempotency regression test (`running pass twice produces same result`) with helper/index stability assertions

- [x] `Binaryen Pass: GlobalRefining.cpp` parity hardening
  - [x] Broaden observed-type inference across additional expression forms and control-flow merges

- [ ] `Binaryen Pass: GlobalStructInference.cpp` parity hardening
  - [x] Implement closed-world `struct.get*` inference across singleton/two-value cases with constant grouping and non-constant global-field reads
  - [x] Expand parity tests for guard conditions (mutable globals/fields, in-function creators, non-eqref globals, >2 distinct values) and subtype propagation behavior
  - [x] Add descriptor-mode regression coverage documenting current no-op behavior in this IR
  - [ ] Implement descriptor-cast mode behavior once descriptor ops exist in IR (flag is wired but currently no-op)
  - [ ] Add descriptor-mode parity tests when IR support lands

- [x] `Binaryen Pass: GUFA.cpp` parity hardening
  - [x] Extend oracle domain/rewrites beyond current scalar+ref subset
  - [x] Add safe merge semantics across control-flow boundaries (less conservative than full state reset)

- [ ] `Binaryen Pass: GlobalTypeOptimization.cpp` parity hardening
  - [ ] Add additional parity tests around tricky type-hierarchy removal/reordering edge cases and public-type constraints

- [ ] `Binaryen Pass: Heap2Local.cpp` parity hardening
  - [ ] Descriptor-specific parity (`ref.cast_desc_eq`, `ref.get_desc`, descriptor-bearing `struct.new`) when/if descriptor ops are added to IR
  - [ ] Atomics-dependent parity (`struct/array rmw/cmpxchg`, synchronization-sensitive cases) after atomics support lands
  - [ ] Add more branch/CFG stress tests to validate escape/exclusivity precision on complex control flow

- [x] `Binaryen Pass: HeapStoreOptimization.cpp` parity hardening
  - [x] Replace conservative “branchy value + later local.get” guard with LocalGraph/`canMoveSet`-equivalent `canSkipLocalSet` logic
  - [x] Add CFG/basic-block-scoped action traversal parity (not only linear list scanning)
  - [x] Add explicit `struct.new` invalidation checks equivalent to Binaryen `ShallowEffectAnalyzer(new_).invalidates(setValueEffects)`
  - [x] Expand parity tests for:
    - [x] legal branch-skip cases currently rejected
    - [x] required rejection cases
    - [x] reordering across mixed locals/globals/memory/call/trap effects

- [x] `Binaryen Pass: DeadCodeElimination.cpp` parity hardening
  - [x] Add parity-focused tests for EH/branch interaction and block/loop/try_table corner cases

- [x] `Binaryen Pass: DuplicateFunctionElimination.cpp` parity hardening
  - [x] Add parity tests for advanced signature/feature interactions and index remapping edge cases

- [x] `Binaryen Pass: DuplicateImportElimination.cpp` parity hardening
  - [x] Add parity tests for mixed extern kinds and import/export remapping edge cases

- [x] `Binaryen Pass: I64ToI32Lowering.cpp` parity hardening
  - [x] Expand comprehensive feature coverage tests across call/call_indirect/call_ref + return_call* + control-flow/result typing + global/error guard paths
  - [x] Add wasm2js-style parity for conversion/reinterpret/trunc i64 ops (`f*.convert_i64*`, `i64.trunc_*`, `reinterpret`) using scratch-memory lowering
  - [x] Add support for i64-block-result control-flow lowering (`block`/`loop`/`if`/`try_table` typed to i64)
  - [x] Add parity support for unsupported-at-source i64 binary ops when not removed earlier (`mul/div/rem/rot`, `ctz/popcnt`)

## 3) Binaryen Passes Still To Implement

### A) Primary Optimization / Analysis Passes
- [ ] Binaryen Pass: Asyncify.cpp
- [x] Binaryen Pass: I64ToI32Lowering.cpp
- [ ] Binaryen Pass: Inlining.cpp
- [ ] Binaryen Pass: LocalCSE.cpp
- [ ] Binaryen Pass: LocalSubtyping.cpp
- [ ] Binaryen Pass: LoopInvariantCodeMotion.cpp
- [ ] Binaryen Pass: MemoryPacking.cpp
- [ ] Binaryen Pass: MergeBlocks.cpp
- [ ] Binaryen Pass: MergeLocals.cpp
- [ ] Binaryen Pass: MergeSimilarFunctions.cpp
- [ ] Binaryen Pass: OnceReduction.cpp
- [ ] Binaryen Pass: OptimizeAddedConstants.cpp
- [ ] Binaryen Pass: OptimizeCasts.cpp
- [ ] Binaryen Pass: OptimizeInstructions.cpp
- [ ] Binaryen Pass: PickLoadSigns.cpp
- [ ] Binaryen Pass: Precompute.cpp
- [ ] Binaryen Pass: RedundantSetElimination.cpp
- [ ] Binaryen Pass: RemoveUnusedBrs.cpp
- [ ] Binaryen Pass: RemoveUnusedModuleElements.cpp
- [ ] Binaryen Pass: RemoveUnusedNames.cpp
- [ ] Binaryen Pass: RemoveUnusedTypes.cpp
- [ ] Binaryen Pass: ReorderFunctions.cpp
- [ ] Binaryen Pass: ReorderGlobals.cpp
- [ ] Binaryen Pass: ReorderLocals.cpp
- [ ] Binaryen Pass: ReorderTypes.cpp
- [ ] Binaryen Pass: SSAify.cpp
- [ ] Binaryen Pass: SignaturePruning.cpp
- [ ] Binaryen Pass: SimplifyGlobals.cpp
- [ ] Binaryen Pass: SimplifyLocals.cpp
- [ ] Binaryen Pass: TypeFinalizing.cpp
- [ ] Binaryen Pass: TypeGeneralizing.cpp
- [ ] Binaryen Pass: TypeMerging.cpp
- [ ] Binaryen Pass: TypeRefining.cpp
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
- [ ] Binaryen Pass: MinimizeRecGroups.cpp
- [ ] Binaryen Pass: Monomorphize.cpp
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
