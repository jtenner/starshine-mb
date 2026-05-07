---
kind: concept
status: supported
last_reviewed: 2026-05-07
sources:
  - ../../../raw/binaryen/2026-05-05-precompute-current-main-recheck.md
  - ../../../raw/research/0468-2026-05-05-precompute-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-precompute-current-main-port-readiness.md
  - ../../../raw/research/0400-2026-04-26-precompute-port-readiness.md
  - ../../../raw/binaryen/2026-04-22-precompute-primary-sources.md
  - ../../../raw/research/0132-2026-04-20-precompute-binaryen-research.md
  - ../../../raw/research/0251-2026-04-22-precompute-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0268-2026-04-23-generated-o4z-precompute-slot43-retired-by-hot-lower-prefix-label-guard.md
  - ../../../../../src/passes/precompute.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/precompute_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/ir/hot_lower_test.mbt
  - ../../../raw/research/0096-2026-04-18-generated-o4z-precompute-slot19-missing-i32-result.md
  - ../../../raw/research/0105-2026-04-18-generated-o4z-precompute-slot19-retired-by-writeback-guards.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./propagation-partial-precompute-and-gc-identity.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../precompute-propagate/index.md
---

# Starshine `precompute` strategy today

This page describes the **current in-tree Starshine implementation**, not the full upstream Binaryen `version_129` contract. For the future-slice and validation ladder that sits on top of this code map, read [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Short version

Starshine currently implements a deliberately narrow HOT-IR `precompute` pass focused on:

- exact i32/i64 unary and binary folds
- raw stack-level shortcuts for no-candidate functions, nested nop-only control, adjacent scalar folds, branch-free constant-`if` arm picks, immutable module-constant `global.get` folds, mutable/global no-candidate reads, dropped flat nontrapping scalar/global expressions, and preserved effectful/trapping dropped tails with no remaining precompute candidates, so they can skip HOT lift/lower safely while unsupported pure drop cleanup and label-relative branchy arm picks stay on the HOT path
- exact i32/i64 comparisons lowered to i32 boolean constants
- immutable scalar-or-null `global.get` replacement
- constant-`if` arm picking
- dead pure-`drop` cleanup
- root-region `nop` / empty-wrapper cleanup needed for safe writeback
- artifact-driven invalid-lower and writeback-validation guard rails around the old slot-19 failure family

That is useful and already well tested.

But it is still much smaller than upstream Binaryen plain `precompute`, and much smaller again than the full `precompute` + `precompute-propagate` family.

## Exact local code map

The 2026-04-26 readiness capture confirms that the important local follow-along points are `src/passes/precompute.mbt:1-1158` for HOT rewrites, `src/passes/pass_manager.mbt:8185-8484` for writeback validation / escape-carrier guards, `src/passes/optimize.mbt:207-276` and `394-417` for registry and preset placement, and `src/passes/precompute_test.mbt:1-342` for the current focused proof lane.
The 2026-05-05 current-main recheck did not move those follow-along points.

## 1. Registry entry and user-visible summary

The public local pass identity lives in [`src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt):

- `precompute_descriptor()`
  - declares the hot-pass name `precompute`
  - invalidates CFG, dominance, liveness, use-def, effects, loop-info, and SSA analyses
- `precompute_summary()`
  - currently promises: exact constant integer folding that is trap-free and stable across the top-level precompute slots

That wording is intentionally narrower than upstream Binaryen and still matches the code.

The pass also appears in the registry and preset expansions in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt):

- `pass_registry_entries()`
  - exposes `precompute` as an active hot pass
- `optimize_preset_passes(...)`
- `shrink_preset_passes(...)`
  - both replay `precompute` twice, matching the current local top-level PC slot story

## 2. Exact constant sources the pass knows how to read

The constant-source helpers are all in [`src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt). The same file now also owns a conservative raw stack-level shortcut for no-candidate functions, nested nop-only control, functions with only adjacent scalar folds, branch-free constant-`if` arm picks, immutable module-constant `global.get` folds, mutable/global no-candidate reads, dropped flat nontrapping scalar/global expressions, and preserved effectful/trapping dropped tails after raw folding exhausts safe candidates; that shortcut still refuses functions with `br_table`, label-relative branchy `if` arms, root-`nop` cleanup, or unsupported pure `drop` candidates so the HOT path handles structural cases.

The HOT constant-source helpers are:

- `precompute_global_const(...)`
  - resolves immutable defined-global initializers through `ctx.module_ctx`
- `precompute_i32_const(...)`
- `precompute_i64_const(...)`
  - read literal HOT `Const` nodes only
- `precompute_i32_exact_const(...)`
- `precompute_i64_exact_const(...)`
  - widen the local notion of “exact constant” to include immutable resolved globals

This is the first major difference from upstream Binaryen:
local `precompute` has no general interpreter and no `Flow` lattice here; it is a direct HOT constant recognizer over a small scalar/global subset.

## 3. Rewrite builders and the actual scalar folds

The core rewrite helpers also live in [`src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt):

- `precompute_replace_with_const_i32(...)`
- `precompute_replace_with_const_i64(...)`
  - build temporary HOT const nodes, replace the target node, and call `pass_mark_mutated(...)`
- `precompute_try_fold_global_get(...)`
  - rewrites immutable defined `global.get` to literal consts or `ref.null`
  - deliberately rejects `StringConst`, which keeps the local string gap explicit
- `precompute_try_fold_unary(...)`
  - currently covers only `i32.eqz` and `i64.eqz`
- `precompute_try_fold_binary(...)`
  - owns all current exact scalar binary folding
  - positive families today are integer add/sub/mul, bitwise ops, shifts, and the signed/unsigned compare set for both i32 and i64
  - trapping operators like division and remainder are intentionally absent

So the local coded fold surface is larger than the one-line summary, but still strictly scalar and trap-averse.

## 4. Constant-`if` lowering and root-shape rebuilding

The current constant-`if` implementation is also in [`src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt). The HOT implementation handles structural arm picking, and the raw shortcut now handles branch-free stack-level constant-`if` tails before adjacent scalar folds; label-relative branches (`br`, `br_if`, `br_table`, `br_on_*`) keep the function on the HOT path rather than being flattened raw.

HOT details:

- `precompute_try_fold_constant_if(...)`
  - proves the condition with `precompute_i32_exact_const(...)`
  - chooses the `then` or `else` region directly
  - emits `nop` if the chosen region is empty
  - replaces the `if` with the single surviving root if the chosen region has one root
  - otherwise rebuilds a result block via `@ir.hot_build_block(...)`

This is an important local read-along point: constant-`if` folding is not owned by `optimize-instructions` in Starshine today. It is a first-class part of the current local `precompute` file.

## 5. Dead-value and region-cleanup helpers bundled into the same pass

The structural cleanup cluster in [`src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt) is what makes the local pass more than “just fold constants.”

### Pure-value and drop cleanup

- `precompute_is_discardable_value(...)`
  - defines the local pure/discardable lattice
  - accepts `Const`, `LocalGet`, `GlobalGet`, `RefNull`, `RefFunc`, and recursively pure unary/binary/compare/convert/select trees
  - rejects anything with side effects, traps, control, terminators, or zero result arity
- `precompute_try_eliminate_dead_drop(...)`
  - turns `drop(pure-value)` into `nop`

### Region and wrapper cleanup

- `precompute_simplify_region_roots(...)`
  - recursively visits `block`, `loop`, `if`, `try`, and `try_table` regions
  - removes empty root `block` / `loop` wrappers when they are all-`nop`
  - splices folded void-`if` bodies directly into the parent region
  - removes dead dropped pure values from regions
- `precompute_region_is_all_nops(...)`
  - helper for the empty-wrapper rule
- `precompute_trim_region_nops(...)`
  - removes non-root `nop`s from nested regions after rewrites
- `precompute_coalesce_all_root_nops(...)`
  - collapses an all-`nop` root region to one `nop`
- `precompute_trim_root_nops_before_trailing_const(...)`
  - removes a pure root `nop` prefix before a surviving final `const`

This cleanup cluster is not a generic Binaryen port. It is a local HOT/writeback hygiene design that keeps rewritten regions simple enough to lower safely.

## 6. Fixpoint driver

The HOT pass driver is `precompute_run(...)` in [`src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt). For direct pass-manager execution, `precompute_run_raw_func(...)` can now return a raw rewritten function or a raw no-candidate skip before HOT lift when the function is inside the conservative stack-only subset, including nested nop-only control, adjacent folds, branch-free constant-`if` arm picks, immutable global folds, mutable/global no-candidate reads, dropped flat trap-free scalar/global expressions, and preserved effectful/trapping dropped tails with no remaining precompute candidate; the dispatcher provides module context only when raw scanning sees a `global.get`.

Each HOT round currently does:

1. `precompute_simplify_region_roots(...)`
2. full node scan for:
   - `precompute_try_fold_global_get(...)`
   - `precompute_try_eliminate_dead_drop(...)`
   - `precompute_try_fold_constant_if(...)`
   - `precompute_try_fold_unary(...)`
   - `precompute_try_fold_binary(...)`
3. `precompute_trim_region_nops(...)`
4. `precompute_coalesce_all_root_nops(...)`
5. `precompute_trim_root_nops_before_trailing_const(...)`

Then it repeats until a round makes no further changes.

That iterative HOT fixpoint is useful locally, but it is not Binaryen-shaped:
there is no compile-time interpreter, no partial-select climb, no local-flow propagation phase, and no explicit refinalization tail here.

## 7. Pipeline dispatch and writeback guards

The registry file is not the only place to read this pass.
The other critical owner is [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt).

### Dispatch

- the raw dispatcher first asks `precompute_run_raw_func(...)` whether scalar-only work, branch-free constant-`if` arm picking, module-proven immutable `global.get` constants, mutable/global no-candidate reads, dropped flat trap-free scalar/global expressions, preserved effectful/trapping dropped tails, nested nop-only control, or no-candidate functions can skip HOT lift/lower
- the hot-pass dispatcher maps `"precompute" => precompute_run(ctx, func)`

### Invalid-lower / writeback guard rails

The precompute-specific safety surfaces that retired the old slot-19 artifact failure also live here:

- `run_hot_pipeline_precompute_writeback_validation_error(...)`
  - produces a focused validation error for bad lowered output
- `run_hot_pipeline_precompute_branch_depth(...)`
- `run_hot_pipeline_precompute_has_control_transfer(...)`
- `run_hot_pipeline_precompute_has_mismatched_escape_carrier_block(...)`
- `run_hot_pipeline_precompute_lowered_func_has_invalid_escape_carrier(...)`
  - detect suspicious lowered carrier shapes before committing bad writeback

Those helpers are consulted both in precompute-specific validation paths and in neighboring guarded passes that share the same writeback-sensitive carrier family.

This is one of the most important practical differences from upstream Binaryen: a real part of current Starshine `precompute` lives in pipeline safety code, not only in the pass file.

## What the current proof surface looks like

## 1. Main pass-local behavior tests

[`src/passes/precompute_test.mbt`](../../../../../src/passes/precompute_test.mbt) is the primary local semantic proof lane.

Important focused tests include:

- `precompute folds exact i32 constant arithmetic`
- `precompute folds chained exact constants in one pass`
- `precompute folds exact i64 unsigned comparisons to i32 constants`
- `precompute preserves trapping exact operators it does not fold`
- `precompute folds constant false void ifs away`
- `precompute folds constant true result ifs to the chosen arm`
- `precompute removes dropped pure constants from void bodies`
- `precompute folds immutable global.get uses into constants`
- `precompute validates rewritten functions against full module call targets`
- `precompute keeps the structured branch-exit body valid after folding dead exact prefixes`

Those tests prove that the local contract is not just arithmetic folding. They also lock the current `if`, dead-drop, root-cleanup, full-module-validation, and branch-carrier safety stories.

## 2. Preset-slot proof

[`src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt) proves the local scheduler claim directly:

- `optimize preset replays precompute in both PC slots`
- `shrink preset replays precompute in both PC slots`

Those tests are the honest source for the statement that Starshine replays top-level `precompute` twice today. They now count both full HOT starts and raw `skip-raw` shortcuts so the two slots remain visible even when the raw scalar shortcut handles a slot without lifting.

## 3. Registry proof

[`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) proves the public registry surface:

- `precompute_descriptor()` is registered under the expected name
- the optimize and shrink preset expansions both include the two `precompute` slots

## 4. CLI replay and artifact-retirement proof

[`src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt) is the current artifact-replay proof surface.

Important precompute lanes include:

- `run_cmd_with_adapter validates precompute on generated O4z slot19 predecessor`
- `run_cmd_with_adapter keeps extracted generated O4z slot19 precompute func108 output wasm-tools-valid`
- `run_cmd_with_adapter validates precompute on debug artifact`

Those tests are the strongest local evidence that the old slot-19 family is now retired by writeback guards plus full-module validation, not merely papered over in prose.

### Adjacent HOT-lower proof for the later rooted slot-43 continuation

A later rooted continuation under `.tmp/o4z-post-5d2fd48/current-chain/` surfaced one more live slot-43 witness after the earlier saved slot-19 work was already green. The durable outcome there is the same general lesson but at a narrower lowerer site:

- the remaining live blocker was **not** a new `precompute` fold bug
- the bad rewrite lived in `hot_lower_impl_stackify_wrapped_struct_set_prefixes(...)` in [`src/ir/hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt)
- the missing guard was that doubly nested child exits could still target the carried-prefix block's **own** label even when the source local was not rewritten
- the new regression in [`src/ir/hot_lower_test.mbt`](../../../../../src/ir/hot_lower_test.mbt) locks that exact case:
  - `hot lower keeps wrapped local.set prefixes void when a doubly nested child exit still targets the carried-prefix block without rewriting the source local`
- the fixed rooted slot-43 witness (`func 3867`, extracted as `func 15`) and downstream implemented slots `44`, `45`, `47`, `50`, and `53` now all validate green, as recorded in [`0268`](../../../raw/research/0268-2026-04-23-generated-o4z-precompute-slot43-retired-by-hot-lower-prefix-label-guard.md)

That follow-up matters for honest ownership: the local `precompute` dossier should teach readers that some artifact-backed retirement evidence lives in neighboring HOT-lower safety work, not only in the pass file or cmd replay tests.

## Current semantic boundary versus upstream Binaryen

## What Starshine does implement today

Current Starshine `precompute` implements:

- exact i32/i64 unary and binary scalar folds
- conservative raw stack-level no-candidate, nested nop-only, and scalar-fold shortcuts for safe no-HOT-lift cases, including preserved effectful/trapping dropped tails once raw folding has no remaining safe candidate
- exact integer comparison folding to i32 booleans
- immutable defined-global folding for scalar and `ref.null` payloads
- direct constant-`if` picking
- dead pure-`drop` cleanup
- region/root `nop` and empty-wrapper cleanup
- iterative local fixpoint repetition over those rewrites
- pipeline-level invalid-carrier and writeback-validation hardening

## What Starshine still does **not** implement

Compared with upstream Binaryen `version_129`, the local pass still lacks:

- the plain-vs-`precompute-propagate` public mode split
- `LazyLocalGraph` propagation through locals
- bounded compile-time interpretation via `ConstantExpressionRunner` / `Flow`
- write-preserving child-retention logic for arbitrary local/global-writing children
- partial-`select` upward precompute
- GC identity caching and immutable-GC propagation
- string precompute families
- deterministic-SIMD-vs-relaxed-SIMD handling
- synchronization-sensitive GC atomic get rules
- final Binaryen-style refinalization as part of the pass contract

So the honest short description of current Starshine remains:

- **exact scalar HOT folding plus structural cleanup and artifact-driven writeback safety work**, including neighboring HOT-lower carried-prefix label guards that retired the later rooted slot-43 continuation family

not:

- a full port of Binaryen plain `precompute`, and definitely not
- a full port of the `precompute` + `precompute-propagate` family

## Practical follow-along path

If you want to read the local implementation in code order, use this path:

1. [`src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt)
   - descriptor, summary, exact-constant helpers, fold helpers, region cleanup, and `precompute_run(...)`
2. [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
   - dispatch plus invalid-lower/writeback guard rails
3. [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
   - registry entry plus the two top-level preset slots
4. [`src/passes/precompute_test.mbt`](../../../../../src/passes/precompute_test.mbt)
   - pass-local rewrite and validation regressions
5. [`src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
   - preset-slot proof
6. [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
   - public registry and preset-expansion proof
7. [`src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
   - generated-artifact and debug-artifact CLI replay lanes

## Bottom line

The local page no longer needs to be taught as a vague “current Starshine gap.”
It is now more useful as an exact code map:

- what file owns which behavior,
- where the artifact hardening lives,
- which tests lock the current contract,
- and which major Binaryen surfaces are still missing.

That keeps the Starshine side readable for beginners while still giving advanced readers a concrete path from the living wiki into the MoonBit implementation.