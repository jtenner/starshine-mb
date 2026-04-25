# 0129 - `simplify-locals-notee-nostructure` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented Binaryen local-cleanup pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain what `simplify-locals-notee-nostructure` actually does, which helper utilities it depends on, which IR / WAT shapes it rewrites or preserves, and what a future Starshine port must keep exact.
- Superseded for raw-source provenance and Starshine local status by [`0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md`](0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md) and [`../binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md`](../binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md). The mechanics reading below remains useful historical source work.

## Why this pass

- `docs/wiki/binaryen/passes/tracker.md` still listed `simplify-locals-notee-nostructure` with wiki status `none` when this thread started.
- The same tracker had already promoted `simplify-locals-notee-nostructure` to the top suggested next target after the new `merge-locals` dossier landed.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - slot `10`
- The saved Binaryen debug log shows it is not just a one-off top-level curiosity in that captured run:
  - top-level slot `10` took about `0.568566` seconds
  - the same full run executed `simplify-locals-notee-nostructure` `18` total times because later optimizing reruns reused the same default aggressive function pipeline under the higher optimize settings
- `simplify-locals-notee-nostructure` sits in a very revealing aggressive local-cleanup neighborhood whose behavior is easier to understand once this pass is clear:
  - `flatten`
  - `simplify-locals-notee-nostructure`
  - `local-cse`
- The current repo backlog still has **no dedicated `simplify-locals-notee-nostructure` slice** in `agent-todo.md`.
  - The closest local planning notes today are:
    - the neighboring `SLNS` slice for `simplify-locals-nostructure`
    - the older removed-pass list in `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- The name is especially easy to overread.
  - A shallow mental model like “full simplify-locals, but even more restrictive” misses several source-level truths:
    - Binaryen is **not** using a separate implementation here; it instantiates the shared `SimplifyLocals.cpp` template
    - Binaryen is **not** preserving full flatness here, because nesting still remains enabled
    - Binaryen is **not** doing tee creation for multi-use locals here
    - Binaryen is **not** doing block / `if` / loop return creation here
    - Binaryen **is** still doing direct single-use sinks, late equivalent-`get` canonicalization, and final dead-set cleanup here

That makes `simplify-locals-notee-nostructure` a strong dossier target: it was the last remaining current saved-audit `none` gap, it sits in the already-documented aggressive `flatten -> local-cse` prelude, and the real contract is much sharper and more surprising than the CLI name alone suggests.

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- neighboring dossiers:
  - `docs/wiki/raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md`
  - `docs/wiki/raw/research/0119-2026-04-20-local-cse-binaryen-research.md`
  - `docs/wiki/raw/research/0127-2026-04-20-flatten-binaryen-research.md`
  - `docs/wiki/raw/research/0128-2026-04-20-merge-locals-binaryen-research.md`

### Official Binaryen `version_129` sources

- `src/passes/SimplifyLocals.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/passes.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/ir/local-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
- `src/ir/effects.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `src/ir/equivalent_sets.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
- `src/ir/linear-execution.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- `src/ir/properties.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `src/ir/branch-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- `test/passes/simplify-locals-notee-nostructure.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
- `test/passes/simplify-locals-notee-nostructure.txt`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.txt>
- nearby sibling tests used to understand shared-engine behavior boundaries:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.txt>

### Freshness check on current upstream `main`

