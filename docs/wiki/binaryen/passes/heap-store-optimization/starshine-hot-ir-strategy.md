---
kind: concept
status: supported
last_reviewed: 2026-06-20
sources:
  - ../../../raw/research/0839-2026-06-20-heap-store-optimization-branch-wrapper-constructor-pingpong.md
  - ../../../raw/research/0838-2026-06-20-heap-store-optimization-branch-wrapper-table-global-swap.md
  - ../../../raw/research/0837-2026-06-20-heap-store-optimization-branch-wrapper-global-swap.md
  - ../../../raw/research/0836-2026-06-20-heap-store-optimization-deep-nested-growth-bulk-boundaries.md
  - ../../../raw/research/0835-2026-06-20-heap-store-optimization-nested-wrapped-growth-bulk-boundaries.md
  - ../../../raw/research/0834-2026-06-20-heap-store-optimization-nested-wrapped-growth-passive-boundaries.md
  - ../../../raw/research/0833-2026-06-20-heap-store-optimization-wrapped-growth-passive-boundaries.md
  - ../../../raw/research/0832-2026-06-20-heap-store-optimization-wrapped-passive-boundaries.md
  - ../../../raw/research/0831-2026-06-20-heap-store-optimization-wrapped-copy-boundaries.md
  - ../../../raw/research/0830-2026-06-20-heap-store-optimization-loop-wrapped-bulk-fill-boundaries.md
  - ../../../raw/research/0829-2026-06-20-heap-store-optimization-wrapped-bulk-fill-boundaries.md
  - ../../../raw/research/0828-2026-06-20-heap-store-optimization-mixed-index-copy-boundaries.md
  - ../../../raw/research/0827-2026-06-20-heap-store-optimization-multi-index-copy-boundaries.md
  - ../../../raw/research/0826-2026-06-20-heap-store-optimization-multi-index-bulk-boundaries.md
  - ../../../raw/research/0825-2026-06-20-heap-store-optimization-table-grow-bulk-boundaries.md
  - ../../../raw/research/0824-2026-06-20-heap-store-optimization-memory-grow-bulk-boundaries.md
  - ../../../raw/research/0823-2026-06-20-heap-store-optimization-memory-grow-data-boundaries.md
  - ../../../raw/research/0822-2026-06-20-heap-store-optimization-table-grow-elem-boundaries.md
  - ../../../raw/research/0821-2026-06-20-heap-store-optimization-table-size-elem-boundaries.md
  - ../../../raw/research/0820-2026-06-20-heap-store-optimization-memory-size-data-segment-boundaries.md
  - ../../../raw/research/0819-2026-06-20-heap-store-optimization-memory-size-memory-bulk-boundaries.md
  - ../../../raw/research/0818-2026-06-20-heap-store-optimization-table-size-table-set-swap.md
  - ../../../raw/research/0817-2026-06-20-heap-store-optimization-global-set-value-read-swap.md
  - ../../../raw/research/0816-2026-06-20-heap-store-optimization-unrelated-global-swap.md
  - ../../../raw/research/0815-2026-06-20-heap-store-optimization-growth-store-swap-boundaries.md
  - ../../../raw/research/0814-2026-06-20-heap-store-optimization-nested-wrapper-swap.md
  - ../../../raw/research/0813-2026-06-20-heap-store-optimization-wrapped-constructor-pingpong.md
  - ../../../raw/research/0812-2026-06-20-heap-store-optimization-loop-wrapped-table-grow-swap.md
  - ../../../raw/research/0811-2026-06-20-heap-store-optimization-loop-wrapped-memory-grow-swap.md
  - ../../../raw/research/0810-2026-06-20-heap-store-optimization-loop-wrapped-table-size-swap.md
  - ../../../raw/research/0808-2026-06-20-heap-store-optimization-if-wrapped-table-grow-swap.md
  - ../../../raw/research/0809-2026-06-20-heap-store-optimization-if-wrapped-table-size-swap.md
  - ../../../raw/research/0807-2026-06-20-heap-store-optimization-if-wrapped-memory-grow-swap.md
  - ../../../raw/research/0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../../raw/research/0530-2026-05-06-heap-store-optimization-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md
  - ../../../raw/research/0448-2026-05-05-heap-store-optimization-current-main-recheck.md
  - ../../../raw/research/0133-2026-04-20-heap-store-optimization-binaryen-research.md
  - ../../../raw/research/0246-2026-04-22-heap-store-optimization-primary-sources-and-code-map-followup.md
  - ../../../../../src/passes/heap_store_optimization.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/heap_store_optimization_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../raw/research/0530-2026-05-06-heap-store-optimization-direct-revalidation.md
  - ./swap-safety-and-control-flow.md
  - ./wat-shapes.md
