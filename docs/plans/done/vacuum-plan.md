# Vacuum Performance Plan

## Goal

Reduce pathological `Vacuum` runtimes from tens of minutes to something bounded and predictable, without regressing correctness on the existing control-flow and stack-shape corner cases in `src/passes/vacuum.mbt`.

This plan is based on inspection of:

- `src/passes/vacuum.mbt`
- `src/passes/optimize.mbt`
- `src/passes/local_cse.mbt`
- `src/passes/dead_code_elimination.mbt`
- `src/passes/remove_unused_brs.mbt`
- `docs/differences.md`
- `docs/tracing.md`

## Executive Summary

The main problem does not look like a single bad rewrite. It looks like `Vacuum` is paying for too many full-subtree analyses up front and then paying again during rewrites:

1. `Vacuum` seeds whole-function facts before any function-level budget can stop it.
2. The pass caches by `TInstr` / `TExpr` value, which is convenient but likely too expensive on deep recursive trees.
3. Several rewrites trigger additional whole-subtree scans or rewrites even after the seed phase.
4. The current budget is based on top-level instruction count, which is a poor proxy for pathological deep trees.
5. The existing optimize-runner skip heuristic only avoids repeated no-op `Vacuum` runs. It does not protect the first expensive run.

The best fix is not "increase the budget" or "skip more often." The best fix is to make `Vacuum` closer to a single analyzed walk with cheap indexed lookups, then add shape-aware guardrails so worst-case functions degrade gracefully instead of exploding.

## Current Findings

### 1. The pass seeds an entire function before the budget matters

`vq_optimize_function` always calls `vq_seed_texpr_facts(body, env, analysis_cache)` before the main optimization sequence starts. See `src/passes/vacuum.mbt:2760-2865`, especially `2803-2814`.

That means:

- the current budget does not bound the initial analysis cost
- the first expensive `Vacuum` on a bad function can still be extremely slow
- later early returns only limit rewrite work, not front-loaded analysis work

This matches the note in `docs/differences.md` that the current runner skip only helps repeated no-op `Vacuum` invocations, not the first pathological one.

### 2. The cache design is probably hiding a large constant factor

`VQAnalysisCache` stores many `Map[TInstr, ...]` and `Map[TExpr, ...]` tables. See `src/passes/vacuum.mbt:680-693`.

That is a red flag for deep recursive IR:

- every cache lookup and insert has to hash and compare recursive AST values
- if hashing or equality walks the tree structurally, the "cached" operation can still cost O(subtree size)
- the pass uses these caches constantly in hot loops

The hottest examples are:

- type cache: `src/passes/vacuum.mbt:170-187`
- effect cache: `src/passes/vacuum.mbt:190-209`
- control-transfer cache: `src/passes/vacuum.mbt:267-279`
- stack-signature cache: `src/passes/vacuum.mbt:1457-1474`

If the cache key cost scales with subtree size, then deep-tree pathologies will defeat the cache.

### 3. `Vacuum` reuses expensive shared helpers that walk whole subtrees

The pass delegates several core questions to helpers from other passes:

- `lcs_collect_effects(instr)` in `src/passes/local_cse.mbt:513-525`
- `lcs_collect_shallow_effects(instr)` in `src/passes/local_cse.mbt:529-532`
- `lcs_infer_tinstr_type(instr, env)` in `src/passes/local_cse.mbt:1005+`
- `has_break_to_depth_in_texpr(expr, depth)` in `src/passes/dead_code_elimination.mbt:870-877`

Those helpers are correct and reusable, but in `Vacuum` they are called in a pass that is already recursively analyzing and rebuilding the same tree. That compounds cost.

### 4. Seeded analysis is broad and recursive

`vq_seed_instr_facts` recursively visits all recursive children, then also computes shallow effects, local control-transfer facts, and stack signatures. See `src/passes/vacuum.mbt:869-933`.

`vq_seed_texpr_facts` recursively seeds nested blocks, loops, if arms, and try bodies, then asks `vq_seed_instr_facts` for each top-level instruction in the expression. See `src/passes/vacuum.mbt:936-981`.

This is a large front-loaded pass over the whole function. It is useful, but the current design suggests:

- one big recursive prepass
- followed by another recursive optimization pass
- followed by extra targeted subtree scans during specific rewrites

That is a bad fit for very deep or very wide pathological shapes.

### 5. Several rewrite helpers trigger extra whole-subtree work