- `src/passes/SimplifyLocals.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>

I only used `main` for a narrow freshness check on the easiest drift points to miss:

- the public constructor surface still includes `createSimplifyLocalsNoTeeNoStructurePass()`
- the pass registry still exposes `simplify-locals-notee-nostructure`
- the aggressive `addDefaultFunctionOptimizationPasses()` prelude still includes:
  - `flatten`
  - `simplify-locals-notee-nostructure`
  - `local-cse`

On that narrow surface, I did not see a same-day drift from the `version_129` story.
That is **not** a claim that every internal detail on `main` is unchanged.

## Initial answer in one paragraph

Binaryen `version_129` implements `simplify-locals-notee-nostructure` as `SimplifyLocals<false, false, true>`: a shared simplify-locals variant that runs only in aggressive `optimizeLevel >= 4` mode, immediately after `flatten` and before `local-cse`, and whose main visible rewrite family is direct single-use local sinking plus late equivalent-`get` cleanup and final dead-set removal. The pass explicitly disables both tee creation and structure-building rewrites, but it still allows ordinary nesting into existing consumer positions, which means it is **not** the full flatness-preserving variant despite its scheduler slot. In beginner terms, Binaryen uses it to remove the easiest temp locals that `flatten` just created, without also inventing new tees or new control-flow result structure.

## Public naming and alias surface

There are three name surfaces that matter locally.

### 1. Upstream pass registration

`pass.cpp` registers:

- `simplify-locals-notee-nostructure`
- description: `miscellaneous locals-related optimizations (no tees or structure)`
- factory: `createSimplifyLocalsNoTeeNoStructurePass`

So the public CLI meaning is explicitly:

- no tees
- no structure

but not “no nesting.”

### 2. Upstream constructor name

`passes.h` declares:

- `Pass* createSimplifyLocalsNoTeeNoStructurePass();`

`SimplifyLocals.cpp` defines it as:

- `return new SimplifyLocals<false, false>();`

which, given the template defaults, means:

- `allowTee = false`
- `allowStructure = false`
- `allowNesting = true`

This one line is the most important source fact in the whole dossier.

### 3. Current Starshine placeholder alias

`src/passes/optimize.mbt` still tracks the removed-name placeholder as:

- `simplify-locals-no-tee-no-structure`

The tracker now needs to keep explicit that:

- Binaryen / audit spelling = `simplify-locals-notee-nostructure`
- current Starshine removed-name placeholder = `simplify-locals-no-tee-no-structure`

## Source-grounded scheduler placement

## Aggressive top-level slot

In `pass.cpp`, the aggressive part of `addDefaultFunctionOptimizationPasses()` says:

- if `options.optimizeLevel >= 4`:
  - `flatten`
  - `simplify-locals-notee-nostructure`
  - `local-cse`

The source comment explains why:

- `local-cse` is particularly useful after `flatten`
- but `flatten` adds many new and redundant locals
- so Binaryen wants “some amount” of simplify-locals first

That comment strongly suggests the practical intent of this exact variant:

- simplify the most obvious temporary carrier locals
- but avoid heavier local cleanup machinery that would add tees or new structure before `local-cse`

## Not in the canonical no-DWARF `-O` / `-Os` path

The current repo’s no-DWARF page documents `simplify-locals-nostructure` in the ordinary early local-cleanup slot.
It does **not** list `simplify-locals-notee-nostructure` there.

That is correct.

This pass is an aggressive-only slot.
A future Starshine port must not quietly merge it into the ordinary no-DWARF story.

## Nested reruns still matter

`opt-utils.h` shows:

- `addUsefulPassesAfterInlining(runner)` prepends `precompute-propagate`
- then calls `runner.addDefaultFunctionOptimizationPasses()`

So if the parent optimization run is aggressive enough, touched functions can see the aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` prelude again inside nested reruns.

The saved local evidence matches that:

- the top-level captured `-O4z` audit records one missing slot:
  - slot `10`
- the saved Binaryen debug log records `18` total executions in the full run

So the durable scheduler lesson is:

- preserve the top-level slot
- preserve the nested rerun story
- preserve the exact neighbor relation to `flatten` and `local-cse`

## The real implementation structure

## One shared template, not a bespoke pass

`SimplifyLocals.cpp` implements one main template:

- `SimplifyLocals<allowTee, allowStructure, allowNesting>`

For this pass, the instantiation is:

- `SimplifyLocals<false, false, true>`

That means the whole real contract must be read as “what the shared engine does when those three gates are set like this.”

## Phase 1: count local gets

The pass starts by using `LocalGetCounter` from `local-utils.h`.

It counts reads per local.
That count drives:

