# 0115 - `code-pushing` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented no-DWARF / `-O4z` Binaryen pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain what upstream `code-pushing` actually does, what source files and helper analyses matter, which IR / WAT shapes it rewrites, which bailout families matter, and what a future Starshine port must preserve.

## Why this pass

- The updated tracker still listed `code-pushing` with wiki status `none` at the start of this run.
- The tracker also ranked it as the first suggested next dossier target.
- No dedicated living folder existed yet under `docs/wiki/binaryen/passes/code-pushing/`, so this was still an eligible new dossier rather than overlap with an existing deep page.
- `code-pushing` matters to both of the main Binaryen parity stories in this repo:
  - the canonical Binaryen no-DWARF `-O` / `-Os` path
  - the saved generated-artifact `-O4z` audit
- It sits in an especially helpful neighborhood for future Starshine work:
  - after `precompute`
  - before `tuple-optimization`
  - before `simplify-locals-nostructure`
- That means a good dossier here helps explain one of the currently missing scheduler neighbors that still blocks fully honest tuple-opt preset placement in-tree.
- The pass name is easy to misread. It sounds like generic code motion or LICM, but the actual `version_129` implementation is much narrower and more local:
  - it scans a block left-to-right
  - it looks for a contiguous pushable suffix immediately before a control-flow separator
  - it only moves that suffix into specific downstream segments or `if` arms when effect ordering, result use, and code-size heuristics all say it is safe

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tuple-optimization/index.md`
- `docs/wiki/binaryen/passes/tuple-optimization/scheduler-and-gates.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `agent-todo.md`

### Official Binaryen `version_129` sources