#### `vq_simplify_block_to_contents`

See `src/passes/vacuum.mbt:1731-1768`.

It immediately calls `has_break_to_depth_in_texpr(body, 0)` before collapsing a wrapper block. That is another subtree walk. It also calls `vq_rebase_labels_for_collapsed_wrapper` on single-item collapses.

#### `vq_rebase_labels_for_collapsed_wrapper`

See `src/passes/vacuum.mbt:331-429`.

This constructs a transformer and walks the instruction again to adjust labels when collapsing wrappers. On nested wrapper-heavy shapes, repeated collapse + rebase can become another major source of repeated tree work.

#### `vq_value_break_to_depth_has_lub`

See `src/passes/vacuum.mbt:2116-2360`.

This is a full recursive collection over an expression tree to decide whether dropping the tail of a result block is safe. It is cached only for `depth == 0`, which helps some cases, but the operation is still expensive and easy to trigger in nested result-heavy trees.

#### `vq_rewrite_preserves_*`

See:

- `src/passes/vacuum.mbt:991-1004`
- `src/passes/vacuum.mbt:1007-1016`

These use non-cached type and stack-signature computation on both `before` and `after`. That is a correctness-friendly check, but it is expensive in rewrite-heavy paths.

### 6. The budget heuristic is too weak and uses the wrong size metric

`vq_optimize_function` uses:

- `80000` budget if `top_instrs > 200`
- otherwise `12000`

See `src/passes/vacuum.mbt:2803-2804`.

Problems:

- `top_instrs` only measures the number of instructions in the top-level body
- pathological trees can have very small `top_instrs` and enormous total subtree size
- the budget does not cover the seed phase anyway
- "return current instruction unchanged when budget is gone" prevents some rewrites, but does not guarantee a low total runtime

### 7. The first expensive `Vacuum` is still unprotected at the optimizer level

The optimize runner skips a redundant later `Vacuum` if the previous `Vacuum` made no changes and nothing changed since. See `src/passes/optimize.mbt:1513-1708`, especially `1529-1540` and `1700-1707`.

That is useful but insufficient:

- it does not protect the first expensive `Vacuum`
- it does not use function shape or prior timing
- it does not let `Vacuum` degrade to a cheaper mode on known-bad functions

## Likely Root Causes

Ordered by expected impact:

### A. Cache key cost is too high

The biggest structural suspicion is the `Map[TInstr, ...]` / `Map[TExpr, ...]` design. If those keys are structurally hashed and compared, the pass may be spending large amounts of time just looking up cached facts.

Expected symptom:

- cache hit counts look good
- runtime is still terrible

### B. Repeated whole-tree traversals are stacked on top of each other

The pass currently does all of the following:

- whole-function seed
- recursive optimize walk
- repeated block-collapse scans
- repeated label-rebase rewrites
- repeated type / stack-preservation checks
- occasional value-break LUB collection

That combination is enough to create quadratic or worse behavior on deep or repeated wrapper/control-flow shapes.

### C. The guardrails are aimed at the wrong failure mode

The current guardrails mostly help:

- trivial functions
- repeated no-op `Vacuum` passes
- rewrite work after the pre-analysis already happened

They do not directly address:

- deep nesting
- huge total subtree size with small top-level body length
- repeated collapse/rebase churn

## Recommended Strategy

Use a staged approach. Do not try to rewrite `Vacuum` all at once.

### Stage 0: Instrumentation First

Before changing algorithms, add enough detail to prove where time is going.

#### Add per-function shape metrics

For each function, record:

- total instruction count, not just top-level instruction count
- max nesting depth
- block count
- if count
- drop count
- number of wrapper-like single-item blocks
- number of result-typed blocks

This should happen before seeding so that guardrails can use it.

#### Add per-phase timing inside `Vacuum`

At minimum, time:

- shape scan
- fact seeding
- main optimize sequence
- block-collapse / label-rebase work
- final can-nop-body decision

Also collect top-N slow functions, following the tracing guidance in `docs/tracing.md`.

#### Add helper-level counters for suspected hotspots

Count calls and elapsed time for:

- `vq_seed_texpr_facts`
- `vq_seed_instr_facts`
- `vq_simplify_block_to_contents`
- `vq_rebase_labels_for_collapsed_wrapper`
- `vq_value_break_to_depth_has_lub`
- `vq_rewrite_preserves_type_and_stack_sig`
- `vq_rewrite_preserves_stack_sig`
- fallback calls into `lcs_collect_effects`
- fallback calls into `lcs_infer_tinstr_type`
- fallback calls into `has_break_to_depth_in_texpr`

