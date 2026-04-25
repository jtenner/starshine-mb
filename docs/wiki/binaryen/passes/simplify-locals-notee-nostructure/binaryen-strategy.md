---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md
  - ../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./variant-surface.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../flatten/index.md
  - ../local-cse/index.md
  - ../simplify-locals-nostructure/index.md
---

# Binaryen `simplify-locals-notee-nostructure` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- Use the immutable raw source manifest in [`../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md) for provenance, current-main spot-check scope, and the exact reviewed source/test URL set.
- The core implementation is the shared `src/passes/SimplifyLocals.cpp` template.
- Scheduler placement comes from `src/passes/pass.cpp` and the after-inlining helper in `src/passes/opt-utils.h`.
- The key helper contracts come from:
  - `src/ir/local-utils.h`
  - `src/ir/effects.h`
  - `src/ir/equivalent_sets.h`
  - `src/ir/linear-execution.h`
  - `src/ir/properties.h`
  - `src/ir/branch-utils.h`
- The shipped behavior examples come from the dedicated `simplify-locals-notee-nostructure` test and the sibling simplify-locals variant tests under `test/passes/`.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.txt>

## High-level intent

Binaryen uses `simplify-locals-notee-nostructure` as a **small-but-real** cleanup pass in the aggressive `-O4` neighborhood.

That sentence is true but incomplete.

The actual implementation is the shared simplify-locals engine with two capabilities turned off:

- no tee creation
- no structure-building rewrites

The pass is **not**:

- the full late `simplify-locals` pass
- the same as `simplify-locals-nostructure`
- the same as `simplify-locals-nonesting`
- a guarantee that the IR stays fully flat after `flatten`
- just a dead-set remover
- a whole-function CFG locals optimizer

Instead, the real `version_129` contract is:

- keep only the direct single-use sinking family from the main sink loop
- keep conservative effect-based invalidation
- keep nesting into already-existing use positions enabled
- disable block / `if` / loop return creation
- disable multi-use tee creation
- still run late equivalent-`get` canonicalization
- still run final dead-set cleanup

## Variant identity is the first important fact

The public constructor is:

- `createSimplifyLocalsNoTeeNoStructurePass() -> SimplifyLocals<false, false>()`

That means:

- `allowTee = false`
- `allowStructure = false`
- `allowNesting = true`

Those three facts are more informative than the CLI name by itself.

## The pass in one table

| Phase | What Binaryen does in this variant | Why it exists |
| --- | --- | --- |
| Variant gate | Instantiate `SimplifyLocals<false, false, true>` | Remove easy local carriers without adding tees or structure |
| Count gets | Use `LocalGetCounter` before the fixpoint | Distinguish direct one-use sinks from preserved multi-use locals |
| First-cycle main scan | Sink only easy single-use locals | Grab common flatten-produced temp patterns cheaply |
| Later-cycle main scan | Still only sink one-use locals | `allowTee = false` means multi-use locals never become sinkable |
| Invalidate conservatively | Use directional effect ordering plus explicit `try` / `try_table` guards | Avoid reordering across traps, throws, globals, memory, tables, or dangling `pop` |
| Skip structure rewrites | Do not call block / `if` / loop return helpers | Avoid inventing new control-flow result structure in the aggressive prelude |
| Late equivalent-get cleanup | Canonicalize `local.get`s toward a better equivalent local | Improve later optimization opportunities without deleting the copy-carrying sets |
| Final dead-set cleanup | Run `UnneededSetRemover` | Remove now-dead or same-value local traffic, including useless existing tees |
| Repair | Run `ReFinalize` when needed | Restore outer expression types when refined values become visible |

## Scheduler placement is part of the meaning

`pass.cpp` inserts this pass only when `options.optimizeLevel >= 4`.

The relevant aggressive prefix is:

- `ssa-nomerge`
- `flatten`
- `simplify-locals-notee-nostructure`
- `local-cse`
- `dce`
- ...

The key source comment says:

- `local-cse` is particularly useful after `flatten`
- but Binaryen wants to simplify locals a little first because `flatten` adds many new and redundant ones

That tells us the practical job of this pass:

- remove the obvious local carrier noise that `flatten` just created
- but do not add new tees or new value-carrying structure on the way to `local-cse`

### Important non-obvious scheduler fact

This pass is **not** in the canonical no-DWARF `-O` / `-Os` page used elsewhere in this repo.

So a future Starshine port must preserve two distinct truths at once:

- `simplify-locals-nostructure` is the ordinary early no-structure slot in the no-DWARF path
- `simplify-locals-notee-nostructure` is the stricter aggressive `-O4` / `-O4z`-only prelude slot

Conflating those two variants would make the scheduler dishonest.

### Nested reruns still matter

