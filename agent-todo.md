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

- [x] `Binaryen Pass: Inlining.cpp` implementation + parity coverage
  - [x] Add `InliningOptions` defaults matching Binaryen (`alwaysInlineMaxSize`, `oneCallerInlineMaxSize`, `flexibleInlineMaxSize`, `maxCombinedBinarySize`, `allowFunctionsWithLoops`, `partialInliningIfs`)
  - [x] Wire options through `OptimizeOptions` and pass scheduling
  - [x] Add `ModulePass::Inlining` and `ModulePass::InliningOptimizing`
  - [x] Add `ModulePass::InlineMain` (`main`/`__original_main` single-call inlining)
  - [x] Implement iterative full inlining with size/call/loop guards, reachability-safe callsite planning, and growth cap
  - [x] Implement callsite inlining transform with local remap, default-only local init, return/return_call rewriting (including hoist path for `return_call*` under `try_table`), and label-depth fixups
  - [x] Add split inlining support for Pattern A and Pattern B (with dependency-based rejection guard)
  - [x] Add focused tests covering always-inline, one-caller thresholding, multi-use behavior, growth cap, return/return_call handling, split behavior, and inline-main cases

- [x] `Binaryen Pass: LocalCSE.cpp` implementation + parity coverage
  - [x] Implement 3-phase local CSE pipeline (`Scanner` / `Checker` / `Applier`) over tree IR
  - [x] Restrict CSE connectivity to basic-block-like linear regions (clear active state on non-linear boundaries)
  - [x] Add effect-based request invalidation between original/repeat pairs
  - [x] Add full pass tests for repeated whole-trees, boundary isolation, child-request suppression, memory interference invalidation, trap-only candidate handling, shrink-level gating, and idempotency
  - [x] Wire `ModulePass::LocalCSE` into `src/passes/optimize.mbt` dispatch and integration tests

- [x] `Binaryen Pass: LocalSubtyping.cpp` implementation + parity coverage
  - [x] Restrict analysis/refinement to reference-typed var locals (ignore non-ref locals and params)
  - [x] Scan function bodies for `local.get` / `local.set` / `local.tee` and build per-local set/get buckets
  - [x] Compute "cannot become non-nullable" locals using local-flow reachability (`LocalGraph` init-value visibility) plus structural dominance fallback checks
  - [x] Implement iterative local-type refinement to LUB of assigned value types until convergence
  - [x] Enforce refinement safety constraints (`new <: old`, non-`none`, defaultability, non-nullability relaxation to nullable when unsafe)
  - [x] Include tee assignments in refinement and keep tree IR node typing coherent (implicit in `TInstr` + local signature updates)
  - [x] Add full inline pass tests (LUB refinement, safe/unsafe non-nullability, defaultability guard, tee handling, iterative convergence, no-op cases, validation check)
  - [x] Wire `ModulePass::LocalSubtyping` into `src/passes/optimize.mbt` dispatch and add optimize integration test
  - [x] Update docs/bookkeeping (`README.mbt.md`, `AGENTS.md`, `agent-todo.md`)

- [x] `Binaryen Pass: OptimizeCasts.cpp` implementation + parity coverage
  - [x] Implement Binaryen-shaped two-stage flow: early cast movement + best-cast reuse
  - [x] Add effect/barrier-based movement invalidation for cast hoisting safety
  - [x] Add temp-local tee rewriting for refined-cast reuse
  - [x] Add focused pass tests for early movement, refinement preference, non-null handling, and boundary conservatism
  - [x] Update docs/bookkeeping (`AGENTS.md`, `agent-todo.md`)

- [x] `Binaryen Pass: RemoveUnusedModuleElements.cpp` implementation + parity coverage
  - [x] Add closed-world reference-vs-use modeling for functions (`ref.func` can keep function without marking body reachable)
  - [x] Add open-world mode toggle so `ref.func` conservatively marks function targets as used
  - [x] Track callable signatures from `call_ref` and `call_indirect` and promote matching referenced function targets to used
  - [x] Keep referenced-only functions in output while rewriting their bodies to `unreachable`
  - [x] Add root-all-functions mode (`remove_unused_non_function_elements`) to preserve all functions while trimming other module elements
  - [x] Expand test suite with parity-focused scenarios: closed/open world behavior, call_ref promotion, call_indirect promotion, referenced-only body rewriting, and root-all mode
  - [x] Verify via `/home/jtenner/.moon/bin/moon test src/passes`

