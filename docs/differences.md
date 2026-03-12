# Optimize Pipeline Differences vs. Binaryen

This document records the current findings from comparing this repository's default optimize pipeline against Binaryen's `PassRunner::addDefault*OptimizationPasses()` and `PassRunner::run()` behavior.

The short version is:

- The MoonBit optimize pipeline is intentionally modeled on Binaryen's no-DWARF default path.
- The pass order is broadly similar, especially in the function pipeline.
- The implementation is not pass-for-pass or runtime-for-runtime identical.
- The largest differences are not cosmetic pass-name gaps. They are IR-shaping substitutions, runner behavior, and validation behavior.

For the current performance investigation, the practical conclusion is that Binaryen's high-level sequence is a useful reference for intent, but not a reliable reference for runtime cost in this codebase.

## Scope

This comparison is based on:

- Binaryen's default optimization pass construction and runner logic from the user-provided `PassRunner` source snippet.
- The local MoonBit implementation in [src/passes/optimize.mbt](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt).

The most relevant local entry points are:

- [default_function_optimization_passes](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1841)
- [default_global_optimization_pre_passes](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1943)
- [default_global_optimization_post_passes](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L2006)
- [optimize_module_with_options_internal pass loop](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1493)
- [pass application helpers](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L204)
- [IR-context scheduler dispatch](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L503)

## Overall Finding

The local code explicitly states that its default pipelines "intentionally mirror Binaryen's no-DWARF path" in:

- [function passes](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1845)
- [global pre passes](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1948)

That statement is directionally true, but only at the pass-sequence level. Once execution strategy and validation policy are included, parity becomes approximate rather than strict.

## 1. Function Pipeline: Broadly Similar Shape, Not Exact Parity

The local function pipeline follows the same overall Binaryen pattern:

1. early normalization / simplification
2. dead code and branch cleanup
3. early instruction-level cleanup and propagation
4. locals-focused cleanup and coalescing
5. structure cleanup and merge-block cleanup
6. late propagation and final cleanup