#### Add cache cardinality metrics

Record:

- unique `TInstr` entries inserted
- unique `TExpr` entries inserted
- per-cache hit/miss counts

If runtime is still high with high hit rates, that is strong evidence the key type itself is too expensive.

### Stage 1: Add Real Pathological Guardrails

These are the shortest-path fixes to prevent 30-40 minute disasters while deeper work is in progress.

#### 1. Budget the seed phase

The budget needs to cover:

- shape scan
- seed pass
- rewrite pass

If the seed phase alone can run unbounded, the runtime problem remains.

#### 2. Replace `top_instrs` with a better cost model

Use a pre-scan to derive a function cost estimate based on:

- total instructions
- max depth
- control-flow node count
- wrapper-block density

Deep-tree pathologies are specifically missed by the current `top_instrs` heuristic.

#### 3. Add a degraded mode, not just a stop flag

When a function is classified as too expensive:

- do not run full `Vacuum`
- run only the cheapest local rewrites

Cheap local rewrites likely include:

- `drop(local.tee(x)) -> local.set(x)`
- dropping obviously pure constants / local.get / global.get
- constant-condition `if` folding when the condition is already a const
- removing `nop`-only loop or empty void block cases that need no deep stack reasoning

This keeps progress on easy wins while bounding pathological behavior.

#### 4. Make the degraded-mode reason explicit in trace output

Emit one clear reason per skipped/degraded function, for example:

- `pathological_shape=true`
- `seed_budget_exceeded=true`
- `mode=cheap_only`

### Stage 2: Replace Value-Keyed Caches With Node-Indexed Analysis

This is the highest-value structural change.

#### Why this should be the main fix

The current cache API is convenient, but it is likely turning many "O(1) cache hits" into "re-hash / re-compare a recursive AST".

Instead:

1. assign a stable integer id to each `TInstr` and `TExpr` in a prepass
2. store analysis facts in arrays indexed by id
3. store parent / depth / local shape metadata alongside those ids

Expected benefits:

- cheap cache lookup
- cheap cache insert
- easy phase timing and cardinality accounting
- direct support for bottom-up analysis

#### Suggested data layout

Build a per-function analysis table that stores, for each node id:

- kind
- depth
- result type or unknown
- shallow effect bits
- subtree effect bits
- subtree has calls
- subtree has control transfer
- subtree throws
- subtree has explicit unreachable
- may-not-return
- stack signature
- maybe "has break to wrapper depth 0"

For expressions:

- top-level result type summary
- subtree control-transfer summary
- subtree explicit-unreachable summary
- subtree throw summary
- block-collapse safety metadata

#### Important design choice

Do not compute these facts with many independent recursive helpers. Compute them in one post-order analysis over the function.

### Stage 3: Remove Repeated Full-Subtree Scans From Rewrite Paths

Once node-indexed facts exist, start deleting the repeat scans.

#### 1. Replace `has_break_to_depth_in_texpr(body, 0)` in block simplification

Current code:

- `src/passes/vacuum.mbt:1737-1739`

Plan:

- compute wrapper-break metadata during the main analysis
- make block-collapse safety a constant-time lookup

This is especially important because block simplification is on a hot path.

#### 2. Replace full-tree label rebasing with a cheaper strategy

Current code:

- `src/passes/vacuum.mbt:331-429`

Likely better options:

- represent "collapsed one wrapper level" as a depth delta carried during rebuild
- or perform rebasing only on the exact subtree being returned, using node ids and a purpose-built rebasing walk
- or only invoke rebasing when precomputed metadata says the subtree actually contains labels at or above the affected depth

The current generic transformer is safe but expensive.

#### 3. Stop using general-purpose type/effect helpers in hot rewrite checks

Examples:

- `vq_rewrite_preserves_type_and_stack_sig`
- `vq_rewrite_preserves_stack_sig`
- `vq_has_unremovable_effects_cached`

Plan:

- use precomputed node facts for old nodes
- compute new-node facts with specialized local formulas when the rewrite shape is known
- fall back to generic helpers only for uncommon cases

#### 4. Replace recursive value-break LUB scans with precomputed block metadata

Current code:

- `src/passes/vacuum.mbt:2116-2360`
- especially the use in `2604-2637`

