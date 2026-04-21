---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0114-2026-04-20-rse-binaryen-research.md
related:
  - ./index.md
  - ./cfg-and-value-tracking.md
  - ./wat-shapes.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `rse` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is `src/passes/RedundantSetElimination.cpp`.
- Scheduler placement comes from `src/passes/pass.cpp` and the after-inlining helper in `src/passes/opt-utils.h`.
- The key helper contracts come from:
  - `src/ir/local-graph.h`
  - `src/ir/liveness.h`
  - `src/ir/numbering.h`
  - `src/ir/properties.h`
- The shipped behavior examples come from:
  - `test/passes/rse_all-features.wast`
  - `test/passes/rse_all-features.txt`
  - `test/lit/passes/rse-gc.wast`

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/liveness.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast>

## High-level intent

Binaryen uses `rse` to remove redundant local traffic.

That sentence is true but incomplete.

The real `version_129` pass is a hybrid of:

- local-set redundancy elimination
- local-get replacement
- copied-local value propagation
- basic-block predecessor merging
- liveness-backed dead-store checks
- type-aware current-expression refinement

The name sounds like a generic write-elimination pass.

The implementation is narrower:

- it is about **locals**
- it is intentionally conservative around non-linear control flow
- it explicitly avoids loop precision with the current block-input model

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Build local graph | Compute per-basic-block local get/set relations and fallthrough info | Turn “is this set still needed?” into a real graph question |
| Seed local state | Give parameters initial value numbers plus self-influence markers | Treat entry values like tracked local sources |
| Merge block inputs | Combine predecessor knowledge into exact value, merged values, or unseen | Preserve precision only when predecessors really agree |
| Walk linearly | Track current local values through straight-line code | Enable redundant set/get decisions |
| Rewrite sets | Delete same-value or never-needed `local.set` / `local.tee` | Shrink local traffic without losing RHS effects |
| Rewrite gets | Replace some `local.get`s with the current expression/local/zero | Make earlier sets dead and keep current values more precise |
| Invalidate stale influences | Remove obsolete set->get relations as rewrites happen | Expose more dead sets later in the same walk |
| Refinalize + vacuum | Repair types and clean tiny leftovers | Keep valid IR and a tidy final shape |

## Phase 1: `rse` is locals-only in `version_129`

The most important scope fact comes straight from the implementation surface.

`RedundantSetElimination.cpp` visits and tracks:

- `LocalSet`
- `LocalGet`

And its analysis dependencies are local-specific:

- `LocalGraph`
- `Liveness`

There is no pass-local visitor for:

- `GlobalSet`
- memory stores
- `StructSet`
- `ArraySet`

So a faithful description is:

- `rse` is Binaryen's late **local** redundancy cleanup pass

not:

- “remove all redundant sets everywhere.”

This is the first thing a Starshine port should preserve honestly.

## Phase 2: current values are tracked on a tiny lattice

Each local index has a `LocalInfo` record with:

- `curr`
  - the pass's best current-value knowledge
- `setses`
  - which sets or entry/self values still influence that current value

The value side is a three-state lattice:

| State | Meaning |
| --- | --- |
| `Unseen` | no exact current value is trusted here |
| exact `Value` | all known paths agree on one numbered value |
| `MergedValues` | predecessors disagree, so only a set of possible values remains |

That lattice is tiny on purpose.

Binaryen would rather lose precision than claim more CFG knowledge than it really proved.

## Phase 3: value numbering makes “same value” semantic, not textual

The pass uses `ValueNumbering` to compare values.

It also supplies a `FlexibleValues` callback so that if the implementation already knows the exact current value of a local, then a `local.get` can be value-numbered as that current value instead of as just “some get.”

Practical consequences:

- repeated pure values can count as the same current local value
- copied locals can inherit exact value identity
- refined GC expressions can still count as the same semantic value when appropriate

So “same value” in `rse` means:

- same value number under the current flexible-local environment

not merely:

- same syntax text

## Phase 4: block entry merges are where CFG precision is won or lost

Before visiting a basic block, the pass merges predecessor information.

For one local index, the merge rule is:

- if all predecessors provide the same exact value, keep that exact value
- if predecessors provide different values, record `MergedValues`
- if there is no usable predecessor knowledge, keep `Unseen`

This is the core CFG boundary.

The pass still merges the influencing set history even when exact value knowledge collapses.

That asymmetry is important:

- exact substitution needs one exact value
- dead-set reasoning can still benefit from “these are the possible incoming sets”

## Phase 5: copied locals inherit both value and history

If Binaryen sees:

```wat
(local.set $y
  (local.get $x))
```

it does not treat `$y` as merely holding the syntax `local.get $x`.

Instead it lets `$y` inherit:

- `$x`'s current value state
- `$x`'s influencing set history

That means later reads of `$y` and later dead-set checks on `$y` can be as precise as the knowledge Binaryen already had for `$x`.

This copied-local inheritance is one of the easiest things to accidentally omit in a simpler port.

## Phase 6: redundant set elimination has two main entry points

## Family 1: same-value set

If a `local.set` writes the value the local already holds, the set is redundant.

Rewrite shape:

- `local.set` -> `drop(value)`
- `local.tee` -> `value`

This preserves any RHS work while deleting the local write.

## Family 2: never-needed set

If liveness and fallthrough analysis say the stored local value is never needed by any future non-rewriteable read, then the set is redundant even if the new value differs from the old one.

This is where the pass becomes more interesting than a plain same-value peephole.

## Phase 7: same-block reads can be rewritten, so they do not always keep a set alive

The helper `isNeverRead(...)` is subtle.

A later read inside the same basic block does **not** automatically force the set to stay.

If all influenced gets are in the same block and the set does not influence the block's fallthrough value, Binaryen can remove the set because those same-block gets can be replaced directly.