- which locals are single-use and can sink directly
- which locals are multi-use and therefore ineligible here
- which locals become zero-use by the end and can be removed later

This is why the pass is more than a purely local adjacent set/get peephole.

## Phase 2: fixpoint with a stricter first cycle

The pass begins with `firstCycle = true` and iterates until neither the main walk nor the late cleanup finds more useful work.

The shared comment explains the reason:

- single-use locals are easy to sink and match common compiler patterns
- further cycles can do more complicated work

For `notee-nostructure`, the special point is:

- the first cycle only permits one-use sinks
- later cycles would normally allow tee-based multi-use sinks in tee-enabled variants
- but `allowTee = false` means multi-use locals remain disallowed on every cycle

So the first-cycle / later-cycle split still exists, but its visible effect is narrower here than in `simplify-locals-nostructure` or full `simplify-locals`.

## Phase 3: linear-trace scanning, not full CFG reasoning

The pass inherits from `LinearExecutionWalker` and tracks pending candidate writes in:

- `sinkables : local index -> SinkableInfo`

It also keeps small extra state for non-linear regions:

- `blockBreaks`
- `unoptimizableBlocks`
- `ifStack`

The main durable point is:

- the pass reasons about one current linear execution trace
- it explicitly resets or conservatively merges around non-linear control flow
- it is not a full CFG, dominator, or liveness engine

That matters because the pass name sounds much broader than the actual algorithm.

## Phase 4: `canSink(...)` is where the no-tee rule really bites

`canSink(LocalSet* set)` rejects candidates when:

- the set is already a tee
- the value contains dangling EH `pop`
- `firstCycle` is true and the local has more than one use
- or `allowTee` is false and the local has more than one use

That last rule means:

- any multi-use local is blocked from entering the sinkable set in this variant

This is the most important operational consequence of `allowTee = false`.

## Phase 5: the main positive rewrite is direct single-use sinking

`optimizeLocalGet(...)` has a source-level split between:

- direct single-use sink
- tee-based multi-use sink

For this variant, only the first branch is practically relevant for newly sinkable sets.

### Direct single-use sink

When a later `local.get` reads a pending sinkable write and the local has one use:

- replace the `local.get` with the set’s value
- nop the origin set
- erase the pending sinkable
- mark another cycle if needed

This is the core positive rewrite family a future port must preserve.

### Why the tee branch is effectively dormant

The tee branch would:

- replace the `local.get` with the `local.set`
- turn the set into a `local.tee`
- nop the old origin

But `canSink(...)` prevents multi-use locals from ever reaching that point in this variant.

So the real beginner-friendly summary is:

- `simplify-locals-notee-nostructure` behaves like a one-use direct-sink local simplifier, plus later cleanup

## Phase 6: overwrite cleanup still happens during the main walk

In `visitPost(...)`, if Binaryen sees a later set to a local that already has a pending sinkable set, the earlier write is dead on that linear trace.

Binaryen then:

- converts the earlier set into `drop(oldValue)` if needed for effects
- removes the old pending sinkable entry
- continues with the newer write as the meaningful candidate

So the pass still does real dead-overwrite cleanup, not just direct get replacement.

## Phase 7: invalidation uses directional effect ordering

Each sinkable stores an `EffectAnalyzer` snapshot.

As the walk continues, `checkInvalidations(...)` compares the current effects against each pending sinkable using:

- `effects.orderedAfter(info.effects)`

This blocks dangerous motion across:

- local reads and writes
- mutable-global reads and writes
- memory and table effects
- shared-memory ordering rules
- traps versus global-state mutation hazards
- branches / returns / nonlocal control transfer
- dangling `pop`

A faithful port should preserve this directional invalidation model instead of reducing everything to one “impure expression” boolean.

## Phase 8: `try` / `try_table` has an extra dedicated throw barrier

In `visitPre(...)`, when the current node is `Try` or `TryTable`, Binaryen explicitly drops pending sinkables whose values may throw.

Reason:

- moving such a value into the `try` could change which handler catches the exception

