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

- [ ] `Binaryen Pass: SignatureRefining.cpp` parity hardening
  - [x] Closed-world, no-table signature refinement over shared function signatures (direct `call` + `call_ref`)
  - [x] Signature-level result refinement across all functions sharing a type
  - [x] Conservative bailouts for imported/public/tag/subtyped/supertyped signatures
  - [x] Parameter-fixup local rewriting for refined params with incompatible `local.set`/`local.tee` writes
  - [x] Scheduler integration via `ModulePass::SignatureRefining` and default GC pre-pass inclusion
  - [x] Intrinsic parity for `call.without.effects` dual-signature handling
  - [x] JS-called/signature-called parity for params-only refinement blocking via unseen-call/public-reference gating
  - [x] Full `ModuleUtils::getPublicHeapTypes()`-equivalent external-observability gating for function signatures
  - [x] Type-rewrite/refinalize parity for typed-body exactness under this validator

## 3) Binaryen Passes Still To Implement

1) General optimization & canonical IR improvements (good “implement first” set)

- [x] ReorderLocals.cpp
- [x] ReorderTypes.cpp
- [x] SimplifyGlobals.cpp (general canonicalization / simplification)
- [x] SimplifyLocals.cpp (general canonicalization / simplification)
- [x] Untee.cpp (canonicalization: removes tee patterns / simplifies local.set+use forms)
- [x] Vacuum.cpp (general cleanup of unreachable/unused IR “dust”; canonical-ish)

### Low Priority

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
- [x] SignatureRefining.cpp (type/signature shaping; closer to type system)
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

- [x] Implemented `src/passes/signature_refining.mbt` and wired it via `ModulePass::SignatureRefining` in `src/passes/optimize.mbt`.
- [x] Added comprehensive pass-level tests for direct-call and `call_ref` param refinement, result refinement, table/import/tag/subtype bailouts, and param-fixup local rewriting.
- [x] Updated default closed-world GC pre-pass scheduling to include `SignatureRefining` and added scheduler-level dispatch/gating coverage in `src/passes/optimize.mbt`.
- [x] Implemented `src/passes/simplify_globals.mbt` and wired it via `ModulePass::SimplifyGlobals`, `ModulePass::SimplifyGlobalsOptimizing`, and `ModulePass::PropagateGlobalsGlobally` in `src/passes/optimize.mbt`.
- [x] Added pass-level tests for dead global-write removal, immutable-copy/constant propagation, linear trace global-set propagation, read-only-to-write detection, and global-init/data-offset propagation.
- [x] Added scheduler-level dispatch coverage in `src/passes/optimize.mbt` and documented simplify-globals variants in `README.mbt.md`.
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
- [x] Implemented `src/passes/reorder_locals.mbt` and wired it via `ModulePass::ReorderLocals` in `src/passes/optimize.mbt`.
- [x] Added pass-level and scheduler-level tests for local-use-count ordering, first-use tie-breaking, parameter-index preservation, and dropping/remapping unused locals.
- [x] Implemented `src/passes/reorder_types.mbt` and wired it via `ModulePass::ReorderTypes` in `src/passes/optimize.mbt`.
- [x] Added pass-level and scheduler-level tests for private-group type reordering, public-group preservation, and `TypeIdx` remapping under LEB-cost pressure.
- [x] Implemented `src/passes/signature_pruning.mbt` and wired it via `ModulePass::SignaturePruning` in `src/passes/optimize.mbt`.
- [x] Added pass-level tests for shared-signature pruning, `call_ref` signature/arg rewriting, table-section bailout, and scheduler-level dispatch coverage.
- [x] Implemented `src/passes/simplify_locals.mbt` and wired it via `ModulePass::SimplifyLocals`, `ModulePass::SimplifyLocalsNoTee`, `ModulePass::SimplifyLocalsNoStructure`, `ModulePass::SimplifyLocalsNoTeeNoStructure`, and `ModulePass::SimplifyLocalsNoNesting` in `src/passes/optimize.mbt`.
- [x] Expanded `simplify_locals` parity with structural `block`/`loop` return coalescing, conditional-break (`br_if`) value coalescing behavior, and late equivalent-local canonicalization.
- [x] Added/expanded pass-level tests for block/loop coalescing, direct structure rewrite invariants, late canonicalization behavior, and structure-gated equivalent-set removal behavior.
- [x] Added scheduler-level dispatch coverage in `src/passes/optimize.mbt` and documented simplify-locals variants in `README.md` and `README.mbt.md`.
- [x] Implemented `src/passes/untee.mbt` using the `ModuleTransformer[IRContext]` pass pattern and wired it via `ModulePass::Untee` in `src/passes/optimize.mbt`.
- [x] Added pass-level tests for `local.tee -> block(local.set, local.get)` rewriting, unreachable-tee dropping, and parameter-typed block-result behavior; plus scheduler-level dispatch coverage in `src/passes/optimize.mbt`.
- [x] Updated pass registry/docs for `Untee` in `README.mbt.md` and `AGENTS.md`.
- [x] Implemented `src/passes/vacuum.mbt` using the `ModuleTransformer[IRContext]` pass pattern and wired it via `ModulePass::Vacuum` in `src/passes/optimize.mbt`.
- [x] Added pass-level tests covering drop/if/loop/block/try_table/function cleanup behaviors plus scheduler-level dispatch coverage for `ModulePass::Vacuum`.
- [x] Updated pass registry/docs for `Vacuum` in `README.mbt.md` and `AGENTS.md`.
- [x] Fixed transformer bug where `ModuleTransformer::walk_module` ignored `on_module_evt`; added regression test in `src/transformer/tests.mbt`.
- [x] Audited `ModuleTransformer` hook dispatch coverage and added broad regression tests in `src/transformer/tests.mbt` to assert section/core walk functions invoke their corresponding `on_*` events.