- [x] `Binaryen Pass: RemoveUnusedBrs.cpp` implementation + parity coverage
  - [x] Add `src/passes/remove_unused_brs.mbt` with fixed-point function-level branch simplification pass
  - [x] Wire `ModulePass::RemoveUnusedBrs` in `src/passes/optimize.mbt` dispatch and add optimize integration test
  - [x] Remove trailing redundant control flow at scope exits (`br 0`, `return`) and trailing `nop`s where safe
  - [x] Convert one-armed `if` branch patterns to `br_if` and fold nested one-armed `if` conditions through `select`
  - [x] Simplify `br_table`/switch patterns: trim trailing/leading defaults and lower default-only or singleton tables
  - [x] Combine adjacent branch patterns (`br_if + br`, adjacent shrink-mode `br_if`s) when effect-safe
  - [x] Fold constant `br_if` conditions to unconditional branches or fallthrough with side-effect preservation
  - [x] Optimize block tails where dropped `br_if` value duplicates final fallthrough value
  - [x] Add comprehensive inline pass tests (behavioral cases + idempotency)
  - [x] Verify via `/home/jtenner/.moon/bin/moon test src/passes`

## MemoryPacking pass

- [x] Preconditions: skip when module has 0 memories or more than 1 memory
- [x] Preconditions: imported sole memory requires `zeroFilledMemory=true`
- [x] Preconditions: skip when multiple segments and any active segment has non-constant offset
- [x] Preconditions: skip when active constant-offset segments overlap
- [x] Segment splitting: skip empty segments
- [x] Segment splitting: skip `__llvm*` named segments
- [x] Segment splitting: skip segments referenced by GC data ops (`array.new_data` / `array.init_data`)
- [x] Segment splitting: skip passive segment splitting when any `memory.init` ref has non-constant offset/size
- [x] Segment splitting: compute full alternating zero/non-zero ranges
- [x] Active trap parity: preserve startup OOB trap byte when `trapsNeverHappen=false`
- [x] Passive thresholds: apply metadata/referrer-based threshold and edge-threshold merging
- [x] Active thresholds: apply fixed zero-span threshold heuristic
- [x] Segment limit handling: cap splits at max data segment count by merging remaining ranges
- [x] Segment creation: emit non-zero ranges only and compute active offsets with saturating addition
- [x] Segment rewrite: replace module data segment list and keep data-count section in sync
- [x] Segment-op optimization: rewrite `data.drop` on active segments to `nop`
- [x] Segment-op optimization: simplify `memory.init` must-trap/must-nop cases (bulk-memory semantics)
- [x] Referrer collection: gather `memory.init`, `data.drop`, and GC data-op referrers
- [x] Unused segment dropping: remove passive segments only referenced by `data.drop` and nop those drops
- [x] Replacements: rewrite transformed passive `memory.init` into `memory.init` + `memory.fill` sequences
- [x] Replacements: rewrite transformed `data.drop` into per-split drops
- [x] Replacements: preserve zero-length `memory.init` trap semantics
- [x] Drop-state global: lazily create and use `__mem_segment_drop_state` only when needed
- [x] Rewriter implementation: use lazy/function-local replacement with temp-local stashing for non-const dest
- [x] Rewriter implementation: rewrite `array.new_data` / `array.init_data` data indices after segment remap
- [x] File created: `src/passes/memory_packing.mbt`
- [x] Pass wired into scheduler/registry (`ModulePass` + `optimize_module` dispatch)
- [x] Full MemoryPacking test suite added
- [x] Documentation updated (`README.mbt.md` + `AGENTS.md` + `agent-todo.md`)

## MergeBlocks pass