- `src/passes/CodePushing.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/ir/effects.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `test/lit/passes/code-pushing.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing.wast>
- `test/lit/passes/code-pushing_into_if.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_into_if.wast>
- `test/lit/passes/code-pushing_ignore-implicit-traps.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_ignore-implicit-traps.wast>
- `test/lit/passes/code-pushing_tnh.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_tnh.wast>
- `test/lit/passes/code-pushing-gc.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-gc.wast>
- `test/lit/passes/code-pushing-eh.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-eh.wast>

## Fast answer

Binaryen’s `code-pushing` pass is an **early control-dependent sinking pass**.

What it really does in `version_129` is:

1. walk each function bottom-up
2. scan each block for a contiguous suffix of expressions that are currently movable
3. look at the next control-flow structure after that suffix
4. ask whether cloning that suffix deeper into the relevant branches or segments is:
   - semantically safe
   - still type-correct after refinalization
   - profitable enough for size / execution tradeoffs
5. if yes, duplicate the suffix into the downstream segments and delete the original copy

Important durable facts:

- This is **not** generic CFG-wide code motion.
- It is **not** loop-invariant code motion.
- It is **not** common subexpression elimination.
- It is **not** a generic branch-folding pass.
- The implementation is built around **block-local segment selection** plus one important special case for sinking across `if`.
- The pass is willing to duplicate code, but only when a local heuristic says the benefit is worth the added copies.
- When both `if` arms are reachable, Binaryen becomes much stricter:
  - no value-typed `if`
  - no calls
  - no side effects
  - no throws
  - no mutable-global / memory / table traffic
  - no trap-sensitive operations under default settings
- When one `if` arm is already `unreachable`, Binaryen is more permissive because it can sink into the one reachable arm without duplicating into two live paths.
- The exact barrier model is option-sensitive. The shipped `ignore-implicit-traps` and `traps-never-happen` tests show that pass options deliberately relax some trap-related invalidation rules.

A safer short description is:

> `code-pushing` is Binaryen’s early pass for sinking a movable block suffix into downstream control-flow segments when all the effect, use, and profitability checks line up.

That matches the implementation much better than the CLI name alone.

## Where it appears in the scheduler

## Top-level no-DWARF path

Binaryen `version_129` `pass.cpp` schedules `code-pushing` in the default function pipeline when `optimizeLevel >= 2`.

In the canonical no-DWARF `-O` / `-Os` path tracked in this repo, the relevant neighborhood is:

- `optimize-instructions`
- `heap-store-optimization`
- `pick-load-signs`
- `precompute`
- `code-pushing`
- `tuple-optimization`
- `simplify-locals-nostructure`
- `vacuum`
- `reorder-locals`

That placement is meaningful.

The top comment in `CodePushing.cpp` explicitly says the pass should run after at least `optimize-instructions`, because earlier simplification can already remove some work. The neighboring tuple and local-cleanup passes then benefit from a body where some branch-local work has already been sunk out of common prefixes.

## Saved generated-artifact `-O4z` audit

The saved ordered audit in this repo records `code-pushing` as a real missing top-level slot:

- slot `20`: `code-pushing`

The same saved Binaryen debug log shows many more executions in the same full run. A repo-local count over `.artifacts/o4z-wasm-opt-debug.log` finds `18` occurrences of `code-pushing`, not just the one top-level slot.

That matters because it confirms the nested rerun story is real for this pass too.

## Nested reruns

`opt-utils.h` shows that Binaryen’s `optimizeAfterInlining(...)` helper prepends `precompute-propagate` and then reruns the default function optimization pipeline on touched functions.

That means `code-pushing` can reappear under optimizing passes like:

- `dae-optimizing`
- `inlining-optimizing`

The saved `.artifacts/o4z-wasm-opt-debug.log` matches that expectation: the repeated `precompute-propagate -> code-pushing -> tuple-optimization` subsequences are visible in the same full run.

For Starshine parity, the durable scheduler lesson is:

- the top-level `code-pushing` slot matters
- the nested rerun sites matter too
- the pass’s exact neighbors (`precompute`, `tuple-optimization`, `simplify-locals-nostructure`) are part of its meaning, not just bookkeeping

## What the pass is actually optimizing

The source comment in `CodePushing.cpp` gives the core intuition.

Binaryen wants to take work that currently happens in a common prefix and sink it into the branch-local region where it is actually needed.

A beginner-friendly mental model is:

- if an expression is only useful after control flow splits,
- executing it before the split may do unnecessary work on paths that never use it,
- so duplicate it into the places that actually use it,
- but only if doing so is safe and not too expensive.

That still needs several corrections to be fully honest:

- Binaryen does not search arbitrary CFGs for all such opportunities.
- It only works with a contiguous block suffix that it can reason about cheaply.
- It has a separate special case for `if`.
- It requires effect invalidation checks throughout the scan.
- It uses a real cost / benefit heuristic before rewriting.
- It refinalizes after rewriting because types and block shapes may change.

So the pass is best understood as **structured suffix sinking**, not as generic downward motion.

## Actual implementation structure

## 1. Pass shape

`CodePushing` is a `WalkerPass<PostWalker<CodePushing>>` and reports:

- `isFunctionParallel() == true`
- `create() -> std::make_unique<CodePushing>()`

So Binaryen treats it as a per-function pass that can run across functions in parallel.

The post-walk choice matters because the pass wants inner structures already simplified before it decides whether an outer block now has a sinkable suffix.

## 2. Two sink families live in one pass

The most important implementation split is between two destination families.

### Family A: generic control-flow segments

This is the `optimizeSegment(...)` path.

It looks at a block child that follows the current candidate suffix and asks whether some suffix of `pushable` can be cloned into the relevant downstream segments found by `BranchSeeker`.

This is the family used for branchy `block` / `br` / `br_table` style shapes in the main `code-pushing.wast` tests.

### Family B: direct sinking over `if`

This is the `optimizeIntoIf(...)` path.

It has its own rules because `if` introduces a very different question:

- sink into `then`
- sink into `else`
- sink into both arms
- or sink only into the single reachable arm when the other is already `unreachable`

A future Starshine port should not blur those two families into one vague “move code deeper” helper.

## 3. The scan is block-local and contiguous

The pass does not pull together disjoint expressions from across a block.

Inside a block scan, it maintains a current contiguous candidate segment, usually described in the source with containers like:

- `pushable`
- `values`
- `neededByBlock`

The durable contract is:

- only a suffix of the current contiguous candidate segment can move
- if a later child invalidates tracked candidate values, the segment boundary breaks
- the pass then starts a new candidate region from what remains movable

That is a major reason the implementation stays cheap and structured.

## 4. `values` and invalidation are the hidden core

While scanning the block, the pass keeps a set of currently movable candidate expressions together with enough effect information to ask whether the next child invalidates them.

When the next child arrives, Binaryen performs a shallow effect analysis and asks, in effect:

- does this child read something a candidate writes?
- write something a candidate reads?
- transfer control flow in a way that breaks the reasoning?
- introduce trap / side-effect / EH concerns that make earlier motion unsafe?

If the answer is yes for a candidate, that candidate is removed from the live `values` set. If that invalidation empties or breaks the current segment, the pass resets the candidate suffix boundary.

This is why the pass is safer than a naive suffix matcher.

It is constantly re-checking that the expressions it hopes to sink are still movable through what comes next.

## 5. `BranchSeeker` finds the generic sink destinations

For the generic control-flow family, `BranchSeeker` is the key helper inside `CodePushing.cpp`.

Conceptually it walks the following control-flow child and records the downstream segments where the pushed suffix would need to be appended.

Important durable facts from the source:

- it looks at branches to targets associated with the immediate child segments it is analyzing
- it can also treat fallthrough as a segment endpoint
- it reasons about branch destinations using the block-child structure, not a whole CFG graph solver
- it has special handling for block shapes whose last child carries the block’s concrete type

The broad beginner takeaway is:

- Binaryen does not say “push into any path from here”
- it says “push into these specific branch / fallthrough segments that this following structured control-flow node exposes”

## 6. `optimizeSegment(...)` chooses a suffix, not an arbitrary subset

Once `BranchSeeker` has produced candidate target segments, `optimizeSegment(...)` walks backward over the current `pushable` region.

For each possible suffix boundary, it asks:

- is this suffix still valid for every target segment?
- does each target segment actually use the result it needs?
- what is the size / execution tradeoff if we duplicate this suffix there?

This is another place where the real contract is narrower than the pass name suggests.

Binaryen is not searching for arbitrary best subsets.
It is evaluating **suffixes** of a single contiguous region.

## 7. The profitability model is simple but real

The source comments in `optimizeSegment(...)` are explicit that the pass uses a heuristic, not just a correctness check.

Key durable facts:

- it computes a `full` cost for the whole pushed suffix
- it computes a `cost` that can be discounted when the control-flow structure already branches all the way out, because then the original code disappears instead of being both kept and duplicated
- it computes a `benefit` from shrinking or simplifying the surrounding control-flow shape
- it subtracts `executed` cost from the benefit to avoid overestimating wins in cases where sinking may cause more total execution, especially in loops
- it requires `benefit > cost` before it rewrites

This is important for porting.

A correct-but-heuristic-blind port would still be an inaccurate Binaryen port, because it would duplicate code in places upstream deliberately skips.

## 8. The `if` path has stricter special rules

`optimizeIntoIf(...)` is where the pass becomes easiest to misunderstand.

### Case 1: one arm is `unreachable`

If one `if` arm is already `unreachable`, Binaryen can sink the suffix into the one reachable arm.

Why this is easier:

- it does not need to duplicate across two live arms
- it is closer to postponing the work until the one path that actually continues

This is the reason some apparently effectful or trap-sensitive shapes can still sink into a single reachable arm even though the general two-arm rules are much stricter.

### Case 2: both arms are reachable

If both arms are reachable, Binaryen immediately narrows the legal space.

Important source-enforced rules:

- the `if` itself must not have a concrete result type
- the candidate segment must not transfer control flow
- the candidate segment must not call
- it must not have other side effects
- it must not throw
- it must not read or write mutable globals
- it must not read or write tables or memory
- it must not trap under the default safety settings
- at least one arm must actually use the pushed value

Then Binaryen may sink into:

- both arms if both use the value
- only `then` if only `then` uses it
- only `else` if only `else` uses it

And it may add `drop(...)` wrappers where needed to preserve statement-like structure when only one arm consumes the value.

The critical beginner lesson is:

- two-arm `if` sinking is deliberately **much** purer and stricter than the generic “one arm unreachable” case

## 9. Result-use checks are part of correctness, not just profitability

The pass repeatedly checks whether the result of the current candidate expression is actually used in the downstream segment or arm.

That is why several tests keep apparently movable pure computations in place:

- if the result is still used after the control-flow structure,
- or if only some internal part of the downstream structure uses it in a way the pass does not model,
- sinking would be wrong or incomplete.

This is one of the easiest places to accidentally overgeneralize the pass during a port.

## 10. Rewriting is handled by `Pusher`

When Binaryen commits to a rewrite, the actual cloning and insertion work is done by `Pusher`.

Conceptually it:

- clones the selected suffix into each chosen target segment or `if` arm
- removes the original copy from the old block prefix
- preserves the remaining prefix / control-flow structure
- cleans up now-empty or singleton block shapes where possible

The key durable takeaway is that the pass does **structural surgery**, not just local instruction substitution.

It may change:

- block child lists
- `if` arm contents
- whether a surrounding block remains necessary
- the exact types of surrounding expressions after motion

## 11. `ReFinalize` is part of the contract

After these rewrites, `CodePushing.cpp` uses `ReFinalize` to rebuild expression and block types.

This matters for at least three families:

- pushing through or into ref-typed code
- pushing around `if` / block shapes that change from value-carrying to statement-like
- pushing through EH or branchy code where `unreachable` and concrete-type interactions matter

A future Starshine port must preserve that refinalization step instead of assuming old outer types remain valid automatically.

## Helper dependency map

## `EffectAnalyzer` and `ShallowEffectAnalyzer`

This is the single most important helper family for understanding `code-pushing`.

The pass uses shallow effect information during scanning and deeper effect information for some `if` decisions.

Practical role:

- decide whether a later child invalidates currently movable expressions
- decide whether a candidate segment is pure enough for the strict two-arm `if` case
- respect option-sensitive trap behavior (`ignore-implicit-traps`, `traps-never-happen`)

Without this effect model, the pass would very quickly become unsound.

## `Builder`

Used to construct replacement structure, especially `drop(...)` / `if` / block wrappers during rewriting.

## `ReFinalize`

Mandatory post-rewrite repair step.

## `opt-utils.h`

Not part of the inner algorithm, but essential for the scheduler story because it explains the repeated nested reruns visible in the saved Binaryen log.

## Tests

The shipped lit tests are unusually important for this pass because they expose the intended boundary between:

- default-safe pushing
- one-arm `if` sinking
- two-arm `if` sinking
- GC-sensitive pushing
- EH-sensitive non-pushing
- option-sensitive trap relaxation

For this dossier, the most informative test files were:

- `code-pushing.wast`
- `code-pushing_into_if.wast`
- `code-pushing_ignore-implicit-traps.wast`
- `code-pushing_tnh.wast`
- `code-pushing-gc.wast`
- `code-pushing-eh.wast`

## Important WAT / IR shape families

## Positive family 1: pure arithmetic or local work used only inside later control flow

This is the core success case.

A common-prefix pure computation sits before an `if` or branchy block, but all real consumers are in the later control-dependent region.

Binaryen can duplicate the computation into the relevant arms/segments and delete the old prefix copy.

## Positive family 2: push into both reachable `if` arms

The `code-pushing_into_if.wast` tests show the clean two-arm case:

- the `if` has no concrete result type
- the candidate work is pure enough
- both arms use the value

This is the easiest beginner mental picture of the pass, but it is only one subfamily.

## Positive family 3: push into exactly one arm

The same `into_if` tests show that Binaryen can also sink into just one arm when:

- only one arm uses the value
- the surrounding structure still allows that move safely

This is a good reminder that the pass is not just “duplicate into all arms.”

## Positive family 4: one arm unreachable

This is a major special case.

If one arm is already `unreachable`, Binaryen can often sink the code into the one reachable arm even when the general two-arm rules would reject duplication.

This family is worth documenting separately because a naive explanation of the pass often misses it.

## Positive family 5: branchy block / switch-style pushing

The main `code-pushing.wast` tests show the non-`if` structured family.

Here Binaryen uses `BranchSeeker` and target segments rather than the direct `if` arm logic.

This is the family that makes the pass feel broader than “sink into an `if`,” but it still stays within structured block segments rather than arbitrary CFG regions.

## Positive family 6: GC ref operations can participate

`code-pushing-gc.wast` shows that GC-oriented operations like:

- `struct.get`
- `array.get`
- `ref.cast`
- `ref.as_non_null`

can be pushed under the same general effect rules when they are in safe control-dependent shapes.

This is important because it means the pass is not restricted to integer arithmetic or locals.

## Negative family 1: value still used after the control-flow separator

If the result of the candidate expression is still needed after the `if` or other separator, Binaryen cannot simply sink it into one inner region.

The `into_if` tests make this explicit.

This is a core “why didn’t it move?” explanation for future users.

## Negative family 2: value-typed `if` blocks the general two-arm path

When both arms are reachable, `optimizeIntoIf(...)` rejects `if` expressions with a concrete result type.

That means “the code is pure” is not enough.
The outer typing shape also matters.

## Negative family 3: calls, side effects, throws, memory, table, mutable globals

For the strict two-arm `if` family, Binaryen refuses candidate segments with these effects.

This is the pass’s biggest “sounds simple, but isn’t” contract.

Many programmers expect a pure-looking load or cast to move automatically; Binaryen only does that when the full effect model says it is okay.

## Negative family 4: trap sensitivity under default settings

Under default safety settings, trap-capable operations are a barrier for the strict two-arm `if` sink path.

The `ignore-implicit-traps` and `traps-never-happen` tests exist precisely because changing those pass options changes what counts as a barrier.

## Negative family 5: EH-sensitive structure

`code-pushing-eh.wast` exists because EH structure makes motion especially easy to get wrong.

The pass must not misplace or reorder semantics around:

- `try`
- `catch`
- `pop`
- `throw`
- values whose availability depends on EH structure

The durable lesson is not “EH is never optimized.”
It is:

- EH is a major source of bailout shapes,
- and any port needs explicit EH coverage rather than hoping generic control-flow logic is enough.

## Negative family 6: not profitable enough

Even when a move is semantically legal, Binaryen can still skip it because the local heuristic says the duplication cost is not worth the win.

This matters most in:

- small expressions
- loops
- shapes where pushing would still execute the duplicated work too often

## Pass interactions

## Why it sits before `tuple-optimization`

The repo’s tuple docs already record that Binaryen wants the exact neighborhood:

- `precompute`
- `code-pushing`
- `tuple-optimization`
- `simplify-locals-nostructure`

That ordering is not cosmetic.

A sunk branch-local prefix can expose cleaner tuple-local traffic for the tuple pass, and tuple cleanup can then hand an easier body to the early local simplifier.

So `code-pushing` is one of the missing upstream neighbors that still matter for honest preset parity around tuple-opt.

## Why it sits after `precompute`

The source comment in `CodePushing.cpp` says the pass should run after at least `optimize-instructions` because earlier simplification can already remove some work. In practice the default neighborhood also puts `precompute` immediately before it.

That means `code-pushing` generally sees:

- simpler child expressions
- fewer obviously redundant prefixes
- a better chance that any remaining movable segment is actually worth duplicating

## Why `simplify-locals-nostructure` comes after it

If code is sunk into more local branches first, the early no-structure local cleanup can work on a body where branch-local temporary traffic is already closer to where it matters.

That helps explain why the scheduler neighborhood is a genuine part of the semantics, not just a list ordering accident.

## What the pass is **not**

A future Starshine port should avoid accidentally broadening this pass beyond upstream behavior.

`code-pushing` is not:

- arbitrary CFG-wide sinking
- generic LICM in reverse
- generic expression duplication for all profitable shapes
- a substitute for tuple optimization
- a substitute for simplify-locals
- a substitute for branch cleanup
- a proof that all pure code should move under an `if`

The real Binaryen contract is narrower and more structure-driven than the name suggests.

## Easy misunderstandings to avoid

1. **“It pushes any pure code deeper.”**
   - No. It only considers a contiguous block suffix and specific downstream segments.
2. **“If both `if` arms use a value, it always sinks.”**
   - No. The two-arm `if` path has strict purity and type-shape requirements.
3. **“If one arm is unreachable, the same strict rules apply.”**
   - No. That one-arm-reachable case is deliberately more permissive.
4. **“This is basically CSE.”**
   - No. It duplicates code to make execution more path-specific.
5. **“The pass name implies generic pushdown over all control flow.”**
   - No. The structured segment model is the real scope.
6. **“Ignoring traps is just a test harness quirk.”**
   - No. The dedicated tests show option-sensitive behavior is part of the intended contract.

## Future Starshine port contract

If Starshine ports `code-pushing`, preserve these facts first:

1. function-parallel, post-walk structure
2. block-local contiguous-segment model
3. separate generic-segment and `if`-specific logic
4. effect-based invalidation during scanning
5. strict two-arm `if` purity rules
6. one-arm-unreachable special case
7. profitability gating, not correctness-only rewriting
8. mandatory refinalization after rewrites
9. scheduler placement after `precompute` and before `tuple-optimization` / `simplify-locals-nostructure`
10. nested rerun behavior under optimizing passes
11. explicit GC and EH coverage in tests
12. option-sensitive trap behavior coverage (`ignore-implicit-traps`, `traps-never-happen`)

Those are the durable upstream-level truths.

## Uncertainty / inference notes

- I directly inspected `CodePushing.cpp`, the pass schedule surface, `effects.h`, and the shipped lit tests.
- I did **not** fully trace every option-plumbing line for `ignoreImplicitTraps` and `trapsNeverHappen` through `effects.h` in this run. The exact option-sensitive barrier story is therefore partly grounded in the test files and the visible invalidation comments, not only in a full line-by-line audit of the option constructor path.
- I also did not attempt to catalog every single positive case in `code-pushing.wast`; the living dossier focuses on the recurring algorithm families and the tests that best explain them.

## Suggested living-page breakdown

This raw note should be filed into living docs as:

- `docs/wiki/binaryen/passes/code-pushing/index.md`
- `docs/wiki/binaryen/passes/code-pushing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/code-pushing/segment-selection-and-barriers.md`
- `docs/wiki/binaryen/passes/code-pushing/wat-shapes.md`

## Sources

### Local repo sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tuple-optimization/index.md`
- `docs/wiki/binaryen/passes/tuple-optimization/scheduler-and-gates.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `agent-todo.md`

### Official Binaryen `version_129` sources

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_into_if.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_ignore-implicit-traps.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_tnh.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-eh.wast>