`opt-utils.h` shows that `optimizeAfterInlining(...)` prepends `precompute-propagate` and then calls `addDefaultFunctionOptimizationPasses()` on the touched functions.

That means this aggressive prelude can reappear inside optimizing passes when the parent run uses higher optimize settings.

The saved local evidence matches that story:

- the saved generated-artifact audit records one top-level missing slot:
  - slot `10`
- the saved Binaryen debug log records `18` total executions in the full `-O4z` run

So the durable scheduler lesson is:

- preserve the aggressive top-level slot
- preserve the nested rerun story under optimizing passes
- preserve the exact neighbor relation to `flatten` and `local-cse`

## Phase 1: get counting drives the main sink loop

`LocalGetCounter` from `local-utils.h` counts how many `local.get`s each local still has.

That count determines:

- whether a write has only one use and can inline directly
- whether a local is multi-use and therefore **must not** become sinkable in this variant
- whether a local now has zero reads and can be cleaned up by the late sweep

That is why the pass is not just a tiny adjacent set/get peephole.

## Phase 2: the fixpoint still has a special first cycle

`doWalkFunction(...)` begins with `firstCycle = true` and then iterates until no useful main or late optimizations remain.

This special first cycle exists in the shared implementation for all variants.

For `simplify-locals-notee-nostructure`, the important subtlety is:

- the first cycle only allows single-use sinks
- later cycles would normally enable tee-based multi-use sinks in tee-capable variants
- but here `allowTee = false`, so multi-use locals remain ineligible on every cycle

So the first-cycle split still exists, but its visible effect is narrower here than in `simplify-locals-nostructure` or full `simplify-locals`.

## Phase 3: the main scan is linear-trace based, not CFG-based

The pass inherits from `LinearExecutionWalker` and keeps a current map of pending sinkable sets:

- `sinkables : local index -> SinkableInfo`

It also tracks conservative control-flow state with:

- `blockBreaks`
- `unoptimizableBlocks`
- `ifStack`

The durable takeaway is that the main sinking logic reasons about:

- one current linear execution trace
- with explicit resets or limited merges at non-linear boundaries

It is not a full CFG + dominance analysis.

## Phase 4: the actual main rewrite family is direct single-use sinking

When `optimizeLocalGet(...)` finds a pending sinkable set for the same local, the source code has two branches:

- direct single-use sink
- tee-based multi-use sink

For this variant, only the first branch is practically reachable for newly sinkable sets.

### Why the tee branch is effectively dormant here

`canSink(...)` rejects a `LocalSet` when:

- it is a tee already
- it contains dangling EH `pop`
- `firstCycle` is true and the local has more than one use
- or `allowTee` is false and the local has more than one use

Because `allowTee = false`, a multi-use local never becomes a pending sinkable in the first place.

So in this variant the main visible sink rule is:

- find a single-use local set
- replace the later `local.get` with the set value
- nop the origin set
- continue iterating

That is a much sharper contract than “simplify-locals, but no tees.”

### Refinalization still matters

When Binaryen replaces a `local.get` with a more refined value, outer expression users may need type repair.

The source comment uses a GC example where a more refined reference changes the visible type at a `struct.get`.

So even this stricter variant still records `refinalize = true` and runs `ReFinalize()` when needed.

A future port must not lose that type-repair step just because the pass sounds like “mere local traffic cleanup.”

## Phase 5: overwrite cleanup still runs in the main walk

In `visitPost(...)`, if Binaryen sees a later `local.set` to an index that already has a pending sinkable set, the older write is dead on that linear trace.

Binaryen then:

- converts the previous set to `drop(oldValue)` if its value matters for effects
- removes the old pending sinkable entry
- continues with the newer write as the meaningful candidate

So the pass does real dead-overwrite cleanup as part of the main walk.

## Phase 6: invalidation uses directional effect ordering

`checkInvalidations(...)` compares each pending sinkable against the current effects using:

- `effects.orderedAfter(info.effects)`

This is the main safety boundary.

It blocks motion across conflicts such as:

- local reads and writes
- mutable-global reads and writes
- memory and table access conflicts
- shared-memory ordering constraints
- trap versus global-state mutation hazards
- control-flow transfer
- dangling `pop`

A faithful port should preserve this directional barrier idea instead of collapsing it into one generic “has side effects” bit.

## Phase 7: `try` / `try_table` has an extra explicit throwing-value barrier

In `visitPre(...)`, when the current node is `Try` or `TryTable`, Binaryen drops any pending sinkable whose value may throw.

Reason:

- moving that value into the `try` would change where the throw could be caught

This is an explicit pass-local correctness rule worth preserving exactly.

## Phase 8: what “no structure” disables here

The shared implementation contains these structure-building helpers:

- `optimizeLoopReturn(...)`
- `optimizeBlockReturn(...)`
- `optimizeIfElseReturn(...)`
- `optimizeIfReturn(...)`

Those helpers are only called when `allowStructure` is true.

So in `simplify-locals-notee-nostructure`, Binaryen deliberately does **not** create new:

- loop result carriers
- block result carriers
- `if (result ...)` or `if-else (result ...)` carriers extracted from local traffic
- speculative one-armed `if` else-side `local.get`s

This is one of the main semantic differences from full `simplify-locals` and from `simplify-locals-notee`.

## Phase 9: what still remains enabled despite the strict name

The most surprising still-enabled feature is:

- `allowNesting = true`

That means the pass may still sink a single-use local into an already-existing consumer position.

For example, if the IR already contains:

- `drop(local.get $tmp)`
- `i32.add (local.get $tmp) ...`
- or another ordinary use site

then replacing that `local.get` with the set value is still legal in this variant.

### Important implication for the aggressive `flatten` prelude

This means `simplify-locals-notee-nostructure` is **not** a full flatness-preserving pass.

That can be surprising because it runs immediately after `flatten`.

The best source-grounded explanation is:

- Binaryen wants to simplify locals only *a little* before `local-cse`
- it avoids new tees and new result structure
- but it still allows direct sink nesting into existing use positions

So a future Starshine port should not advertise “the IR stays flat after this pass” unless the implementation intentionally diverges from Binaryen.

## Phase 10: late equivalent-get cleanup is still a real part of the pass

If the main sink loop reaches a fixed point, Binaryen runs `runLateOptimizations(...)`.

That late stage creates an inner `EquivalentOptimizer` with these important properties:

- `connectAdjacentBlocks = true`
- track local equivalence classes using `EquivalentSets`
- canonicalize `local.get`s toward a better equivalent local
- but only remove equivalent sets when `removeEquivalentSets = allowStructure`

For this variant:

- `removeEquivalentSets = false`

So the late phase still does:

- equivalent-`get` canonicalization
- type-improving canonicalization toward a more refined local

but it does **not** do:

- the later structured variant’s redundant-set deletion

That is an important non-obvious boundary.

## Phase 11: late dead-set cleanup still runs after equivalence work

After the `EquivalentOptimizer`, Binaryen runs `UnneededSetRemover` from `local-utils.h`.

That helper removes:

- sets whose local now has zero uses
- sets that store the same value already present

Two beginner-important details follow from that:

1. `simplify-locals-notee-nostructure` still has a real final cleanup sweep.
2. “no tee” means “do not create new tees in the main sink logic,” not “ignore existing tee nodes forever.”

If an existing `local.tee` becomes unnecessary, `UnneededSetRemover` may still collapse it.

## What the dedicated shipped test proves directly

The dedicated `simplify-locals-notee-nostructure.wast/.txt` pair is small, but it proves an important visible boundary.

On the shared `contrast` input, Binaryen keeps the multi-use local `$x` as plain local traffic:

- the initial `local.set $x` remains
- both later reads remain `local.get $x`
- unlike `simplify-locals-nostructure`, no `local.tee` is created

The same output also shows the no-structure side clearly:

- the arm-local `$a` and block-local `$b` carrier patterns remain structured
- no new `if (result ...)` or block result carrier is built for them

## What must be inferred from the shared implementation

The dedicated notee/no-structure test is intentionally narrow.

So some behavior in this dossier is a source-backed inference rather than a dedicated one-file golden assertion.

Those inferences are still strong because they come from the exact shared template and helper code, but they should be labeled honestly.

High-confidence source-backed inferences include:

- single-use sink behavior matches the shared direct-sink path
- `try` / `try_table` throwing barriers still apply here
- equivalent-`get` canonicalization still runs here
- equivalent-set deletion still stays off here
- dead-set cleanup still runs here
- full flatness is not preserved here because `allowNesting = true`

## Beginner checklist: what a future Starshine port must preserve

A faithful port should preserve at least these facts:

- exact variant identity: `SimplifyLocals<false, false, true>`
- aggressive-only scheduler slot after `flatten` and before `local-cse`
- nested rerun behavior under optimizing passes at aggressive settings
- single-use direct sinks only in the main rewrite family
- no tee creation for multi-use locals
- no block / `if` / loop return creation
- conservative linear-trace invalidation rather than full-CFG reinvention
- explicit `try` / `try_table` throw barriers
- late equivalent-`get` canonicalization
- late dead-set removal
- type repair via `ReFinalize()` when refined values become visible
- honest documentation that the pass may reintroduce some nesting into already-existing consumer positions

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md)
- [`../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md`](../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md`](../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md)
- Binaryen `version_129` source files:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- Binaryen `version_129` tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.txt>