This is a major implementation fact.

It means the pass is really doing two coordinated things:

- delete redundant sets
- rewrite redundant gets

If you only implement the first half, you will miss real upstream behavior.

## Phase 8: `noteExpression(...)` is where current-value refinement happens

The pass watches ordinary expressions too.

If an expression's value number matches the exact current value of some local, Binaryen may record that expression as the better current representative for that local.

This matters because a later `local.get` replacement should use the **best current expression**, not just an arbitrary earlier one.

For GC locals, this is how more refined expressions like `ref.cast` or `ref.as_non_null` can become the preferred current representative.

## Phase 9: `replaceLoadCurr(...)` is the type-aware local-get rewrite gate

When Binaryen decides a `local.get` can be replaced with the current value, it still checks static type compatibility.

If the current representative expression has a subtype that fits the `local.get` type, Binaryen substitutes that expression.

Otherwise, when the type admits it, the helper path can materialize a zero literal of the requested type.

Two important takeaways:

- this is not a blind substitution pass
- the GC/ref-type story is tied to type assignability

The shipped `rse-gc.wast` tests exist largely to keep this replacement logic honest.

## Phase 10: non-linear control-flow barriers deliberately wipe precision

After branches and control-flow structures, `noteNonLinear()` clears current local-value knowledge.

This means exact straight-line reasoning is intentionally local.

A beginner-friendly way to think about it is:

- `rse` trusts what it learned on the current linear path
- once control can split or rejoin in a hard-to-model way, it forgets the exact linear cache and falls back to more conservative block-entry reasoning

This is why the pass stays much simpler than a full SSA optimizer.

## Phase 11: loops are a deliberate conservative bailout

The source comment explicitly says there is no point optimizing loops here with the current `LocalGraph` block-input model because the inputs are wrong in loops.

That means upstream `version_129` prefers:

- leaving some loop redundancies unfixed

instead of:

- risking unsound cross-backedge substitutions

A faithful port should either preserve this loop boundary first or replace it with a provably better loop-aware model.

## Phase 12: liveness/influence invalidation is part of the algorithm, not cleanup fluff

The pass updates the local-graph/liveness story as it rewrites.

Key helpers include:

- `invalidateSetGetPairs(...)`
- `unneededLoad(...)`
- `fixPredecessorValues(...)`

The practical meaning is:

- once Binaryen proves an older set no longer matters,
- it removes stale influence edges,
- which can make yet more sets look dead later in the same walk

So the analysis is not purely read-only.

The optimizer mutates its own bookkeeping as it goes.

## Phase 13: GC support is about refined local values, not field stores

The shipped GC lit tests show several exact behaviors worth preserving:

- **positive**: prefer a current refined expression when it still fits the use type
- **negative**: do not replace a local get with a more refined but non-assignable expression
- **negative**: do not pretend different predecessor choices are one exact value
- **negative**: do not over-refine through loop-target shapes

This is the easiest place to overstate the pass.

The real GC contract is:

- type-aware local substitution

not:

- “GC field write elimination.”

## Phase 14: the pass refinalizes and vacuums immediately after changes

After a changed function walk, Binaryen runs:

- `ReFinalize().walkFunctionInModule(...)`
- `vacuum.runOnFunction(...)`

That tells us two things:

- the pass expects its local rewrites to perturb types and structure enough that repair is mandatory
- the pass also expects tiny cleanup debris and intentionally relies on `vacuum` to remove it

This is why the scheduler still keeps another late top-level `vacuum` after `rse`.

## Scheduler placement is part of the meaning

In `pass.cpp`, Binaryen places `rse` late in the default function optimization pipeline:

- after `coalesce-locals` / `local-cse` / `simplify-locals`
- after late `code-folding`, `merge-blocks`, `remove-unused-brs`, and `remove-unused-names`
- after late `precompute(-propagate)`, `optimize-instructions`, and `heap-store-optimization`
- before the final `vacuum`

That placement is a design clue.

By the time `rse` runs:

- locals have already been structurally simplified
- shared values and copied locals are easier to see
- pure value cleanup has already exposed more obvious same-value traffic
- one final cleanup pass is still available after `rse` finishes

This is why a future Starshine implementation should resist the temptation to wire `rse` too early.

## What the pass does **not** do

A future port should avoid silently broadening the pass beyond upstream behavior.

`rse` in Binaryen `version_129` does **not**:

- eliminate `global.set`
- eliminate memory stores
- eliminate `struct.set` or `array.set`
- solve full SSA or arbitrary phi reasoning
- optimize loops with the current implementation
- keep exact value knowledge through every non-linear control-flow boundary
- promise one canonical best expression after multi-way predecessor disagreement

The real contract is smaller, more local, and more conservative than the name suggests.

## The most important porting lessons

If Starshine ports `rse`, preserve these facts first:

1. locals-only scope
2. exact scheduler slot and nested rerun presence
3. copied-local inheritance of both value and influence history
4. same-block local-get rewriting as part of dead-set elimination
5. the `Unseen` / exact value / merged-values lattice
6. non-linear barriers that wipe exact current-value knowledge
7. explicit loop conservatism unless a stronger proof-backed model exists
8. type-aware refined-expression replacement for GC locals
9. refinalization and vacuum cleanup after local rewrites

Those are the durable upstream truths.

## Sources

- [`../../../raw/research/0114-2026-04-20-rse-binaryen-research.md`](../../../raw/research/0114-2026-04-20-rse-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` local graph helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- Binaryen `version_129` liveness helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/liveness.h>
- Binaryen `version_129` value numbering helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
- Binaryen `version_129` properties helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- Binaryen `version_129` pass tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast>
- Binaryen `version_129` pass output: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.txt>
- Binaryen `version_129` GC lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast>
