---
kind: concept
status: supported
last_reviewed: 2026-10-30
sources:
  - ./index.md
  - ../../../../../src/passes/heap_store_optimization.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/heap_store_optimization_test.mbt
  - ../../../../../src/passes/heap_store_swapped_ref_order_perf_wbtest.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-port-readiness-and-validation.md
  - ./swap-safety-and-control-flow.md
  - ./wat-shapes.md
---

# Current Starshine `heap-store-optimization` strategy

## October 30, 2026: bounded shared-region discovery

`hso_process_region` calls `hso_process_node_regions` for each control-bearing
root; the latter follows value-child edges until it encounters a region owner,
then re-enters `hso_process_region`. HOT value sharing therefore makes this walk
enumerate paths rather than unique regions. Repeated diamonds multiply entry
counts at each level, even when there are no constructor/store candidates.

The Slipstream host-imports qualification at branch `feat/moonbit-host-imports`
(source `94686f99425e8b8d9aeea8ad14b55e3fe8ccb6a2`,
`docs/host-imports/capacity-evidence/diagnostics/checked-model.json`, read with
the accompanying graph checker and native reference records) found 685 unique
regions and 10,879 nodes in function 513, but modeled 169,958,025,743,247 region
entries. Its model matched all 827,150 observed prefix entries; there were zero
store candidates and no root changes. These are diagnostic counts, not timings
or a completed optimization. The native reference reproduced the same phase.

Before any mutation, an iterative postorder preflight memoizes expanded
control-owner counts over the stored child graph. Parallel scalar arrays hold
visit state and saturated costs; each stored node/edge is examined a bounded
number of times. If the estimated expansion exceeds eight times the initial
node count (saturated before multiplication), the pass returns unchanged for
that function. The estimate includes all stored child paths and can be more
conservative than the discovery walk. This also protects secondary subtree
queries inside region processing; bounding recursive discovery alone does not
protect those queries.

For admitted functions, discovery additionally consumes the same per-invocation
budget. Each live node descent consumes one unit, including non-region value
wrappers. Exhaustion stops further nested discovery while every entered region
finishes its ordinary safety-checked scan. This protects discovery if rewrites
introduce additional sharing after the preflight. It bounds successful recursive
entries linearly and their child/root scanning polynomially in stored IR size;
it does not claim every predicate or rewrite in the entire pass is linear.

Declining a high-expansion function is sound because it preserves the exact
original function before any mutation. No store, evaluation, trap, effect,
local value or catch/branch target changes. The cost is all missed HSO folds and allocation movements in
that function; code size or execution speed can therefore be worse than an
unbounded completed optimization. Admission depends on sharing/expansion, not a
hard function-size cutoff. Ordinary trees remain eligible, including large
ones. Admitted functions retain all existing catch-depth, owner, suffix-use,
effect and local-order checks. A node-only memo of **rewrite results** would not
be a sound general replacement because legality depends on those contexts and
mutation; the preflight memoizes a pure size estimate instead.