Plan:

- compute whether a block has value breaks to depth 0
- compute their type set summary or "unknown / multivalue / compatible / incompatible" during analysis
- use that summary directly during drop-of-result-block rewrites

### Stage 4: Split `Vacuum` Into Cheap and Expensive Tiers

If Stage 2 and Stage 3 are still not enough, split the pass intentionally.

#### Cheap tier

Single-pass local simplifications that do not require expensive global reasoning.

Examples:

- trivial `drop` simplifications
- constant-condition `if` folding
- no-op loop / block cleanup
- dropping side-effect-free leaf expressions

#### Expensive tier

Only run on functions whose shape passes a cost threshold.

Examples:

- stack-signature-sensitive rewrites
- wrapper-collapse with label rebasing
- branch-value LUB reasoning
- traps-never-happen cleanup that depends on richer control-flow facts

This gives the optimizer a clean degrade path instead of an all-or-nothing `Vacuum`.

## Detailed Implementation Order

Recommended order of work:

1. Add shape scan + per-phase timings + top-N hotspot reporting.
2. Add a pathological-function classifier based on total nodes and depth.
3. Budget the seed phase and add a cheap-only degraded mode.
4. Add targeted regression fixtures for pathological shapes before touching internals.
5. Replace `Map[TInstr, ...]` / `Map[TExpr, ...]` caches with per-node integer indexing.
6. Convert seed logic into one fused post-order analysis.
7. Remove hot-path subtree rescans:
   - block-collapse break scan
   - label rebasing where avoidable
   - value-break LUB rescans
   - generic type / stack preservation rescans
8. Revisit thresholds and decide whether the cheap/expensive split should remain permanent.

## Tests To Add Before Code Changes

No code is being changed in this document, but the implementation should follow TDD. The first code change should be tests.

### Pathological-shape regression fixtures

Add generator-backed tests for:

- deeply nested single-child blocks
- deeply nested dropped wrappers
- repeated nested `if` trees with empty / near-empty arms
- result-typed nested blocks that trigger wrapper-collapse checks
- branch-heavy shapes that trigger label rebasing

These should assert:

- output still validates
- expected simple rewrites still happen where applicable
- the pass completes through a bounded code path

### Guardrail tests

Add tests that prove:

- pathological shape classification triggers degraded mode
- seed-phase budget exhaustion does not fail the pass
- degraded mode keeps the module valid
- cheap rewrites still occur in degraded mode

### Analysis-cache tests

Once node-indexed analysis exists, add tests for:

- stable node-id assignment within one function traversal
- correctness of cached stack signatures
- correctness of cached control-transfer / throw / explicit-unreachable facts
- correctness of cached wrapper-collapse metadata

Do not add trace-only tests.

## Things That Are Unlikely To Be Sufficient

These may help a little, but they do not look like real fixes:

- increasing the existing rewrite budget
- tweaking the `top_instrs > 200` threshold
- relying on the optimizer's repeated no-op `Vacuum` skip
- only adding more cache tables while still keying them by `TInstr` / `TExpr`
- only disabling validation, since the report specifically points at `Vacuum` runtime itself

## Risks And Tradeoffs

### Correctness risk

`Vacuum` has many existing tests around stack shape, value typing, and control transfer. Any aggressive simplification of the implementation must preserve those invariants.

The riskiest changes are:

- replacing stack-signature checks with local formulas
- changing wrapper-collapse and label-rebase logic
- degrading behavior for large functions

That is why the plan stages guardrails first, then node-indexed analysis, then rewrite simplification.

### Temporary compile-time regression risk

Instrumentation-heavy builds may initially add overhead. That is acceptable for short-lived diagnostic work, but the final implementation should leave only the cheap counters and optional trace paths.

### Maintenance tradeoff

A fused analysis table is more code than "call shared helper when needed," but the current shared-helper model appears too expensive for pathological functions. This is a case where local specialization is justified.

## Recommended End State

The target design should look like this:

1. one cheap pre-scan classifies function shape
2. one bounded post-order analysis computes all reusable facts by node id
3. one rewrite walk uses constant-time indexed lookups
4. pathological functions degrade to a cheap tier instead of attempting the full expensive logic
5. traces report where time went and why any function was skipped or degraded

If implemented in that order, the first expensive pathological `Vacuum` run should become bounded, observable, and substantially faster instead of depending on a later no-op skip to save runtime.
