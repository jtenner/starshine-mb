# 0146 - Binaryen `remove-unused-brs` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the refreshed `remove-unused-module-elements` dossier.
- Follow the repo wiki workflow in `docs/README.md`.
- Re-check the tracker, pass index, canonical no-DWARF path, and `agent-todo.md` before choosing a pass.
- Because the tracker no longer has a `none` queue or an implemented-landing queue, justify any already-`deep` fallback explicitly.
- Deepen the existing `remove-unused-brs` folder with direct `version_129` source-backed teaching material.
- File the durable conclusions back into:
  - `docs/wiki/binaryen/passes/remove-unused-brs/`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/index.md`
  - `docs/wiki/log.md`

## Candidate selection

I followed the campaign instructions in order:

1. read `docs/README.md`
2. read `docs/wiki/binaryen/passes/tracker.md`
3. read `docs/wiki/binaryen/passes/index.md`
4. read `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
5. re-checked the relevant backlog slices in `agent-todo.md`

At that point:

- the saved-audit `none` queue was already empty
- the implemented-landing queue was already closed by the recent `remove-unused-names` work
- the old tuple-opt major-gap fallback was already closed
- the old `remove-unused-module-elements` source-structure fallback was already closed too

So this run needed a justified major-gap fallback.

I picked `remove-unused-brs` for four source-backed reasons:

- It is still one of the most scheduler-relevant implemented hot passes in the whole repo:
  - Binaryen `version_129` runs it three times in the canonical no-DWARF function pipeline
  - `pass.cpp` comments explicitly say nearby passes open opportunities for later `remove-unused-brs` reruns
- It still has active implementation and artifact pressure in `agent-todo.md` under `RUB`, so better docs are likely to pay off soon.
- The existing folder was already broad, but it still had a major teaching gap:
  - no dedicated `wat-shapes.md` page at all, even though this pass is strongly shape-driven
  - no dedicated upstream implementation/test-map page
  - the old `binaryen-strategy.md` relied mainly on the earlier archived comparison note instead of teaching the current official `version_129` source structure directly
- That gap is major because the pass name sounds like “delete a few dead branches,” while the real upstream implementation is a staged function pass with:
  - a flow-tracking fixpoint
  - loop and block reshaping helpers
  - a GC-specific BrOn optimizer
  - a jump-threader
  - a late final optimizer with `tablify`, `restructureIf`, `selectify`, and local-set arm rewrites
  - branch-hint propagation and `never-unconditionalize` behavior

So this thread is not about changing tracker status.
It is about closing the still-real official-source and WAT-shape teaching gap in an already-deep folder.

## Official Binaryen source inventory

Primary `version_129` sources used for this research:

- core pass implementation:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedBrs.cpp>
- pass registration and scheduler placement:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- helper surfaces the pass actually depends on:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-hints.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/drop.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/gc-type-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/localize.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- representative official test families:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-eh.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-desc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-exact.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-exact-only.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-intrinsics.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_all-features.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_branch-hints.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_branch-hints-unconditionalize.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_branch-hints-shrink.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_enable-multivalue.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_levels.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_shrink-level=1.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_trap.wast>

## Freshness and source-trust rule

This dossier treats Binaryen `version_129` as the release oracle.

I also did a narrow current-main check on the core file and test roster:

- the `remove-unused-brs*` lit-file roster is unchanged between `version_129` and `main`
- the core implementation is still recognizably the same staged pass
- there is at least one small but real semantic drift in current `main`:
  - the `JumpThreader` one-child named-block redirect no longer requires the child block type to match the parent block type
  - `version_129` still has that guard

That is intentionally a **narrow** freshness statement, not a whole-file equivalence proof.
The durable rule for the living pages should be:

- use `version_129` as the normative algorithm oracle
- record current-main drift explicitly when it matters
- do not silently rewrite the `version_129` teaching story as if the released algorithm already had current-main behavior

## Repo-local sources used for context

- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `agent-todo.md` (`RUB` slice)
- the older archived comparison and HOT-shape notes:
  - `docs/wiki/raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md`
  - `docs/wiki/raw/research/0071-2026-03-28-remove-unused-brs-hot-lift-shapes.md`