- [x] Merge nested blocks into parent block lists (head/tail safe merging with convergence loop)
- [x] Skip merging child blocks that contain dead code after unreachable (`hasDeadCode`)
- [x] Respect branch targets when merging named-equivalent blocks (merge only prefix before first branch to self)
- [x] Skip named-equivalent concrete-typed block merging (value-carrying breaks not handled)
- [x] Wrap concrete values moved into non-final parent positions with `drop`
- [x] Finalize block types after block-list modifications
- [x] Run function-level ReFinalize when transformations require global re-typing
- [x] Merge loop-body block tails into parent blocks when safe
- [x] Do not move loop-tail items containing branches to loop label
- [x] Skip partial loop-tail merges when loop has flowing concrete value
- [x] Optimize `(drop (block ...))` by pushing `drop` inward and removing outer `drop`
- [x] Handle dropped named-equivalent blocks by safely removing break values when allowed
- [x] Implement `ProblemFinder` safety checks for break-value removal
- [x] Block break-value removal when `br`/`br_if` sent values have side effects
- [x] Block break-value removal on `br_if` value-use count mismatch (all origin-targeting `br_if` values must be dropped)
- [x] Handle `try_table` origin-target catches: allow only `catch_all_ref` or `catch_ref` of zero-param tags
- [x] Block break-value removal for unsupported origin-targeting branch-like ops (`br_table` / `br_on*` / etc.)
- [x] Implement `BreakValueDropper` rewrite for `br`/`br_if` origin-target values
- [x] Rewrite drops of non-concrete values to the value itself during break-value dropping
- [x] Rewrite `try_table` catches targeting origin to stop sending refs
- [x] Re-run block merge optimization on blocks touched by break-value dropping
- [x] Implement expression restructuring to pull block prefixes outward from child operands
- [x] Restrict restructuring to unnamed blocks with >=2 items, matching block/back type, and non-unreachable back
- [x] Preserve operation ordering with effect analysis (`compute_effects`/`invalidates`) while restructuring
- [x] Apply `if` restructuring only to condition child
- [x] Apply conservative `throw` restructuring (skip when any throw operand has side effects)
- [x] Implement reusable branch-target cache helper (`has_branch` caching)
- [x] New file created: `src/passes/merge_blocks.mbt`
- [x] Pass registered in pipeline (`ModulePass` + `optimize_module` dispatch)
- [x] Full MergeBlocks test suite added
- [x] README updated for MergeBlocks
- [x] AGENTS.md updated with MergeBlocks context

## MergeLocals pass

- [x] Detect local-to-local copies (`local.set x (local.get y)` with `x != y`) and instrument with trivial `local.tee`
- [x] Preserve types during instrumentation and keep IR valid
- [x] Build eager pre-state local-flow snapshot and compute set influences
- [x] Implement optimize-to-copy (`y -> x`) with all-or-nothing rewrite per copy
- [x] Implement optimize-to-trivial (`x -> y`) with all-or-nothing rewrite per copy
- [x] Enforce no-phi/merge guard via reaching-set size (`== 1`) on rewritten gets
- [x] Enforce exact local type equality checks before rewrites
- [x] Build post-state snapshot and verify each rewrite direction
- [x] Undo rewrite direction per-copy when post verification fails
- [x] Remove temporary trivial instrumentation tees at pass end
- [x] Ensure idempotent behavior across repeated runs
- [x] New file created: `src/passes/merge_locals.mbt`
- [x] Pass registered in pipeline (`ModulePass::MergeLocals` + `optimize_module` dispatch)
- [x] Dedicated test suite added: `src/passes/merge_locals_tests.mbt`
- [x] README updated
- [x] AGENTS.md updated

## MergeSimilarFunctions pass