This is a dedicated pass-local correctness rule, not just a generic side-effect check.

## Phase 9: what the structure gate disables

The shared implementation contains these structure-building helpers:

- `optimizeLoopReturn(...)`
- `optimizeBlockReturn(...)`
- `optimizeIfElseReturn(...)`
- `optimizeIfReturn(...)`

They are only called when `allowStructure` is true.

So this variant does **not** create new:

- loop result carriers
- block result carriers
- `if (result ...)` or `if-else (result ...)` carriers from local traffic
- speculative one-armed `if` else-side `local.get`s

That is the exact source-grounded meaning of “no structure.”

## Phase 10: despite the aggressive slot, nesting is still enabled

This is the most counterintuitive source fact.

Because `allowNesting = true`, a single-use local may still sink into an already-existing consumer position.

That means the pass can still turn:

- `drop(local.get $tmp)` into `drop(value)`
- another ordinary read of a temp into the temp’s stored value directly

So this pass is **not** the nonesting variant.

## Consequence: it does not preserve full flatness

Because Binaryen runs this after `flatten`, it is tempting to assume the pass preserves Flat IR.

The source does not justify that assumption.

What the source supports is only this narrower claim:

- the pass removes some of the locals that `flatten` created
- it avoids adding tees or new value-carrying control structure
- but it may still reintroduce some ordinary nesting into existing consumer positions

That is an important beginner trap to document explicitly.

## Phase 11: late equivalent-`get` cleanup still runs here

If the main walk reaches a fixed point, `runLateOptimizations(...)` runs an inner `EquivalentOptimizer`.

Important details:

- it sets `connectAdjacentBlocks = true`
- it uses `EquivalentSets`
- it canonicalizes `local.get`s toward a better equivalent local
- it can prefer a more refined type even when use counts tie

For this variant:

- `removeEquivalentSets = allowStructure = false`

So the late phase still does:

- equivalent-`get` canonicalization
- type-improving canonicalization

But it does **not** do:

- equivalent-set deletion of the structured variant

That distinction is easy to miss if one only reads the CLI name.

## Phase 12: final dead-set cleanup still runs too

After the `EquivalentOptimizer`, Binaryen runs `UnneededSetRemover` from `local-utils.h`.

That helper removes:

- sets whose local now has zero uses
- sets that assign the same value already present

It also handles tee-shaped sets.

So “no tee” means:

- do not create a new tee in the main sink logic

It does **not** mean:

- leave every existing tee alone forever

A dead or same-value existing tee can still be erased by the final cleanup sweep.

## What the shipped tests tell us directly

## Direct dedicated evidence: the `contrast` boundary

The dedicated `simplify-locals-notee-nostructure.wast/.txt` pair is small, but it proves two important visible boundaries.

### Multi-use local `$x`

Input has:

- one `local.set $x (i32.const 1)`
- two later `if (local.get $x)` uses

Output keeps:

- the `local.set`
- both `local.get`s
- no `local.tee`

So the “no tee” rule is visibly real.

### Structured carriers `$a` and `$b`

The same test keeps:

- arm-local `if` carriers in place
- block / branch local-carrier structure in place

So the “no structure” rule is visibly real too.

## What the shipped tests do **not** cover directly

The dedicated notee/no-structure test is narrow.
It does not by itself golden-test every source behavior that still remains enabled.

So the following conclusions are **source-backed inferences**, not dedicated single-test-file golden claims:

- direct single-use sink behavior still exists here
- `try` / `try_table` throw barriers still apply here
- late equivalent-`get` canonicalization still runs here
- equivalent-set deletion still stays off here
- final dead-set cleanup still runs here
- full flatness is not preserved here because nesting still remains enabled

Those inferences are still strong because they follow from the exact shared template and helper code, but they should be labeled honestly.

## Important positive, negative, and bailout families

## Positive families

- direct one-use sink into an existing consumer
- dead-overwrite cleanup on the current linear trace
- late equivalent-`get` canonicalization
- final dead / same-value set removal
- cleanup of useless existing tee traffic