- the later artifact and perf follow-ups already filed under `0076` through `0108`
- in-tree implementation/tests:
  - `src/passes/remove_unused_brs.mbt`
  - `src/passes/remove_unused_brs_test.mbt`
  - `src/passes/pass_manager.mbt`
  - `src/passes/optimize_test.mbt`
  - `src/passes/perf_test.mbt`
  - `src/cmd/cmd_wbtest.mbt`

## High-level conclusion

Binaryen `remove-unused-brs` is not just “remove unnecessary branch instructions.”

The upstream `version_129` pass is a staged function-parallel structured-control optimizer with these major pieces:

1. a custom walker that tracks which `br` / `return` values are already flowing to the surrounding continuation
2. early local rewrites while that flow information is still live
3. loop-specific reshaping to expose more removable exits
4. block sinking to move named exits inward where later optimizers can see them better
5. a separate GC-specific optimizer for `br_on_null`, `br_on_non_null`, and `br_on_cast*`
6. a jump-threader that retargets or traps branches after the main fixpoint settles
7. a late final optimizer that handles:
   - `if-else` to `br_if`
   - adjacent `br_if` merges
   - `tablify`
   - `restructureIf`
   - `selectify`
   - local-set arm cleanup
   - constant-condition branch cleanup

That is why the pass sits in three different no-DWARF top-level slots and still finds new work each time.

## Biggest beginner correction

The pass name suggests a dead-branch stripper.
The real upstream pass is closer to:

- “clean up structured control so fallthrough, branch destinations, and late shape simplifications agree better.”

That means several important rewrite families are not “dead” in the ordinary sense.
For example:

- `selectify` runs code unconditionally when cost/effects allow it
- `tablify` changes several adjacent `br_if` into one `br_table`
- `optimizeSetIf` changes a `local.set (if ...)` shape into a `br_if` plus later set or into a copy-free one-arm form
- `visitThrow` can turn a caught `throw` into a `br`
- `optimizeGC` can turn `br_on_cast` into plain `br`, `drop`, `br_on_non_null`, or `unreachable`

So the pass is about structured-control normalization and profitability, not just liveness.

## Exact implementation structure

## Phase 0: shared state and pass options

The pass class keeps a small amount of explicit walker state:

- `anotherCycle`
- `neverUnconditionalize`
- `flows`
- `ifStack`
- `loops`
- `catchers`

Those fields already teach the real story:

- this is not a generic CFG pass
- it is a custom postwalk with a few targeted stacks and fixpoint cycles

`neverUnconditionalize` matters more than it sounds.
It exists so branch-hint fuzzing can tell RUB not to start executing work that was previously conditional.
That flag is part of the real upstream behavior, not a local project quirk.

## Phase 1: flow cleanup during the main custom walk

The central custom machinery lives in:

- `visitAny(...)`
- the special `scan(...)` override
- the outer `doWalkFunction(...)` cycle

The mental model is:

- when Binaryen sees a plain `br` or `return`, it records that instruction as a currently flowing exit
- if it later reaches the matching block continuation without interference, the branch/return is redundant
- a plain `br` becomes `nop` or just its value
- a `return` becomes `nop` or just its returned value

Important details:

- value flow is stricter than control flow
  - `none`-typed arms stop value flow
  - unreachable earlier elements inside a block stop value flow
- `if` without `else` stops value flow from that point
- `if` with `else` merges the two arm-flow vectors carefully
- plain `nop` at block tails is removed early because it blocks value flow for no reason
- `TryTable` and `Loop` are allowed to keep value flow alive in this stage

This is the core “remove branches that flow to where we already go” story.

## Phase 2: in-walk control rewrites that happen before the later helper passes

Several rewrites happen during or directly alongside that same early walk.

### `optimizeSwitch(...)`

Early `switch` cleanup handles easy cases before later passes run:

- trim trailing default targets
- shift away leading default targets by subtracting a constant from the condition
- collapse one-target switches into `br`
- collapse two-option switches into `if`
- rewrite very large mostly-default switches into nested `if` form when shrinking or when the table is absurdly large