- [x] A) Identify candidate functions and group (defined-only, same signature/locals, hash buckets + equivalence refine)
- [x] B) Derive parameterization plan (const/call-target sites, diff vectors, parameter reuse, param limit guard)
- [x] C) Profitability heuristic (merge only when estimated removal beats thunk/shared overhead)
- [x] D) Create shared implementation (extra params, site replacement, call->call_ref rewrite, var-local reindexing)
- [x] E) Replace originals with thunks (forward original params + per-function constants/ref.func values; signatures preserved)
- [x] F) Safety + determinism invariants (imports untouched, call target type checks, reject non-const/non-call diffs, stable class ordering)
- [x] New file created and pass registered (`src/passes/merge_similar_functions.mbt`, `ModulePass::MergeSimilarFunctions` dispatch)
- [x] Full test suite added (positive + negative + determinism + local-shift + validation checks)
- [x] README updated
- [x] AGENTS.md updated
- [x] `moon check`, `moon test`, `moon info && moon fmt` all green

## MinimizeRecGroups pass

- [x] A) Collect and classify heap types (private/public) and reserve public rec-group shapes
- [x] B) Build private type graph, compute SCCs, and establish initial in-group topo ordering constraints
- [x] C) Implement rec-group shape and comparable-shape construction for deterministic collision checks
- [x] D) Maintain incremental shape collision handling with shape map + DSU classes + work stack
- [x] E) Implement permutation-first disambiguation with constrained topological-order enumeration
- [x] F) Implement canonical permutation derivation for nontrivial collision classes
- [x] G) Implement brand-type fallback (including singleton non-equality guard and permutation reset)
- [x] H) Implement collision category handling logic (public conflicts, same/different class conflicts, union cases)
- [x] I) Rewrite module heap types into rebuilt rec groups and remap all module type uses deterministically
- [x] New file created + pass registered (`src/passes/minimize_rec_groups.mbt`, `ModulePass::MinimizeRecGroups`)
- [x] Full MinimizeRecGroups test suite implemented
- [x] README updated
- [x] AGENTS.md updated
- [x] `moon check`, `moon test`, `moon info && moon fmt` all green

## Monomorphize pass

- [x] New file + pass registration (`src/passes/monomorphize.mbt`, `ModulePass::Monomorphize`, `ModulePass::MonomorphizeAlways`)
- [x] Pass argument support for `--pass-arg=monomorphize-min-benefit@N` via `monomorphize_apply_arguments`
- [x] Max parameter cap enforced for specializations (`MONO_MAX_PARAMS = 20`)
- [x] Direct-call discovery + dropped-call detection (`drop(call ...)`) with unreachable-site filtering
- [x] CallContext build implemented (reverse-inlined operands + dropped flag)
- [x] Movability and ordering checks implemented (effects/control-flow/locals/calls/tuple-child and reverse invalidation walk)
- [x] Trivial-context suppression implemented and memoized to no-op
- [x] Structural context hashing/equality for memoization and specialization reuse
- [x] Specialized clone builder implemented (new signature, param->var rewrite, local index remap, prelude insertion)
- [x] Dropped-result specialization support (`none` result + return-value removal rewrite)
- [x] Callsite updater implemented (retarget call, new operand list, dropped-drop elimination)
- [x] Skip guards implemented (imports, direct recursion, unreachable operands/targets)
- [x] Empirical mode cost gate implemented (`benefit > monomorphize_min_benefit`)
- [x] `MonomorphizeAlways` mode implemented (accept all non-trivial legal contexts)
- [x] Optimizer hook implemented (`do_opts`) with nested-safe function-level cleanup
- [x] Deterministic behavior enforced (snapshot function iteration, stable append order, deterministic context keying)
- [x] Full test suite added (always + empirical + drops + memoization + thresholds + determinism + parser + skips + bounds)
- [x] README updated
- [x] AGENTS.md updated
- [x] `moon check`, `moon test`, `moon info && moon fmt` all green

## OnceReduction pass