---

# Current Starshine `heap-store-optimization` strategy

This page is the local “what is actually implemented today?” companion to the upstream Binaryen strategy page.
For the compact validation and replay surface, including the 2026-05-06 refreshed direct `pass-fuzz-compare` lane, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md). The 2026-06-20 `version_130` refresh supersedes the older `version_129` oracle wording and flags directional `orderedBefore(...)` movement checks as active audit work.

## Short version

Current Starshine `src/passes/heap_store_optimization.mbt` follows the same **core idea** as Binaryen `version_130`:

- fold a `struct.set` back into a nearby fresh constructor when local visibility and effect ordering stay safe.

But the implementation shape is not a literal source port.

Binaryen uses:

- a CFG walker over AST basic blocks
- `EffectAnalyzer`
- `ShallowEffectAnalyzer`
- `LazyLocalGraph`

Current Starshine uses:

- HOT-region traversal and rewrite helpers
- per-node effect masks from the HOT analysis layer
- custom subtree predicates for trapless-readonly and reorderable shapes
- custom control-flow / owner-label reasoning
- extra cleanup to keep HOT lowering and writeback valid after the rewrite

So the local pass is best understood as:

- a HOT-IR generalization of the same narrow constructor/store-folding contract

not:

- a direct line-by-line port of Binaryen `HeapStoreOptimization.cpp`

## Exact local code map