This is one reason RUB is not just about `br` and `if`.

### `visitIf(...)` early one-arm work

Before the late final optimizer, the main pass already handles:

- one-arm `if { br }` to `br_if`
- one-arm `if { br_if }` by combining conditions with a `select`
- nested one-arm `if` condition folding

These early rewrites are guarded by:

- effect safety
- cost of unconditional execution
- multivalue select limitations
- the `neverUnconditionalize` flag

### `visitThrow(...)`

This is an easy-to-miss surface.

If a `throw` is definitely caught by an enclosing `try_table` catch destination and that catch does **not** use `exnref`, then RUB treats the throw like control-flow-only branching:

- matching `catch` or `catch_all` can become `br`
- multivalue throw payloads become tuple-valued break payloads when needed
- `catch_ref` / `catch_all_ref` are explicit negative cases
- mixtures of old `Try` and `TryTable` are intentionally left alone here

That means some old-EH cleanup belongs to RUB, not only to DCE or Vacuum.

## Phase 3: `optimizeLoop(...)`

After each main walk cycle, Binaryen revisits recorded loops.

The goal is not arbitrary loop simplification.
It is specifically to expose removable exits by conditionalizing or moving the final branch-to-top shape.

Canonical family:

- a loop body ends in a simple `br $loop`
- an earlier `if` or `br_if` decides whether to exit elsewhere
- RUB can move the trailing slice into an arm or flip a nearby `br_if`
- then later ordinary flow cleanup can delete the now-redundant branch out

Important boundaries:

- loop must be named
- body must be a block
- trailing top-of-loop branch must be simple
- Binaryen stops if it encounters intervening control-flow transfer that blocks the proof
- `BranchSeeker::count(...)` is used to make sure some “move inside the if” transforms are still single-use enough to pay off

## Phase 4: `sinkBlocks(...)`

This pass stage sinks named exit blocks into loops or into one side of an `if`.

That sounds cosmetic, but it is scheduler-significant.
The point is to put the interesting label where later cleanup can use it more directly.

Two key families:

- named block containing only one loop
- named block containing only one `if`

Important safety checks:

- unreachable `if` conditions are left for DCE instead
- the block label must not be used in the `if` condition
- Binaryen only sinks into an arm that does not already use the outer label

This is an example of “make later branch cleanup easier” rather than “delete dead branch immediately.”

## Phase 5: `optimizeGC(...)`

The GC subpass is a separate postwalk run after the main fixpoint.

It handles:

- `br_on_null`
- `br_on_non_null`
- `br_on_cast`
- `br_on_cast_fail`
- descriptor variants of `br_on_cast*`

The logic depends on:

- `Properties::getFallthroughType(...)`
- `GCTypeUtils::evaluateCastCheck(...)`
- `ChildLocalizer`
- `getDroppedChildrenAndAppend(...)`
- `ReFinalize`

Important outcomes include:

- branch definitely taken -> plain `br`
- branch definitely not taken -> `drop` or plain fallthrough value
- successful cast known -> `br`
- failed cast known -> fallthrough value
- success-only-if-non-null -> `br_on_non_null` plus appended `ref.null`
- unreachable input -> append dropped children and replace with `unreachable`

Important beginner correction:

- GC-specific branch cleanup is not a different pass in `version_129`
- it is explicitly part of `RemoveUnusedBrs.cpp`

## Phase 6: `JumpThreader`

After the main fixpoint and GC work, Binaryen runs a separate jump-threader.

This stage:

- collects branch target uses with `operateOnScopeNameUsesAndSentTypes(...)`
- redirects branches from a named parent block to a named child block in certain shapes
- redirects unconditional jumps to the target of a child block's own unconditional jump
- rewrites unconditional jumps to a child block that ends in `unreachable` into direct `unreachable`

The one-child block redirect is also the place where the narrow current-main drift showed up:

- `version_129` requires parent and child block types to match
- current `main` no longer does

That is a real semantic teaching point, so the living docs should keep it explicit.