- [x] New file + pass registration (`src/passes/once_reduction.mbt`, `ModulePass::OnceReduction`)
- [x] Scanner implemented (global read/write rules, canonical once-function pattern detection, read-guard exemption)
- [x] Once global eligibility initialization implemented (integer mutable globals, imported/exported filtering)
- [x] CFG + dominator-based optimizer implemented (redundant once call and redundant set nopping)
- [x] Fixed-point propagation implemented (`once_globals_set_in_funcs` summaries across call graph)
- [x] Deterministic module-order once-body cleanup implemented (no-payload and call-only cleanup with cycle guard)
- [x] Full OnceReduction tests added (A-M coverage: removals, disqualifiers, propagation, dominance, cleanup, cycle safety, determinism)
- [x] README updated
- [x] AGENTS.md updated
- [x] `moon check`, `moon test`, `moon info && moon fmt` all green

## LoopInvariantCodeMotion pass

- [x] pass skeleton + registration (`src/passes/loop_invariant_code_motion.mbt`, `ModulePass::LoopInvariantCodeMotion`)
- [x] loop entrance traversal + stop on transfer-control effects
- [x] effect safety checks (global-state writes, invalidation against `effectsSoFar`, loop read/write interaction, throws conservatism)
- [x] `LocalGraph` integration + local.get dependency checks via `get_sets(get_id)`
- [x] local-set interference accounting (`numSetsForIndex` decrement/check/restore flow)
- [x] rewriting to preheader block shape (`block(moved..., loop)` preserving loop block type)
- [x] comprehensive tests covering LICM A-J scenarios + crash-safety + idempotency
- [x] docs updates (`AGENTS.md`, `README.mbt.md`, `agent-todo.md`)
- [x] `moon check`, `moon test`, `moon info && moon fmt` all green

## OptimizeAddedConstants pass

- [x] pass implementation + registration (`src/passes/optimize_added_constants.mbt`, `ModulePass::OptimizeAddedConstants`, `ModulePass::OptimizeAddedConstantsPropagate`)
- [x] low-memory gate and bound semantics wired via `OptimizeOptions.low_memory_unused` / `OptimizeOptions.low_memory_bound`
- [x] add-const fold for both `load` and `store` pointers with `low_memory_bound` safety checks
- [x] const-pointer + offset normalization with memory32/memory64 overflow guards
- [x] conservative propagate mode with:
  - [x] `GetParents` helper for `local.get` immediate parent checks
  - [x] propagatable-set filtering (all influenced gets must be under load/store parents)
  - [x] single-reaching-set use-site gating
  - [x] helper-local insertion for non-SSA/non-stable bases
- [x] iterative rerun to fixpoint when propagation succeeds + cleanup of unneeded sets between rounds
- [x] tests added for fold basics, safety bounds, const-pointer normalization, propagate success/rejection/helper behavior, multi-iteration behavior, and low-memory gating failure

## OptimizeInstructions pass

- [x] new file + pass registration (`src/passes/optimize_instructions.mbt`, `ModulePass::OptimizeInstructions`)
- [x] IRContext transformer integration via `optimize_instructions_ir_pass` and function-level fixpoint rewrite loop
- [x] local metadata scan for max-bits / sign-extension-informed simplifications
- [x] canonicalization and effect-safe child reordering for symmetric/relational binaries
- [x] binary peephole parity coverage for arithmetic/bitwise/shift/relational patterns (including power-of-two division/multiply lowering)
- [x] unary peephole parity coverage for `eqz` patterns, wrap/extend reductions, reinterpret pair elimination, rounding/conversion and unary dedup rules
- [x] select/if/boolean-context simplifications and equal-arm folding
- [x] memory access/store rewrites: ptr+offset folding, truncation masks, wrap/reinterpret store canonicalization
- [x] bulk memory instruction rewrites for const-size `memory.copy` and `memory.fill`
- [x] `call_ref` directization rewrites for `ref.func` and `table.get` call targets
- [x] comprehensive inline test suite added for binary, unary, control-flow, memory, call, and idempotency behavior
- [x] docs/bookkeeping updated (`AGENTS.md`, `agent-todo.md`)
- [x] `moon test` green after integration

## PickLoadSigns pass