## Negative families

- multi-use locals that would need a tee
- new block result creation from local carriers
- new `if (result ...)` creation from arm-local sets
- new loop result creation from loop-local carriers
- one-armed `if` speculative else-side `local.get` insertion
- equivalent-set deletion in the late phase

## Bailout / barrier families

- trap-capable values crossing global-observable effect barriers
- throwing values crossing into `try` / `try_table`
- dangling `pop` values
- already-tee candidates in the main sink loop
- arbitrary non-linear control flow beyond the conservative linear-trace model

## Relationship to nearby passes

## Relation to `flatten`

This pass exists in its most visible scheduler role because `flatten` creates lots of temporary locals.

Binaryen wants to simplify some of them before `local-cse`, but not so aggressively that it introduces new tees or new structured carriers.

That is why this variant is stricter than `simplify-locals-nostructure`.

## Relation to `local-cse`

`local-cse` benefits when repeated whole trees stop looking artificially different because of extra temp-local wrappers.

The source comment in `pass.cpp` explicitly names that handoff.

So this pass is part of the practical precondition story for aggressive `local-cse`.

## Relation to `simplify-locals-nostructure`

`simplify-locals-nostructure` is:

- `SimplifyLocals<true, false, true>`

That later ordinary early-slot variant can tee a multi-use local.
This aggressive variant cannot.

## Relation to full `simplify-locals`

Full `simplify-locals` is:

- `SimplifyLocals<true, true, true>`

That later pass finishes the structure-building and equivalent-set deletion work that this aggressive prelude intentionally leaves behind.

## What a future Starshine port must preserve

A faithful port should preserve at least these facts:

- exact variant identity: `SimplifyLocals<false, false, true>`
- aggressive-only scheduler slot after `flatten` and before `local-cse`
- nested rerun behavior under optimizing passes when aggressive settings are in effect
- main visible rewrite family = direct single-use sink, not tee-based multi-use sink
- no new `local.tee` creation
- no new block / `if` / loop result creation
- conservative linear-trace invalidation rather than a hand-wavy “optimize locals somehow” rewrite
- explicit `try` / `try_table` throw barrier
- late equivalent-`get` canonicalization with `removeEquivalentSets = false`
- final dead-set cleanup via `UnneededSetRemover`
- refinalization when more refined values become visible
- honest documentation that full Flat IR is not guaranteed to survive this pass unchanged

## Open questions / uncertainty

- The dedicated `simplify-locals-notee-nostructure` test is small.
  - It nails the most visible tee / structure boundaries well.
  - It does **not** alone prove every single-use and late-cleanup family.
- The strongest claims about single-use sinks, late get canonicalization, and flatness loss are therefore:
  - direct readings of the shared `SimplifyLocals.cpp` implementation
  - cross-checked against sibling simplify-locals tests
- The same-day `main` check was intentionally narrow.
  - I only checked the public variant surface and the aggressive scheduler slot.
  - I did not perform a full drift audit of every internal helper on `main`.

## Condensed durable takeaways

- `simplify-locals-notee-nostructure` is `SimplifyLocals<false, false, true>`.
- It is an aggressive `-O4` / `-O4z` slot, not part of the ordinary no-DWARF `-O` / `-Os` path.
- Its main visible rewrite family is direct single-use sinking.
- It deliberately refuses both tee creation and structure creation.
- It still runs late equivalent-`get` cleanup and final dead-set cleanup.
- It still allows ordinary nesting into existing consumer positions, so it is not the flatness-preserving nonesting variant.

## Sources

### Local repo sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- neighboring raw notes:
  - `docs/wiki/raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md`
  - `docs/wiki/raw/research/0119-2026-04-20-local-cse-binaryen-research.md`
  - `docs/wiki/raw/research/0127-2026-04-20-flatten-binaryen-research.md`
  - `docs/wiki/raw/research/0128-2026-04-20-merge-locals-binaryen-research.md`

### Binaryen `version_129`

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

### Narrow freshness checks on current upstream `main`

- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