The whitebox regression builds a 13-node repeated diamond (8,191 expanded
control owners), checks the exact 8,190/8,191 admission boundary, requires the
public pass to decline it unchanged, and checks a 64-entry discovery budget
without changing IR/revision. A second test requires current-region constructor
folding to the constant 42 and validation with a zero remaining descent budget.
The CLI dispatcher regression folds a store after twelve nested two-result
blocks and validates encoded output. Existing nested-block pipeline tests retain
ordinary optimization coverage. See
[`heap_store_optimization_wbtest.mbt`](../../../../../src/passes/heap_store_optimization_wbtest.mbt)
and [`cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt).

## October 30, 2026: validation and qualification limits

`moon info` and `moon fmt` completed; final changed MoonBit files were also
formatted directly with `moonfmt`. Public `.mbti` review found no API change.
All **672 HSO/dispatcher tests pass**, including the preflight boundary,
exhausted-budget constructor fold, absent-else cases, and encoded CLI fixture.
The [dedicated 10,000-case v133 comparison](fuzzing.md#october-30-bounded-discovery-regression-renewal)
has zero residual or validation/property/generator/command failures.

Plain `moon test` could not launch the passes whitebox driver on Linux because
Moon's single JSON argument exceeds the `execve` per-argument limit (error 7).
After `moon test --build-only`, the same generated drivers were replayed in 54
bounded file batches, excluding benchmark tests and every `#skip` form, and
requiring exactly one result record per selected test and recording every failure. **15,622 tests ran:
15,595 passed and 27 failed.** Every failure was independently replayed against
`b28144a7c`'s original HSO implementation/test file: all 27 still fail. The final
failure identities exactly match that baseline; there are no new failures.
The full suite is therefore **not green**, and the existing hold/backlog remains
open outside Joshua's exception for this fix.

| Baseline source under `src/` | Failing test indices |
| --- | --- |
| `cmd/fuzz_harness_wbtest.mbt` | 28 |
| `fuzz/main_wbtest.mbt` | 33, 97, 98 |
| `fuzz/metamorphic_wbtest.mbt` | 241 |
| `passes/coalesce_reader_row_wbtest.mbt` | 1, 2 |
| `passes/dae2_cleanup_context_wbtest.mbt` | 3, 4, 5 |
| `passes/dae_type_update_index_wbtest.mbt` | 5, 6, 7, 8, 9, 10 |
| `validate/gen_valid_constraint_wbtest.mbt` | 1, 7 |
| `validate/gen_valid_wbtest.mbt` | 10, 12, 24, 88, 92, 112, 119, 135 |
| `validate/validate.mbt` | 31 |

The final source was built with `moon build --target native --release src/cmd`
and `moon build --target wasm-gc --release src/cmd`. The real CLI input is
**5,535,619 bytes**, SHA-256
`c700196463875b9fc93e0297d55f3880e983fe8cbededd4645c4f7f4a10732c6`.
The native optimizer (SHA-256 `6360c6f7aeded7e7778fff84474823c60bf9bf409da163b1baa6323b8ec6eaee`) ran:

```sh
_build/native/release/build/cmd/cmd.exe --optimize \
  --out /tmp/hso-default-self.wasm \
  _build/wasm-gc/release/build/cmd/cmd.wasm
wasm-tools validate --features all /tmp/hso-default-self.wasm
```

This completed with exit 0 in **1.366 seconds**, producing
**5,160,900 bytes** (SHA-256 `b48ef4ceafdbdd45fb3ade2bb9567aa2d5e331f8826b75c860ee4afe8b4727e5`).
`wasm-tools 1.262.0` validation passed. The optimized CLI also printed `v0.4.0`
under `moonrun`, then optimized the encoded regression fixture and produced
another independently valid module. The native runner used a 64 MiB stack;
the wall time is a completion observation under concurrent repository work,
not a calibrated performance comparison.

The more aggressive `--optimize -O4z` invocation on that same final input is
**not qualified**: it exceeded a 60.0-second limit without output.
A previous real CLI build also produced no output during a 313.97-second probe.
A separate bounded trace on that earlier build last logged
`optimize-instructions` function 4434; this does not isolate the remaining
cause or prove completion of every HSO slot in the aggressive pipeline.
The successful end-to-end result above is specifically the default preset.
The original Slipstream qualification input had already been removed by its
owner's cleanup, so no byte-identical rerun of that older input is claimed.
All generated builds, reports and temporary inputs were removed after filing
these results, as requested; source/tests and this durable record remain.

## September 25, 2026: swapped-root reference order guard

The swapped-readonly-root guard now checks whether the reference node precedes a candidate root before asking if that root's subtree can be reordered. Roots already before the reference cannot violate this specific local-read order, so the subtree walk was wasted. Roots after the reference still receive the same reorderability and local-touch checks.

The native-release helper benchmark in `src/passes/heap_store_swapped_ref_order_perf_wbtest.mbt` measured 64 preceding roots at **5.44 µs to 91.35 ns** and 128 roots at **10.79 µs to 173.66 ns**. A focused test checks that a later root reading the same local is still rejected. Full-pass impact remains unmeasured.

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

## Local dependencies during constructor movement

Descriptor operand effect masks omit local reads, so masks alone cannot prove
that a constructor can cross another root. Both movement checks now compare
local writes against every read/write in the other subtree. This preserves
constructor operand values even when the destination local is unrelated to the
local that an operand reads. Read-only local pairs remain reorderable.

The reduced Dewdrop case stores 42 in a local, constructs a one-field struct from
that local, then replaces the local with 7. The old pass moved the overwrite
before construction and returned 7; the output must return 42. The native
HeapStoreOptimization suite passes all 433 checks, including the new ordering
regression and the existing positive constructor-folding tests.

## Exact local code map

Use this page together with the current source bridge in [research note 0448](./index.md) and the owner/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).
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
  - [`src/passes/heap_store_optimization_test.mbt:1265-7335`](../../../../../src/passes/heap_store_optimization_test.mbt) covers reduced constructor/store, old-field side-effect preservation, later-field call barriers, descriptor immutable/mutable global barriers, descriptor `local.get`, block-wrapped immutable global operands, descriptor `if` operands, descriptor block self-branch operands, branchless descriptor loops plus self-branching loop negatives, readonly-prefix, swap including memory/table growth and size operands, block/if/loop-wrapped blockers, nested mixed-wrapper blockers, block/if/loop-wrapped bulk-fill, copy, passive init/drop, growth/passive init/drop barriers, nested mixed-wrapper growth/passive init/drop barriers, nested mixed-wrapper growth/bulk barriers, deeper growth/bulk barriers, and branch-containing wrapper global-write swap positives for memory-growing, table-size, and table-growing constructors, branch-containing constructor-local-set wrapper positives, branch-containing same-effect-family bulk-fill, copy, and passive init/drop no-fold barriers, trapping-load and call-valued negatives, direct and wrapped constructor-ping-pong boundaries, branch, raw-prefix, and wrapper-cleanup regressions
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