- [x] New file + pass registration (`src/passes/pick_load_signs.mbt`, `ModulePass::PickLoadSigns`)
- [x] Candidate discovery implemented for `local.set` of sign-relevant integer loads (non-tee only)
- [x] Usage accounting implemented per local (`total`, `signed`, `unsigned`, and consistent extension-bit tracking)
- [x] Sign-usage detection implemented for unary sign-extends and two-level shift sign-extension forms (`x << k >>_s k`)
- [x] Zero-usage detection implemented for low-mask forms (`x & mask` / `mask & x`) and two-level shift zero-extension forms (`x << k >>_u k`)
- [x] Optimization gating implemented with Binaryen parity conditions:
  - [x] skip when there are zero uses
  - [x] skip when any use is not classified as sign/zero extension
  - [x] skip when observed extension bits do not match load width
  - [x] skip when mixed extension widths are inconsistent
- [x] Signedness choice heuristic implemented with Binaryen weighting (`signed_uses * 2 >= unsigned_uses`)
- [x] Load-op rewrite parity implemented for all sign-relevant load pairs:
  - [x] `i32.load8_{s,u}`
  - [x] `i32.load16_{s,u}`
  - [x] `i64.load8_{s,u}`
  - [x] `i64.load16_{s,u}`
  - [x] `i64.load32_{s,u}`
- [x] Multi-candidate/local parity: all eligible `local.set(load)` candidates in a function are rewritten consistently using deterministic candidate encounter order
- [x] Atomic-load guard parity accounted for current IR surface (no atomic `LoadOp` variants present yet, so pass naturally only sees non-atomic loads)
- [x] Comprehensive inline test suite added (positive, negative, nested-parent, width-mismatch, tee-ignore, multi-candidate, i64 coverage, idempotency)
- [x] Optimize pipeline integration test added in `src/passes/optimize.mbt`
- [x] Bookkeeping updated (`AGENTS.md`, `agent-todo.md`)

## Asyncify pass

- [x] pass skeleton + registration (`src/passes/asyncify.mbt`, `ModulePass::Asyncify(AsyncifyPassProps)`)
- [x] asyncify pass-arg parsing scaffold (`asyncify_apply_arguments`) including import/ignore/indirect/assert/list/memory/global flags and aliases
- [x] memory selection implemented (single-memory default, multi-memory export selection, optional secondary memory) with wasm32/wasm64 pointer type handling
- [x] `PatternMatcher` wildcard matching and deterministic matcher usage in add/remove/only/import lists
- [x] `ModuleAnalyzer` implemented for callgraph propagation, top-most/bottom-most runtime classification, and instrumentation eligibility
- [x] `AsyncifyBuilder` implemented (`make_get_stack_pos`, `make_inc_stack_pos`, `make_state_check`) with pointer-size-aware loads/stores
- [x] flow instrumentation implemented (`AsyncifyFlow`-style rewrite) for calls/if/block/loop/try plus per-function call-index assignment
- [x] fake-global path implemented (`FakeGlobalHelper`) and lowered back to locals in locals stage
- [x] locals stage implemented (`AsyncifyLocals`-style lowering) for intrinsic lowering, save/restore of relevant locals, unwind block form, and stack pos updates
- [x] runtime API emitted (`__asyncify_state`, `__asyncify_data`, `asyncify_start_unwind`, `asyncify_stop_unwind`, `asyncify_start_rewind`, `asyncify_stop_rewind`, `asyncify_get_state`)
- [x] assert-mode instrumentation implemented for non-instrumented functions (`AsyncifyAssertInNonInstrumented`)
- [x] tests added for direct/indirect instrumentation, fake-global lowering, selective import behavior, list controls, runtime API/global creation, local save/restore relevance, and assert guards
- [ ] catch-block unwind assertion parity (`AsyncifyAssertUnwindCorrectness` in explicit catch-body form) is limited by current IR’s `try_table` catch representation
- [x] docs updated (`AGENTS.md`, `README.mbt.md`, `agent-todo.md`)
- [x] `moon check`, `moon test` green (follow-up `moon info && moon fmt` pending final step)

## Precompute pass