The actual local sequence is visible in [src/passes/optimize.mbt#L1841](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1841).

That broad shape matches Binaryen closely enough that the pipeline "looks right" at first glance. The rest of this section explains the specific mismatches.

## 2. `DataflowOptimization` Replaces Binaryen's `ssa-nomerge`

This is the most important pass-list difference in the function pipeline.

Local code:

- [src/passes/optimize.mbt#L1853](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1853)

The local comment says:

- Binaryen parity mode: `ssa-nomerge`
- Fallback to SSA dataflow simplification in this IR pipeline

That is not a mechanical substitution. In Binaryen, `ssa-nomerge` is primarily an untangling pass that moves locals toward semi-SSA form without introducing merge copies. It is used to improve the shape of the IR before later function passes.

By contrast, the local pipeline runs `DataflowOptimization`, which is a real optimization pass with its own transformation behavior and cost profile. That matters for two reasons:

- It can change IR shape more aggressively than a mostly-normalizing untangling pass.
- Any extra expression duplication, local rewriting, or control-flow restructuring introduced here can amplify the cost of downstream passes like `Flatten`, `SimplifyLocals`, `Vacuum`, and `MergeBlocks`.

This difference is important enough that it should be treated as a semantic divergence, not a naming divergence.

## 3. `RemoveUnusedNames` Cleanup Points in the Default Function Pipeline

Binaryen runs `remove-unused-names` multiple times in the function pipeline. The local pipeline now mirrors those cleanup points in the default path.

Relevant local sequence:

- [src/passes/optimize.mbt#L1866](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1866)
- [src/passes/optimize.mbt#L1921](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1921)

What Binaryen does conceptually:

- `dce`
- `remove-unused-names`
- `remove-unused-brs`
- `remove-unused-names`
- later, after `merge-blocks` and `remove-unused-brs`, another `remove-unused-names`

What the local pipeline now does:

- `DeadCodeElimination`
- `RemoveUnusedNames`
- `RemoveUnusedBrs`
- `RemoveUnusedNames`
- later cleanup passes
- `MergeBlocks`
- `RemoveUnusedBrs`
- `RemoveUnusedNames`
- `MergeBlocks`

Impact:

- This parity gap is now closed.
- It is still probably not a primary runtime cause of the observed optimizer stall.
- The function cleanup choreography now better matches Binaryen's repeated branch-name cleanup pattern.

This difference matters for correctness of the comparison, but it is probably second-order for performance.

## 4. The Second `OptimizeInstructions` Pass Uses a Large-Module Runtime Guard Instead of Unconditional Binaryen Parity

Binaryen always runs a late `optimize-instructions` pass near the end of the function pipeline.

The local pipeline may skip that pass:

- [cleanup cost heuristic](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1836)
- [policy gate](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1928)
- [conditional insertion](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1934)

The local logic computes a cleanup cost profile and suppresses the second `OptimizeInstructions` pass when the module looks too expensive, but only for the throughput-oriented default path. When the caller explicitly asks for stronger size cleanup with `shrink_level >= 2`, the late `OptimizeInstructions` pass is retained even on large modules.

Impact:

- This is a deliberate divergence from Binaryen.
- It still reduces work on very large throughput-focused modules, so it is not a candidate explanation for the slowdown by itself.
- It means the tail of the local pipeline is explicitly trading Binaryen parity for runtime protection on the default throughput path.
- It also means size-focused runs intentionally opt back into the late cleanup stage instead of letting the large-module heuristic silently override explicit shrink intent.
- Any comparison of late-pipeline output or late cleanup opportunities must account for the fact that Binaryen always executes that cleanup stage and the local implementation now does so only when the module is not considered too expensive or when size-focused optimization was explicitly requested.

This is an optimization-policy difference, not just an implementation detail.

## 5. Global Pre-Pass Closed-World Unused Cleanup Now Uses `RemoveUnusedModuleElements`

The local global pre-pass sequence is in [src/passes/optimize.mbt#L1943](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1943).

Binaryen's default pre-pass flow conceptually includes:

- `duplicate-function-elimination`
- `remove-unused-module-elements` at `-O2+`
- `memory-packing`
- `once-reduction` at `-O2+`
- then several GC-specific global passes under the right feature / closed-world conditions

The local code now follows that structure directly:

- [src/passes/optimize.mbt#L1953](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1953)
- [src/passes/optimize.mbt#L1975](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1975)

When `closed_world` is true, the local pipeline now also pushes `RemoveUnusedModuleElements` at the same two pre-pass cleanup points.

Why this mattered:

- Those are not just alternate spellings.
- They imply different implementation boundaries and potentially different dead-code-elimination reach.
- The amount of dead material removed before function passes can materially affect later pass cost.
- Aligning the default closed-world scheduler choice removes that policy-level parity divergence, even though performance consequences still need to be evaluated empirically on pathological modules.

This scheduler parity gap is now closed, though the downstream cost model still needs measurement if performance work later points back at pre-pass cleanup behavior.

## 6. Closed-World GC Pre-Pass Handling Is Mostly Similar, with a Small CFP Difference

The local GC pre-pass handling tracks Binaryen's broad intent:

- `TypeRefining`
- `SignaturePruning`
- `SignatureRefining`
- `GlobalRefining`
- `GlobalTypeOptimization`
- unused cleanup
- constant field propagation
- `GlobalStructInference`
- `AbstractTypeRefining`
- `Unsubtyping`

Relevant local range:

- [src/passes/optimize.mbt#L1965](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1965)

Binaryen's `cfp-reftest` choice is still broader than the local implementation:

- [src/passes/optimize.mbt#L1982](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1982)

The local scheduler now splits the previously conflated behavior into two passes:

- `ConstantFieldPropagation` for direct constant-field read replacement.
- `ConstantFieldNullTestFolding` for the narrow case where a field read is proven to be `ref.null` and a surrounding `ref.test` / `ref.test_desc` can be folded to `i32.const 0` or `i32.const 1`.

This is an honest split, not full parity with Binaryen's broader `cfp-reftest` transform.

Impact:

- The misleading one-pass parity claim is gone.
- The remaining difference is narrower and explicit: the local `ConstantFieldNullTestFolding` pass only covers the known-null subcase rather than Binaryen's wider subtype-selection rewrites.
- It is unlikely to be central to the currently observed stall.

## 7. The Local Global Post Pipeline Now Includes `InliningOptimizing` at the Binaryen-Parity Gate

The local post-pass sequence is in [src/passes/optimize.mbt#L2006](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L2006).

Binaryen normally includes `inlining-optimizing` in this phase under the right optimize / shrink settings.

The local pipeline now does the same:

- [src/passes/optimize.mbt#L2015](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L2015)

Impact:

- This scheduler gap is no longer an open parity blocker.
- The global post-pipeline now inlines before duplicate-function elimination and simplify-globals cleanup the same way Binaryen's default post sequence expects.
- Remaining differences in this phase are now the feature-specific missing `StringGathering` pass and any behavior differences inside the local inliner itself rather than a missing scheduler hook.

## 8. `StringGathering` Is Not Implemented in the Local Post Pipeline

Binaryen can insert `string-gathering` in the global post phase under the relevant feature and optimization settings.

The local code records this as not yet implemented:

- [src/passes/optimize.mbt#L2033](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L2033)

Impact:

- This is a parity gap.
- It is feature-specific.
- It is probably unrelated to the current pathological `Vacuum` / deep-tree issue.
- It should still be documented because it is a direct omission relative to Binaryen's default post pipeline.

This is a completeness difference more than a performance difference for the issue currently under investigation.

## 9. `Directize` Parity Is Close, but the Local Pipeline Encodes a Specific Mode

The local post-pass tail ends with:

- [src/passes/optimize.mbt#L2039](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L2039)

The comment notes that Binaryen's default pass uses `directize` with initial table contents considered immutable, and the local code encodes that as `Directize(true)`.

Impact:

- This is mostly parity-preserving, not parity-breaking.
- It is still worth recording because it shows the local implementation is matching Binaryen by selecting a specific mode explicitly rather than just naming the pass.

This is an example of a local difference that looks different in code shape but is intended to preserve behavior.

## 10. The Largest Runtime Difference Is the Runner, Not the Pass List

This is the most important non-pass-list finding.

Binaryen's normal non-debug runner does not simply execute one full pass over the whole module, then the next, then the next. Instead, it batches function-parallel passes together and runs the whole stack on one function before moving to the next function, using a thread pool.

That matters because it improves:

- cache locality
- reuse of recently visited function state
- reduced repeated module-wide traversal overhead
- parallel throughput across functions

The local runner does not follow that model.

Relevant local pass loop:

- [src/passes/optimize.mbt#L1493](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1493)

Relevant local scheduler helpers:

- [apply_transformer_pass](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L204)
- [apply_ir_transformer_pass](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L216)
- [apply_unit_transformer_pass](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L225)
- [apply_module_runner_pass](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L233)
- [run_ir_context_transformer_scheduler_pass](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L503)

What the local code does:

- iterates `for pass in passes`
- dispatches each pass by pass kind
- applies that pass directly to the module
- validates the module
- proceeds to the next pass

What it does not do:

- build a Binaryen-style stack of function-parallel passes
- run that stack per function for locality
- expose Binaryen-like worker scheduling for the default path

Impact:

- This is a fundamental runtime behavior difference.
- It means that even if the pass order is close, the execution cost profile is not.
- It increases the importance of every full-module walk.
- It increases the cost of repeated passes over very large or pathological functions.
- It makes a direct "Binaryen handles this fine, so our pipeline should too" argument much weaker.

For performance analysis, this finding is at least as important as any individual pass substitution.

## 11. The Local Optimizer Validation Policy Is Now Configurable

The local optimizer no longer validates unconditionally after every pass in the default non-debug path.

- validation policy definition: [src/passes/optimize.mbt](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt)
- final-only validation path: [src/passes/optimize.mbt#L1683](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1683)
- explicit per-pass validation path: [src/passes/optimize.mbt#L1603](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1603)

`OptimizeOptions` now carries an `OptimizeValidationPolicy` value. The default is final-module validation only, which is closer to Binaryen's normal non-debug behavior. The stricter old behavior still exists behind an explicit `AfterEveryPass` opt-in for debugging, pass-development, and targeted validation-heavy workflows.

Impact:

- The default optimization runner no longer adds a mandatory full-module validation walk after every pass.
- Runtime comparisons against Binaryen are less distorted by runner-imposed validation overhead.
- The optimizer still preserves useful failure diagnostics by attributing a final validation error to the last executed pass and including before/after snapshots when available.
- Users who want the previous validation cadence can still request it directly through `OptimizeOptions`.

## 12. The Local Runner Has a `Vacuum` Skip Heuristic That Binaryen Does Not

The local runner tracks whether the previous `Vacuum` made no changes and whether anything changed since then:

- [skip condition](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1502)
- [state tracking](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt#L1657)

If a previous `Vacuum` was a no-op and nothing has changed since, the next `Vacuum` is skipped.

Impact:

- This is a local runtime guard not present in the Binaryen reference path discussed here.
- It is a pragmatic defense against repeated useless cleanup work.
- It only protects repeated no-op `Vacuum` invocations.
- It does not protect the first expensive `Vacuum` on a pathological function shape.

This matters because it shows the local pipeline is already compensating for cleanup cost in ways that diverge from strict Binaryen parity.

## 13. Pass-Sequence Parity Is Better Than Cost-Model Parity

This is the most useful high-level conclusion from the comparison.

If the question is "Does the local optimize pipeline broadly follow Binaryen's default no-DWARF ordering?", the answer is yes.

If the question is "Should the local optimizer have roughly the same runtime behavior as Binaryen on difficult functions because the pass list looks similar?", the answer is no.

The reasons are:

- `DataflowOptimization` is not equivalent to `ssa-nomerge`.
- the local pipeline omits some Binaryen cleanup passes such as repeated `remove-unused-names`
- the local pipeline still omits some feature-specific passes such as `string-gathering`
- the local runner executes passes differently
- the local runner validates after every pass
- the pass implementations themselves are local implementations, not Binaryen's implementations

The practical outcome is that pass-order similarity does not imply cost similarity.

## 14. Which Differences Are Probably Cosmetic vs. Which Ones Matter for Performance

### Mostly comparison-completeness differences

These matter for accuracy of the comparison, but are less likely to explain the observed pathological slowdown on their own:

- missing `RemoveUnusedNames` in the function pipeline
- missing `StringGathering`
- local `cfp-reftest` parity remains partial, but the narrower known-null handling is now split into `ConstantFieldNullTestFolding`
- explicit `Directize(true)` mode selection

### Performance-relevant differences

These are the differences most likely to affect runtime materially:

- `DataflowOptimization` replacing `ssa-nomerge`
- no Binaryen-style stacked function-parallel runner
- unconditional per-pass validation
- local cleanup-avoidance heuristics that already acknowledge cleanup cost pressure
- local pass implementations with different internal complexity from Binaryen

These are the findings that should drive any serious performance investigation.

## 15. Why This Comparison Matters for the Current Pathological Case

The original motivation for this comparison was a long-running optimize pipeline in which later cleanup stages, especially `Vacuum`, appeared to stall on a pathological function shape.

This comparison does not prove that any single pipeline mismatch is the root cause. It does clarify where not to oversimplify:

- It is not enough to say "the pass order matches Binaryen."
- It is not enough to compare only the list of passes.
- It is not enough to assume Binaryen's cost behavior transfers to this codebase.

The most likely performance-relevant interpretation is:

1. the local pipeline broadly follows Binaryen's intended choreography
2. earlier local passes can still produce materially different IR than Binaryen would
3. the local runner adds more overhead around each pass than Binaryen's normal path
4. later expensive passes therefore see both different IR and different surrounding runtime costs

That is the right framing for investigating the observed churn and apparent stall.

## 16. Bottom Line

The current local optimize pipeline is best described as:

- Binaryen-inspired in pass order
- intentionally approximate rather than strictly identical
- materially different in execution strategy
- materially different in validation policy
- therefore not expected to match Binaryen's runtime behavior on hard cases

Any future parity work should treat these as separate goals:

1. pass-sequence parity
2. IR-shaping parity
3. runner/runtime parity
4. pass-internal complexity parity

Without all four, "we mirror Binaryen" is only partially true.