The 2026-06-20 release-oracle refresh found that Binaryen `version_130` changed swap, later-field, descriptor, and shallow-constructor movement barriers from broad symmetric `invalidates(...)` checks to directional `orderedBefore(...)` checks. Follow-ups have fixed concrete gaps: plain `struct.new` / `struct.new_default` no longer carry extra wrapper effects that overblock moved-call folds, later-field trapping operands no longer overblock moved local-only values, immutable descriptor `global.get` operands no longer overblock moved calls while mutable descriptor globals still block, descriptor `local.get`, block-wrapped immutable descriptor globals, pure descriptor-`if` operands, descriptor block self-branch operands, and branchless descriptor-loop operands and descriptor loops that branch to an outer result block no longer overblock moved calls, constructor operand effects now stop `trySwap(...)` from moving a `global.get`-initialized constructor past a later same-global mutable `global.set`, descriptor later-field global barriers distinguish unrelated global reads/writes from same-global read/write conflicts, and swap-side constructor operand effects now treat immutable descriptor globals and mutable constructor `global.get $a` operands as reorderable across unrelated mutable `global.set $b` writes when `$a != $b`. A later coverage slice added explicit tests for `trySwap(...)` with non-trapping `memory.size` constructor operands crossing unrelated `global.set`, trapping `i32.load` constructor operands not crossing unrelated `global.set`, and an intervening constructor local-set that does not let the first constructor fold through the ping-pong shape. Follow-up swap coverage now includes table-size, table-grow, memory-grow, call-valued negatives, final-root no-swap behavior, block-wrapped global writes, if-wrapped table-size/memory-grow/table-grow global-write shapes, branchless loop-wrapped table-size, memory-grow, and table-grow global-write shapes, the constructor-ping-pong distinction where direct constructor local-set roots block but block/if/loop-wrapped unrelated constructor assignments still fold, nested mixed `block` / `if` / branchless `loop` wrappers around unrelated global writes, same-kind growth/store no-swap boundaries for `memory.grow` crossing `i32.store`, `table.grow` crossing `table.set`, `table.size` crossing `table.set`, `memory.size` / `memory.grow` crossing `memory.fill` / `memory.copy`, `memory.size` / `memory.grow` crossing `memory.init` / `data.drop`, `table.size` / `table.grow` crossing `table.init` / `elem.drop`, and cross-index `memory.size` / `table.size` before bulk fills, same-index copies on different memories/tables, mixed-endpoint copies, and block/if/loop-wrapped same-effect-family bulk-fill, copy, passive init/drop, and growth/passive init/drop barriers, mutable-global read/write granularity for unrelated globals, the variant where the unrelated `global.set` value also reads the constructor-read global, and branch-containing unrelated-global-write wrappers for memory-growing, table-size, and table-growing constructor operands, plus branch-containing constructor-local-set wrappers that still fold while direct constructor ping-pong remains blocked, branch-containing same-effect-family `memory.fill` / `table.fill`, `memory.copy` / `table.copy`, and passive init/drop wrappers that still block folds for memory-size and table-size constructors, and the side-effecting memory-grow/table-grow counterparts for branch-containing bulk-memory/table and passive data/element roots. Cross-family ordinary-store positives now cover constructor `memory.size` crossing `table.set` and constructor `table.size` crossing `i32.store`, matching Binaryen's fold behavior. Broader arbitrary descriptor operand expressions, remaining later-field barrier shapes, additional wrapper variants, and broader `trySwap(...)` directionality must still be tested before the pass can be closed; the current block/if/loop copy-root coverage from `0831`, passive init/drop coverage from `0832`, growth/passive init/drop coverage from `0833`, branch-containing growth boundary coverage from `0843`, and cross-family ordinary-store coverage from `0844` are matched Binaryen families, not documented Starshine wins or accepted non-goals.

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

## Backlog

Consult [`agent-todo.md`](../../../../../agent-todo.md) for active release work. This page maps the implementation and preserves earlier audit evidence.

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