## Phase 7: `FinalOptimizer`

This is where many of the most visible WAT-shape rewrites happen.

### Block-end `if br else br` cleanup

Binaryen rewrites a block-tail `if` whose arms end in plain breaks into:

- `br_if` for one arm
- followed by the other arm's fallthrough code

### Adjacent `br_if` merge

When shrinking, adjacent `br_if` to the same target may merge into one `br_if` with `i32.or` on the conditions, but only if unconditional execution of the later condition is safe.

### `tablify(...)`

Binaryen recognizes dense runs of:

- `br_if target (i32.eq value const)`
- or `br_if target (i32.eqz value)`

and converts them into a `br_table` wrapped in a fresh named block, provided:

- the tested value is effect-free enough to share
- constants are unique
- the range is dense enough
- there are enough arms to matter
- no branch values are involved

### `restructureIf(...)`

This is the late block-exit family the older local comparison note cared about.

Canonical shape:

- named block
- first instruction is `drop(br_if $same_block ...)` or `br_if $same_block ...`
- no other branches target that block

Positive outcomes:

- whole block becomes an `if`
- or whole block becomes a `select`

Negative boundaries:

- side-effectful value payloads
- reorder-unsafe condition/value pairs
- `neverUnconditionalize`
- too-costly unconditional execution

### `selectify(...)`

Binaryen can turn a two-arm `if` into `select`, but only when:

- both arms are emit-select-compatible
- condition is not unreachable
- arms are side-effect free
- condition does not invalidate either arm
- cost model allows unconditional execution at current shrink level

### `optimizeSetIf(...)`

This covers `local.set` / `local.tee` of an `if` result.
It can:

- split out a `br_if` arm when one arm is a branch dead-end
- remove a copy arm when one arm is `local.get` of the same target local

### Constant-condition `visitBreak(...)`

RUB also cleans up `br_if` when the condition fallthrough becomes constant.
That can turn a conditional branch into either:

- unconditional `br`
- or plain fallthrough with optional kept value

and then sets `refinalize = true` because block types may change.

## Main analysis and helper dependencies

The pass depends heavily on a small set of helper families.

### Branch helpers

From `branch-utils.h`:

- `BranchSeeker`
- `replacePossibleTarget(...)`
- `operateOnScopeNameUsesAndSentTypes(...)`
- `getUniqueTargets(...)`

These power:

- single-target proofs
- jump-threading
- branch retargeting
- switch simplification

### Effect and cost helpers

From `effects.h` and `cost.h`:

- `EffectAnalyzer`
- `AtomicCost`
- `ThrowCost`
- `CastCost`
- `TooCostlyToRunUnconditionally`

These decide when Binaryen is willing to make formerly conditional work unconditional.

### Shape and child helpers

From `properties.h`, `drop.h`, and `localize.h`:

- `Properties::canEmitSelectWithArms(...)`
- `Properties::getFallthrough(...)`
- `Properties::getFallthroughType(...)`
- `getDroppedChildrenAndAppend(...)`
- `ChildLocalizer`

These are what make the GC, constant-condition, and control-preserving rewrites actually valid.

### Metadata helpers

From `branch-hints.h`:

- `copyTo`
- `copyFlippedTo`
- `applyAndTo`
- `applyOrTo`
- `flip`

This is easy to overlook, but official branch-hints tests prove that preserving branch metadata is part of the pass contract.

## Scheduler placement and pass interactions

`pass.cpp` registers `remove-unused-brs` as a public pass and places it three times in the no-DWARF `-O` / `-Os` function pipeline:

1. right after the early `remove-unused-names`
2. again after `vacuum -> reorder-locals`
3. again after `merge-blocks`

The inline comments in `pass.cpp` make the intent explicit:

- `merge-blocks` makes `remove-unused-brs` more effective
- `coalesce-locals` opens opportunities for late `remove-unused-brs`
- late `remove-unused-names` then opens opportunities again
- a second `merge-blocks` cleans up new blocks created by late `remove-unused-brs`

Nearby pass interactions a future Starshine port must preserve:

- `remove-unused-names` and `merge-blocks` are not just neighbors; they are part of the same cleanup story
- `optimize-instructions` may later clean up casts or selects created by RUB
- `dead-code-elimination` and `vacuum` still own the broader unreachable/dead-wrapper cleanup that RUB intentionally leaves alone

## Important positive shape families

The official tests and source teach these durable positive families:

- tail `br` to the current block continuation
- tail `return` from the current function continuation
- one-arm `if` to `br_if`
- nested one-arm condition folding
- large default-heavy `switch` to `if`
- dense adjacent `br_if eq const` runs to `br_table`
- block-tail `if br else br` to `br_if` plus fallthrough
- self-targeted `drop(br_if value cond)` block-tail value cleanup
- `local.set(if ...)` with branch arm extraction or copy-arm removal
- pure-arm `if` to `select`
- caught `throw` to `br`
- BrOn and BrOnCast simplification from fallthrough type knowledge
- jump-threading through simple one-child block or child-then-jump forms

## Important negative and bailout families

The source and official tests are equally clear about what stays conservative.

- multivalue selects are not emitted in the relevant early `if -> br_if` family
- too-costly unconditional execution blocks some `select` and merged-condition rewrites outside strong shrink modes
- effectful arms or reorder-unsafe condition/value pairs block `restructureIf` and `selectify`
- catch forms using `exnref` are not converted from `throw` to `br`
- mixtures of old `Try` and `TryTable` are not handled in `visitThrow`
- sparse or overlapping `br_if` constant ladders are not tablified
- version_129 jump-threading keeps the same-type guard for one-child block redirects
- unreachable-condition cases are often deliberately left to DCE or later refinalization instead of aggressively normalized in-place

## Most important porting implications for Starshine

A future Starshine port or refinement must preserve these source-backed invariants:

- RUB is staged, not one flat matcher bag.
- Flow cleanup, loop cleanup, block sinking, GC cleanup, jump-threading, and late optimizer work all matter.
- Branch-hint metadata propagation is part of correctness, not optional polish.
- `never-unconditionalize` is a real behavior flag.
- Some rewrites intentionally trade branchiness for unconditional work only when cost/effect proofs allow it.
- EH and GC branch forms are part of the pass contract.
- ReFinalize is required after multiple sub-stages, not just at one final boundary.
- `version_129` and current `main` are close here, but not identical; do not silently blur them together.

## Exact official test map

The `remove-unused-brs*` lit roster in `version_129` and current `main` is:

- `remove-unused-brs.wast`
- `remove-unused-brs-gc.wast`
- `remove-unused-brs-eh.wast`
- `remove-unused-brs-desc.wast`
- `remove-unused-brs-exact.wast`
- `remove-unused-brs-exact-only.wast`
- `remove-unused-brs-intrinsics.wast`
- `remove-unused-brs_all-features.wast`
- `remove-unused-brs_branch-hints.wast`
- `remove-unused-brs_branch-hints-unconditionalize.wast`
- `remove-unused-brs_branch-hints-shrink.wast`
- `remove-unused-brs_enable-multivalue.wast`
- `remove-unused-brs_levels.wast`
- `remove-unused-brs_shrink-level=1.wast`
- `remove-unused-brs_trap.wast`

The biggest teaching lesson from that roster is simple:

- Binaryen itself treats RUB as a pass with core, GC, descriptor, exact-type, EH, branch-hint, shrink-level, multivalue, all-features, and trap-sensitive surfaces.

Any beginner explanation that only covers `if -> br_if` and tail-`br` stripping is therefore incomplete.

## Remaining uncertainty

- I did not do a full line-by-line diff audit of every `remove-unused-brs*` lit file between `version_129` and `main`; I only verified that the roster is unchanged and that the core file has at least one small semantic drift.
- The folder already had an older parity note mentioning a newer Chromium-hosted trap-threading change. This research run did not fully re-audit that older drift claim across every mirror surface, so the safe wiki move is to keep `version_129` as the explicit oracle and record newly verified drift separately instead of trying to collapse all freshness stories into one sentence.