Use this page together with the current source bridge in [`../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md) and the owner/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).
The fastest read-along path through the current MoonBit implementation is:

- registry descriptor and one-line public summary
  - [`src/passes/heap_store_optimization.mbt:2-24`](../../../../../src/passes/heap_store_optimization.mbt)
- active registry and preset placement
  - [`src/passes/optimize.mbt:194-196`](../../../../../src/passes/optimize.mbt) registers the active hot pass
  - [`src/passes/optimize.mbt:282-293`](../../../../../src/passes/optimize.mbt) place it in `optimize`
  - [`src/passes/optimize.mbt:294-305`](../../../../../src/passes/optimize.mbt) place it in `shrink`
- pass-manager integration and raw fast-skip plumbing
  - [`src/passes/pass_manager.mbt:7264-7274`](../../../../../src/passes/pass_manager.mbt) owns `run_hot_pipeline_raw_heap_store_optimization(...)`
  - [`src/passes/pass_manager.mbt:8097-8099`](../../../../../src/passes/pass_manager.mbt) dispatches the main hot-pass case for `"heap-store-optimization"`
- local proof helpers in `src/passes/heap_store_optimization.mbt`
  - [`src/passes/heap_store_optimization.mbt:312-354`](../../../../../src/passes/heap_store_optimization.mbt) covers skip-local-set / control-flow predicates
  - [`src/passes/heap_store_optimization.mbt:560-631`](../../../../../src/passes/heap_store_optimization.mbt) covers trapless readonly and reorderable subtree predicates
  - [`src/passes/heap_store_optimization.mbt:772-944`](../../../../../src/passes/heap_store_optimization.mbt) covers descriptor operand effects, descriptor-aware block/if wrapper recursion, constructor operand effects, and root-swap legality
  - [`src/passes/heap_store_optimization.mbt:1011-1110`](../../../../../src/passes/heap_store_optimization.mbt) covers the supported `struct.new*` / descriptor / default constructor family and shallow constructor wrapper effects
- local rewrite helpers in `src/passes/heap_store_optimization.mbt`
  - [`src/passes/heap_store_optimization.mbt:1296-1468`](../../../../../src/passes/heap_store_optimization.mbt) handles HOT wrapper flattening and unreachable-tail repair
  - [`src/passes/heap_store_optimization.mbt:1653-1775`](../../../../../src/passes/heap_store_optimization.mbt) owns the shared fold-into-constructor proof and rewrite
  - [`src/passes/heap_store_optimization.mbt:1777-1827`](../../../../../src/passes/heap_store_optimization.mbt) owns the tee-wrapped fold rewrite
  - [`src/passes/heap_store_optimization.mbt:2028-2218`](../../../../../src/passes/heap_store_optimization.mbt) recursively processes HOT regions, later-set chains, swaps, and root replacement
  - [`src/passes/heap_store_optimization.mbt:2220-2241`](../../../../../src/passes/heap_store_optimization.mbt) requires effect summaries, marks mutation, and returns pass results
- focused local evidence surfaces
  - [`src/passes/heap_store_optimization_test.mbt:1265-7179`](../../../../../src/passes/heap_store_optimization_test.mbt) covers reduced constructor/store, old-field side-effect preservation, later-field call barriers, descriptor immutable/mutable global barriers, descriptor `local.get`, block-wrapped immutable global operands, descriptor `if` operands, descriptor block self-branch operands, branchless descriptor loops plus self-branching loop negatives, readonly-prefix, swap including memory/table growth and size operands, block/if/loop-wrapped blockers, nested mixed-wrapper blockers, block/if/loop-wrapped bulk-fill, copy, passive init/drop, growth/passive init/drop barriers, nested mixed-wrapper growth/passive init/drop barriers, nested mixed-wrapper growth/bulk barriers, deeper growth/bulk barriers, and branch-containing wrapper global-write swap positives for memory-growing, table-size, and table-growing constructors, branch-containing constructor-local-set wrapper positives, trapping-load and call-valued negatives, direct and wrapped constructor-ping-pong boundaries, branch, raw-prefix, and wrapper-cleanup regressions
  - [`src/passes/perf_test.mbt:6241-6320`](../../../../../src/passes/perf_test.mbt) covers raw fast-skip trace/perf behavior
  - [`src/cmd/cmd_wbtest.mbt:2514-3490`](../../../../../src/cmd/cmd_wbtest.mbt) and [`src/cmd/cmd_wbtest.mbt:6600-6634`](../../../../../src/cmd/cmd_wbtest.mbt) cover focused `--heap-store-optimization` CLI replay and debug-artifact lanes

This exact code map is the main practical difference between the older page and the refreshed one: readers can now go directly from the living strategy text to concrete line ranges.

## What Starshine already models well

## 1. The same core fold family

The in-tree pass still revolves around the same central optimization:

- `struct.set` into a fresh struct becomes an updated `struct.new`

It supports the two canonical entry shapes:

- tee-wrapped immediate form
- later `local.set` / `local.get` chain form

That is the real heart of the pass, and current Starshine models it directly.

## 2. Repeated subsequent-set chains

Like Binaryen, the local pass can absorb multiple later `struct.set`s into the same fresh constructor while the proof remains valid.

That is visible in tests such as:

- `folds consecutive struct.set roots on the same local`
- `reorders unrelated local.get field values within struct.new`

## 3. Default and descriptor constructor forms

Current Starshine explicitly supports more constructor spellings in-tree than the upstream public examples emphasize, including:

- `struct.new_default`
- `struct.new_desc`
- `struct.new_default_desc`

The pass has dedicated module-context helpers for:

- discovering struct fields
- checking whether default materialization is valid
- building explicit default child operands

That is a real local implementation difference worth keeping explicit.

## 4. HOT-region-safe prefix peeling and wrapper cleanup

The current local pass has a lot of machinery that exists because HOT IR and later writeback need more shape repair than upstream AST Binaryen does.

Examples include helpers for:

- trimming unreachable tails in moved values
- flattening block wrappers after peeling prefixes
- retargeting labels when flattening nested block wrappers
- preserving old field side effects with rewritten block/value shells, including the Binaryen lit family where a moved call folds into a plain `struct.new` while the old field call is retained under a dropped sequence

This is why the local test suite contains many shapes that sound more structural than the upstream dedicated test names, such as:

- `flattens swapped block roots before the folded local.set`
- `flattens nested if-tail wrappers inside folded values`
- `keeps the rewritten local.set valid after nop cleanup`

## 5. Wider reduced test coverage than the upstream dedicated lit file

The current repo test suite covers many source-local families beyond the upstream dedicated HSO lit test, including:

- memory/table/global read-only blockers
- nested block / if / loop wrappers
- raw-decoded ref-prefix shapes
- named-label preservation and raw-skip cases
- artifact replay via focused `src/cmd/cmd_wbtest.mbt` `--heap-store-optimization` lanes
- perf fast-skip behavior when there are no candidates

That does **not** automatically mean Starshine is fully upstream-parity complete.
But it does mean the local pass has already accumulated a lot of HOT-specific survival work.

## Current audit warning

The 2026-06-20 release-oracle refresh found that Binaryen `version_130` changed swap, later-field, descriptor, and shallow-constructor movement barriers from broad symmetric `invalidates(...)` checks to directional `orderedBefore(...)` checks. Follow-ups have fixed concrete gaps: plain `struct.new` / `struct.new_default` no longer carry extra wrapper effects that overblock moved-call folds, later-field trapping operands no longer overblock moved local-only values, immutable descriptor `global.get` operands no longer overblock moved calls while mutable descriptor globals still block, descriptor `local.get`, block-wrapped immutable descriptor globals, pure descriptor-`if` operands, descriptor block self-branch operands, and branchless descriptor-loop operands and descriptor loops that branch to an outer result block no longer overblock moved calls, constructor operand effects now stop `trySwap(...)` from moving a `global.get`-initialized constructor past a later same-global mutable `global.set`, and swap-side constructor operand effects now treat immutable descriptor globals and mutable constructor `global.get $a` operands as reorderable across unrelated mutable `global.set $b` writes when `$a != $b`. A later coverage slice added explicit tests for `trySwap(...)` with non-trapping `memory.size` constructor operands crossing unrelated `global.set`, trapping `i32.load` constructor operands not crossing unrelated `global.set`, and an intervening constructor local-set that does not let the first constructor fold through the ping-pong shape. Follow-up swap coverage now includes table-size, table-grow, memory-grow, call-valued negatives, final-root no-swap behavior, block-wrapped global writes, if-wrapped table-size/memory-grow/table-grow global-write shapes, branchless loop-wrapped table-size, memory-grow, and table-grow global-write shapes, the constructor-ping-pong distinction where direct constructor local-set roots block but block/if/loop-wrapped unrelated constructor assignments still fold, nested mixed `block` / `if` / branchless `loop` wrappers around unrelated global writes, same-kind growth/store no-swap boundaries for `memory.grow` crossing `i32.store`, `table.grow` crossing `table.set`, `table.size` crossing `table.set`, `memory.size` / `memory.grow` crossing `memory.fill` / `memory.copy`, `memory.size` / `memory.grow` crossing `memory.init` / `data.drop`, `table.size` / `table.grow` crossing `table.init` / `elem.drop`, and cross-index `memory.size` / `table.size` before bulk fills, same-index copies on different memories/tables, mixed-endpoint copies, and block/if/loop-wrapped same-effect-family bulk-fill, copy, passive init/drop, and growth/passive init/drop barriers, mutable-global read/write granularity for unrelated globals, the variant where the unrelated `global.set` value also reads the constructor-read global, and branch-containing unrelated-global-write wrappers for memory-growing, table-size, and table-growing constructor operands, plus branch-containing constructor-local-set wrappers that still fold while direct constructor ping-pong remains blocked. Broader arbitrary descriptor operand expressions, remaining later-field barrier shapes, additional wrapper variants, and broader `trySwap(...)` directionality must still be tested before the pass can be closed; the current block/if/loop copy-root coverage from `0831`, passive init/drop coverage from `0832`, and growth/passive init/drop coverage from `0833` are matched Binaryen no-fold families, not documented Starshine wins or accepted non-goals.

## Important structural differences from Binaryen

## 1. Binaryen uses CFG basic blocks; Starshine walks HOT regions

Upstream Binaryen records only:

- `StructSet`
- `Block`

per CFG basic block.

Current Starshine recursively processes HOT regions for:

- `block`
- `loop`
- `if`
- `try`
- `try_table`

That means the local implementation can see and transform some wrapped shapes in a more region-native way, but it also means the proof structure is not the same as upstream.

## 2. Binaryen uses `LazyLocalGraph` only on control-flow values; Starshine uses custom subtree analysis

Upstream Binaryen's hardest safety check is:

- can moving the `local.set` forward expose bad `local.get`s?

It answers that with `LazyLocalGraph::canMoveSet(...)`.

Current Starshine answers the same *kind* of question with custom HOT helpers such as:

- subtree/region touches-local predicates
- branch-owner escape checks
- subtree-may-skip-local-set predicates
- reorderability predicates over HOT effect masks

The exact local code locations worth reading are:

- [`src/passes/heap_store_optimization.mbt:312-354`](../../../../../src/passes/heap_store_optimization.mbt) for `hso_subtree_may_skip_local_set(...)` and related skip checks
- [`src/passes/heap_store_optimization.mbt:560-631`](../../../../../src/passes/heap_store_optimization.mbt) for `hso_subtree_is_trapless_readonly(...)` and `hso_subtree_is_trapless_reorderable(...)`
- [`src/passes/heap_store_optimization.mbt:761-792`](../../../../../src/passes/heap_store_optimization.mbt) for `hso_root_can_swap_before_local_struct_new(...)`

So the local proof is aiming at the same semantic barrier, but it is not using the same exact helper stack.

## 3. Starshine currently cares a lot about writeback-valid shapes

Several local helpers exist mainly to avoid generating invalid or awkward lowered output after a successful fold, for example:

- trimming unreachable tails in value wrappers
- flattening single-root block wrappers
- retargeting labels when flattening nested block roots

The exact local code locations worth reading are:

- [`src/passes/heap_store_optimization.mbt:1296-1468`](../../../../../src/passes/heap_store_optimization.mbt) for wrapper flattening and unreachable-tail repair
- [`src/passes/heap_store_optimization.mbt:1653-1775`](../../../../../src/passes/heap_store_optimization.mbt) for side-effect-preserving constructor replacement
- [`src/passes/heap_store_optimization.mbt:2028-2218`](../../../../../src/passes/heap_store_optimization.mbt) for region-root replacement after folds and swaps

That is a local HOT/writeback reality, not a direct upstream Binaryen concern.

## 4. The local pass is still narrow in *goal*, even when broad in *shape handling*

Even though Starshine handles more wrapper families and constructor spellings, the pass is still not claiming broader semantic scope than Binaryen.

It is still fundamentally about:

- folding `struct.set` into nearby `struct.new`

It is **not** currently claiming:

- generic heap dead-store elimination
- load forwarding
- array-store folding as the main contract

That narrow-goal correction must stay explicit locally too.

## Current honest parity state

## Top-level generated-artifact audit

The saved generated-artifact `-O4z` audit recorded exact equality for the two top-level HSO slots:

- slot `17`
- slot `45`

with:

- `wasmEqual = true`
- `normalizedWatEqual = true`
- `normalizedWatTextEqual = true`

But the same summary also says:

- `starshinePassSkippedRaw = true`

for both slots.

So the honest reading is:

- the current fast-skip path preserved exact artifact behavior there
- this is good regression evidence, but not proof that every upstream rewrite family is already exercised on that artifact

## Native artifact replay coverage exists in-tree

`src/cmd/cmd_wbtest.mbt` contains focused native regressions for many concrete `--heap-store-optimization` shapes plus the checked large-artifact replay lane.
Representative entry points include the `hso.wasm`, `hso-tee.wasm`, `hso-branch-fold.wasm`, `hso-swap.wasm`, and debug-artifact cases.

That is important because it proves the current implementation can at least run and validate cleanly on both reduced fixtures and the checked-in large artifact.

## Dedicated HSO backlog slice

`agent-todo.md` now tracks `[O4Z-AUDIT-HSO]` as an active v0.1.0 release-gating audit.
That slice is the execution surface for the remaining Binaryen-behavior parity work, including source-backed movement families, O4z slot/neighborhood evidence, performance/raw fast-skip evidence, and final closeout.

This strategy page remains the living implementation map, but backlog state should be read from `[O4Z-AUDIT-HSO]` rather than inferred from older indirect cleanup-prefix references.

## Fast-skip behavior is part of the local strategy

`src/passes/perf_test.mbt` has explicit tests showing the current implementation can skip raw lifting when:

- a function has no HSO candidates at all
- a struct allocation cannot feed a later `struct.set`

That matters on large artifacts.

It means the local implementation strategy is not only about the rewrite itself.
It is also about making “no candidate here” cheap.

## What a future local refactor must preserve

If Starshine rewrites this pass again, keep these durable local lessons:

- preserve the narrow pass goal: fresh-struct `struct.set` folding, not generic heap DSE
- preserve the fast-skip path when no candidates exist
- keep target-local safety, effect ordering, and control-flow skip reasoning explicit
- keep default and descriptor constructor handling honest
- keep writeback-valid wrapper cleanup as part of the implementation, not as an afterthought
- keep generated-artifact equality evidence labeled honestly when a slot succeeded by fast-skip instead of by exercising the full rewrite surface

## Best current mental model

Upstream Binaryen tells us **what the pass means**.
Current Starshine tells us **what a HOT-IR implementation needs in order to survive real writeback and artifact replay**.

Both matter.

But when those two stories disagree, treat Binaryen `version_129` as the semantic oracle and treat the local file as the current implementation strategy that still needs to keep proving itself against that oracle.