- [x] pass skeleton + registration (`src/passes/precompute.mbt`, `ModulePass::Precompute`, `ModulePass::PrecomputePropagate`)
- [x] Constant-expression evaluator implemented for scalar ops (`unary`/`binary`) and basic ref constants (`ref.null`, `ref.func`, `ref.eq`, `ref.is_null`)
- [x] Immutable global constant folding implemented (`global.get` of immutable literal initializers)
- [x] Propagation mode implemented with LocalGraph-backed fixed-point analysis (`local.set` constants -> `local.get` replacement)
- [x] Propagation safety guards implemented:
  - [x] trap-aware constant evaluation (e.g. divide-by-zero and signed-overflow div not folded)
  - [x] branchy-local conservatism (locals written in `if` arms are not propagated)
- [x] Partial precompute implemented for select lifting through parent ops:
  - [x] `unary(select(...))` -> `select(unary(...), unary(...), cond)`
  - [x] `binary(select(...), const_like)` / `binary(const_like, select(...))` arm precompute
- [x] Full Precompute test suite added inline in `src/passes/precompute.mbt`
- [x] Optimize pipeline integration test added in `src/passes/optimize.mbt`
- [x] Bookkeeping updated (`AGENTS.md`, `agent-todo.md`)

## RedundantSetElimination pass

- [x] pass skeleton + registration (`src/passes/redundant_set_elimination.mbt`, `ModulePass::RedundantSetElimination`)
- [x] CFG/event traversal implemented for structured tree IR (`if` branch split + merge, nested block/loop/try conservatism, return/unreachable tail handling)
- [x] local-value numbering implemented with unique/unseen values and per-block merge values for multi-pred joins
- [x] entry-state initialization parity implemented (params start as unique unknown values; vars start as type-zero when defaultable, otherwise unique)
- [x] fixed-point flow implemented over CFG with deferred queue scheduling and convergence checks via end-state deltas
- [x] redundant `local.set` elimination implemented (`local.set x v` where value number unchanged -> `drop(v)`)
- [x] redundant `local.tee` elimination implemented (`local.tee x v` where value number unchanged -> `v`)
- [x] `local.get` refinement implemented (retarget to equal-value local with strictly more-refined reference type using `Match::matches`)
- [x] rewrite pass implemented with event-id stability across analysis/rewrite to keep CFG decisions aligned with transformed IR
- [x] comprehensive inline test suite added (straight-line, tee, zero-init, param-unknown, branch-merge keep/remove, refinement + validate, nested-block conservatism, idempotency)
- [x] optimize pipeline integration test added in `src/passes/optimize.mbt`
- [x] docs/bookkeeping updated (`AGENTS.md`, `agent-todo.md`)

## 3) Binaryen Passes Still To Implement

### A) Primary Optimization / Analysis Passes
- [x] Binaryen Pass: Asyncify.cpp
- [x] Binaryen Pass: I64ToI32Lowering.cpp
- [x] Binaryen Pass: Inlining.cpp
- [x] Binaryen Pass: LocalCSE.cpp
- [x] Binaryen Pass: LocalSubtyping.cpp
- [x] Binaryen Pass: LoopInvariantCodeMotion.cpp
- [x] Binaryen Pass: MemoryPacking.cpp
- [x] Binaryen Pass: MergeBlocks.cpp
- [x] Binaryen Pass: MergeLocals.cpp
- [x] Binaryen Pass: MergeSimilarFunctions.cpp
- [x] Binaryen Pass: OnceReduction.cpp
- [x] Binaryen Pass: OptimizeAddedConstants.cpp
- [x] Binaryen Pass: OptimizeCasts.cpp
- [x] Binaryen Pass: OptimizeInstructions.cpp
- [x] Binaryen Pass: PickLoadSigns.cpp
- [x] Binaryen Pass: Precompute.cpp
- [x] Binaryen Pass: RedundantSetElimination.cpp
- [x] Binaryen Pass: RemoveUnusedBrs.cpp
- [x] Binaryen Pass: RemoveUnusedModuleElements.cpp
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
- [x] Binaryen Pass: MinimizeRecGroups.cpp
- [x] Binaryen Pass: Monomorphize.cpp
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
