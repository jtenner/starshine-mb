# 0130 - `vacuum` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: deepen the currently shallow `vacuum` pass docs using official Binaryen `version_129` sources, shipped tests, the repo's canonical no-DWARF scheduler note, the local `VQ` backlog slice, and the saved generated-artifact `-O4z` audit.

## Why this pass

- `docs/wiki/binaryen/passes/tracker.md` had just promoted `vacuum` to the top suggested next target once the last unimplemented saved-audit `none` dossier was cleared.
- Unlike the earlier late-tail campaign targets, `vacuum` is already **implemented** in Starshine, but only had a landing page.
- That made it the most useful next pass to deepen because it sits at a very busy cleanup handoff in both upstream Binaryen and this repo's current optimize scheduler.
- The local backlog already has a dedicated slice:
  - `agent-todo.md` -> `#### VQ - Vacuum`
  - `[VQ]001 - Cleanup Semantics Audit`
  - `[VQ]002 - Repeated-Slot Regression Matrix`
- The canonical no-DWARF `-O` / `-Os` page shows `vacuum` four times in the default function pipeline.
- The saved generated-artifact `-O4z` audit also shows `vacuum` four times at real top-level observed Binaryen slots:
  - slot `23`
  - slot `33`
  - slot `37`
  - slot `47`
- The saved Binaryen debug log shows the pass is not just a one-off top-level detail:
  - the first four top-level `vacuum` executions took about `0.429038`, `0.212144`, `0.0617022`, and `0.099056` seconds
  - a direct count of `running pass: vacuum` lines in `.artifacts/o4z-wasm-opt-debug.log` is `72`, which reflects many nested optimizing reruns on touched functions
- The current in-tree Starshine implementation is much narrower than upstream Binaryen.
  - Starshine recursively deletes explicit `nop` region entries.
  - Binaryen `vacuum` does much more: effect-aware unused-result pruning, if/loop/drop/try special cases, traps-never-happen cleanup, branch-hint flipping, and whole-function no-oping when nothing observable remains.

So `vacuum` is both high-value and easy to misunderstand:

- it sounds tiny
- it really is small compared to DCE or simplify-locals
- but it is still much broader than “strip nops.”

## Local source material

### Repo scheduler / backlog / audit sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/vacuum/index.md`
- `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `docs/wiki/raw/research/0106-2026-04-18-generated-o4z-vacuum-slot23-retired-by-carrier-wrapper-guard.md`
- `docs/wiki/raw/research/0107-2026-04-18-generated-o4z-vacuum-slot33-retired-by-validator-escape-fix.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize_test.mbt`

### Local Starshine implementation files

- `src/passes/optimize.mbt`
  - registry summary: `Remove \`nop\` roots and region entries through hot IR cleanup.`
- `src/passes/pass_manager.mbt`
  - `hot_pass_remove_region_nops(...)`
  - hot-pass dispatch branch for `"vacuum"`
  - `vacuum`-specific writeback validation guard reusing `run_hot_pipeline_precompute_writeback_validation_error(...)`
- `src/passes/optimize_test.mbt`
  - current in-tree regression for the `simplify-locals -> vacuum` late cleanup pair

## Official Binaryen `version_129` sources

### Main implementation and scheduler

- `src/passes/Vacuum.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Vacuum.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/passes.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>

### Helper headers `Vacuum.cpp` depends on directly

- `src/ir/branch-hints.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-hints.h>
- `src/ir/drop.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/drop.h>

### Shipped test surface reviewed for this note

- `test/lit/passes/vacuum-func.wast`
- `test/lit/passes/vacuum-removable-if-unused.wast`
- `test/lit/passes/vacuum-removable-if-unused-func.wast`
- `test/lit/passes/vacuum-branch-hints.wast`
- `test/lit/passes/vacuum-global-effects.wast`
- `test/lit/passes/vacuum-gc.wast`
- `test/lit/passes/vacuum-gc-atomics.wast`
- `test/lit/passes/vacuum-strings.wast`
- `test/lit/passes/vacuum-desc.wast`
- `test/lit/passes/vacuum-eh.wast`
- `test/lit/passes/vacuum-eh-pop.wast`
- `test/lit/passes/vacuum-eh-legacy.wast`
- `test/lit/passes/vacuum-intrinsics.wast`
- `test/lit/passes/vacuum-tnh.wast`
- `test/lit/passes/vacuum-tnh-mvp.wast`
- `test/lit/passes/vacuum_all-features.wast`

Representative URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-func.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-eh.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-strings.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-gc-atomics.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-desc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-tnh.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum_all-features.wast>

## Freshness and correction check

I did a narrow direct source check against current upstream `main` plus the Chromium commit links already referenced in the repo.

### What I checked directly

- GitHub `main` `src/passes/Vacuum.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Vacuum.cpp>
- Chromium commit `f284d54ef60a5b6e6c33b4c1f4d4b423f7a6b1c3`
  - <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/f284d54ef60a5b6e6c33b4c1f4d4b423f7a6b1c3%5E%21/>
- Chromium commit `9ee4a25ee15ab53e796cb0b3f320cafa2622c407`
  - <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/9ee4a25ee15ab53e796cb0b3f320cafa2622c407%5E%21/>

### Durable correction

A repo-local note from 2026-04-18 had conflated two same-day Chromium commits.

The fresh check shows:

- `f284d54...` is the actual `Vacuum.cpp` change that adds the function-level `FindAll<Unreachable>` safeguard so `vacuum` does not nop away explicit `unreachable` in the whole-function cleanup case.
- `9ee4a25...` is **not** a `Vacuum` change.
  - It edits `RemoveUnusedBrs.cpp`.
- The `f284d54...` `Vacuum` change is already present in `version_129`.
- Current GitHub `main` still matches `version_129` in substance for `Vacuum.cpp`; the only visible diff I found in a direct raw-file comparison was the comment typo `vaccuming` -> `vacuuming`.

So the durable wiki correction is:

- explicit-`unreachable` preservation is **already part of the `version_129` oracle** for `vacuum`
- it is not a newer post-`version_129` drift fact
- and the previously cited `9ee4...` hash belongs to `RemoveUnusedBrs`, not `Vacuum`

## Fast answer

Binaryen `vacuum` is a function-parallel tree cleanup pass that removes obviously unnecessary code when the result is unused, the type can still be kept valid, and observable effects are preserved.

That sounds obvious, but the actual contract is sharper:

1. it walks the AST bottom-up
2. it has one generic helper for “this result is unused; can I replace the node with nothing, one child, or a dropped-children bundle?”
3. it has special visitor logic for:
   - `block`
   - `if`
   - `loop`
   - `drop`
   - `try`
   - `try_table`
   - the function body itself
4. it re-finalizes the function after all those rewrites

A good beginner mental model is:

- `vacuum` is Binaryen's cleanup crew for small leftover wrappers, empty structure, and now-dead fallthrough values,
- but it still obeys effects, type correctness, branch payload structure, and explicit `unreachable` propagation.

It is **not**:

- just a `nop` sweeper
- a CFG or liveness pass
- a whole dead-code-elimination fixpoint
- a pass that may freely remove anything that traps
- a pass that always simplifies `try_table` to the smallest possible equivalent form

## Where the pass runs

## Registered surface

`pass.cpp` registers:

- `vacuum`
  - description: `removes obviously unneeded code`

`passes.h` exports:

- `createVacuumPass()`

## Canonical no-DWARF scheduler placement

In `version_129` `pass.cpp`, the default function optimization path inserts `vacuum` four times in the no-DWARF `-O` / `-Os` path:

1. after `simplify-locals-nostructure`
   - source comment: `previous pass creates garbage`
2. after `simplify-locals`
3. after the `coalesce-locals -> reorder-locals` cleanup cluster
4. after `rse`
   - source comment: `just to be safe`

That matches the local canonical note in `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`.

## Nested reruns still matter

`opt-utils.h` shows that optimizing boundary passes rerun `addDefaultFunctionOptimizationPasses()` on touched functions inside `optimizeAfterInlining(...)`.

So `vacuum` is not just “four slots in a list.”

It is also:

- part of the nested cleanup bundle that reappears after inlining-like whole-module work

The saved generated-artifact `-O4z` debug log reflects that directly:

- `vacuum` appears at top-level slots `23`, `33`, `37`, and `47`
- but `running pass: vacuum` appears `72` total times in the full debug log

## Actual implementation structure

## 1. `doWalkFunction(...)`: walk first, `ReFinalize` second

The pass class is:

- `struct Vacuum : public WalkerPass<ExpressionStackWalker<Vacuum>>`
- `isFunctionParallel() == true`

Its function-level driver is tiny but important:

- walk the function body
- then call `ReFinalize().walkFunctionInModule(...)`

That `ReFinalize` step is part of the real contract.

Why it matters:

- `vacuum` does not just delete nodes
- it also changes types and structure around:
  - block fallthroughs
  - `if` arms
  - dropped values
  - EH / `pop` situations
  - GC casts whose nullability can become tighter after wrapper removal

The shipped tests `vacuum-eh-pop.wast`, `vacuum-gc.wast`, and `vacuum-global-effects.wast` all reinforce that correctness point.

## 2. The generic `optimize(...)` helper is the heart of the pass

The central helper is:

- `Expression* optimize(Expression* curr, bool resultUsed, bool typeMatters)`

It does **not** blindly delete unused nodes.

Its important rules are:

- if the node type is `none`, force `typeMatters = true`
- if the node type is `unreachable`, do nothing
  - DCE is expected to handle real unreachable cleanup later
- if the result is actually used, do nothing
- special nodes are delegated to their visitor methods instead of optimized here:
  - `Drop`
  - `Block`
  - `If`
  - `Loop`
  - `Try`
  - `TryTable`
- otherwise, ask whether the parent itself must stay via `mustKeepUnusedParent(...)`
- then collect children with unremovable side effects via full `EffectAnalyzer`

The outcomes are:

- no children with unremovable side effects -> return `nullptr`
  - the whole expression can disappear
- exactly one child with unremovable side effects -> recurse into that child
  - this is how wrappers like a dropped pure unary around an effectful child collapse inward
- multiple children with unremovable side effects -> try `getDroppedChildrenAndAppend(...)`
  - if the result type is defaultable, append a dummy zero of the right type
  - otherwise, give up and keep the parent

That is the main reason `vacuum` is more than a `nop` pass.

It is really an **unused-result, effect-aware wrapper eliminator**.

## 3. `mustKeepUnusedParent(...)` is shallower than the child scan

`mustKeepUnusedParent(...)` does two things:

1. special-case `call`
   - if the call is annotated `removableIfUnused`, the call itself may be removed without even consulting ordinary effects
2. otherwise run `ShallowEffectAnalyzer`

That split matters.

The pass distinguishes:

- the parent node's own observable behavior
- the behavior of its children

This is how `vacuum` can remove a dropped `call.without.effects` wrapper or a call marked `@binaryen.removable.if.unused`, yet still keep effectful operands when needed.

## 4. `visitBlock(...)` is where most cleanup shapes happen

`visitBlock(...)` has three major jobs.

### A. TNH backward scan for code definitely heading into an explicit trap

When `trapsNeverHappen` is enabled and the block has at least two items, Binaryen scans backward from an explicit `unreachable`.

It can turn preceding code into `nop` while `headingToTrap` remains true.

But it stops when a node:

- transfers control flow
- calls
- may not return
- has a dangling `pop`

That is a deliberately conservative barrier model.

Important consequence:

- TNH can delete trap-only residue before an explicit `unreachable`
- but it will not cross calls, control transfers, infinite-loop-like behavior, or structural `pop` requirements

### B. Per-child `optimize(...)` with used-last-child handling

Then it runs `optimize(...)` over each block child.

The last element is treated specially:

- it may still be used as the block's result

If an unused child optimizes to nothing:

- a final concrete child cannot simply vanish
- if `LiteralUtils::canMakeZero(childType)` is true, Binaryen substitutes a zero literal of that type
- if not, it keeps the original child
- if the child type is `unreachable`, it keeps it for DCE later instead of deleting it here

This is an important type-safety rule.

### C. Post-compression block simplification

After compressing away skipped children:

- if a surviving child is `unreachable`, later siblings are truncated as dead
- then `BlockUtils::simplifyToContents(...)` is applied

This is how blocks shrink to:

- nothing
- one child
- or simpler contents

## 5. `visitIf(...)` is a bundle of small, very non-random rewrites

`visitIf(...)` handles several families.

### Constant or unreachable condition

- constant condition -> select the reachable arm immediately
- unreachable condition -> replace the entire `if` with the condition

### TNH unreachable-arm cleanup

When TNH is enabled and the `if` itself is not `unreachable`:

- if one arm is definitely `unreachable`, Binaryen can replace the `if` with:
  - `drop(condition)`
  - followed by the other arm, if any

But it deliberately avoids the case where both arms are unreachable.

That case is left for DCE.

### Empty-arm cleanup and branch-hint preservation

If there is an `else` arm:

- `else = nop` -> just remove the `else`
- `then = nop` and `else` non-empty -> flip the condition with `eqz`, move the old `else` to `then`, drop the `else`, and call `BranchHints::flip(...)`

That branch-hint flip is an easy detail to miss, but the dedicated `vacuum-branch-hints.wast` test exists to lock it in.

### Both arms are drops of the same type

If both arms are `drop`s whose inner values have the same type:

- Binaryen converts the `if` to an `if` of the underlying values
- then wraps the whole thing in one `drop`

That removes redundant outer structure without changing semantics.

### No-`else` empty body

If there is no `else` and `then` is `nop`:

- replace the whole `if` with `drop(condition)`

## 6. `visitLoop(...)` is tiny and intentionally narrow

`visitLoop(...)` only does one thing directly:

- if the loop body is `nop`, the loop becomes `nop`

That is a good example of what `vacuum` is **not** trying to do.

It is not a general loop reasoning pass.

The `vacuum-tnh.wast` tests reinforce that loops that may be infinite or contain non-removable effects stay conservative even in TNH mode.

## 7. `visitDrop(...)` is the other major hot spot

`visitDrop(...)` is where the generic helper and some very practical special cases meet.

### First: optimize the dropped value

- `curr->value = optimize(curr->value, false, false)`
- if that returns `nullptr`, the entire `drop` becomes `nop`

### Drop of tee -> set

If the optimized value is a `local.tee`:

- `vacuum` turns it into an ordinary `local.set`

That is a concrete rewrite a future Starshine port must preserve.

### Remove the whole drop if it no longer has unremovable side effects

If the `drop` expression itself now has no unremovable side effects:

- `drop` becomes `nop`

### Pop a dropped block result when safe

If the dropped value is a `block` whose last item computes the block result:

- optimize that last item with `resultUsed = false`
- if it disappears, check whether named branches still need the block result via `BranchUtils::BranchSeeker`
- if no such carried-value branch dependency remains, pop the last item and simplify the block

This is a very important safety edge.

The pass is not allowed to remove a block result that branches still target.

### Sink a `drop` into the live arm of an `if`

If the dropped value is an `if` with a concrete result type and one arm ends in `unreachable`:

- reuse the same `drop` around the concrete arm
- make the `if` itself `none`

The source comment explains why:

- it can expose branch cleanup opportunities for later passes

## 8. `visitTry(...)` and `visitTryTable(...)` are intentionally asymmetric

### `visitTry(...)`

If the try body cannot throw:

- replace the whole `try` with the body

If the try body can throw, but:

- the `try` type is `none`
- it has a `catch_all`
- the entire `try` has no unremovable side effects

then:

- the whole `try` becomes `nop`

### `visitTryTable(...)`

If the try_table body cannot throw:

- replace the whole `try_table` with the body

But `vacuum` does **not** do the analogous “trivial catch-all of throw” cleanup for general `try_table` bodies.

The shipped `vacuum-eh.wast` test says this explicitly:

- Binaryen leaves that optimization to `remove-unused-brs`, which can reason about turning the `throw` into a `br`

That asymmetry is real and easy to over-assume away.

## 9. `visitFunction(...)` contains the pass's largest cleanup and its easiest-to-miss safeguard

At function scope, `vacuum` first tries:

- `optimize(curr->body, curr->getResults() != Type::none, true)`

Then, if the function returns `none`, it does a broader whole-function check.

If the whole function has no unremovable side effects:

- it may nop the body entirely

But there is an extra TNH safeguard.

If the only reason the body is removable is trap-removability in TNH mode:

- Binaryen checks `FindAll<Unreachable>(curr->body)`
- if there is an explicit `unreachable`, it **refuses** to nop the whole function body

Why:

- replacing explicit `unreachable` with `nop` is valid in isolation
- but it prevents unreachability from propagating outward to callers and later passes

This explicit-unreachable preservation is already in `version_129`.

It is not merely a newer trunk-only drift note.

## Helper dependencies that matter

## `EffectAnalyzer` and `ShallowEffectAnalyzer`

These are the core safety filters.

They explain why `vacuum` can distinguish:

- removable pure wrappers
- trap-only behavior under options like TNH
- non-removable calls
- synchronization-sensitive GC atomic operations
- string operations that trap versus ones that do not

The pass depends on them much more than on any CFG-style analysis.

## `Intrinsics`

Needed for `removableIfUnused` call annotations.

This is how Binaryen makes certain dropped calls disappear while still preserving effectful operands.

## `LiteralUtils`

Needed for dummy replacement values when an unused concrete result cannot simply disappear.

This is central to the `typeMatters` story.

## `getDroppedChildrenAndAppend(...)`

This helper is what lets `vacuum` keep unconditional effectful children while deleting their now-useless parent.

It is one of the key reasons the pass is more than “turn dropped pure things into nops.”

## `BranchUtils::BranchSeeker`

Needed when deciding whether it is safe to pop the last value out of a dropped result block.

## `BranchHints::flip(...)`

Needed when a `then = nop, else = body` shape is rewritten by flipping the condition.

## `BlockUtils::simplifyToContents(...)`

Needed for the final trivial-block collapse after child cleanup.

## `ReFinalize`

Needed after all the tree surgery.

Without it, several GC / EH / type refinements would be unsafe or invalid.

## `FindAll<Unreachable>`

Needed for the function-level TNH safeguard that preserves explicit `unreachable` propagation.

## What the shipped tests teach that the source alone is easy to miss

## Whole-function cleanup is broader than “remove dead expressions”

`vacuum-func.wast` shows:

- local sets and even `return` can disappear in a void function when nothing observable remains
- but a result-returning function is intentionally left alone at this stage

## Call annotations and global effect facts materially change results

`vacuum-removable-if-unused*.wast` and `vacuum-global-effects.wast` show:

- a dropped call can disappear if annotated removable-if-unused
- a pass like `--generate-global-effects` can make later `vacuum` cleanup stronger

## Branch-hint metadata must track `if` flipping

`vacuum-branch-hints.wast` locks this in.

## Trap-sensitive GC / string / descriptor / atomic operations are option-sensitive

The GC, string, descriptor, and TNH tests collectively show:

- `string.compare` may still need to stay when dropped because it can trap
- `string.eq` can disappear when dropped
- nullable `i31.get`, `ref.as_non_null`, and many casts are trap-sensitive by default
- some descriptor operations disappear only under `--ignore-implicit-traps` or `--traps-never-happen`
- atomic access on shared mutable data remains observable even when the result is dropped, while some unshared or immutable cases can disappear

Inference note:

- `Vacuum.cpp` itself only has explicit TNH branches.
- I infer from the source shape plus the lit tests that `--ignore-implicit-traps` changes `vacuum` behavior indirectly through the effect analyzers, not through a separate dedicated code path inside `Vacuum.cpp`.

## EH behavior is not “remove anything that looks obviously caught”

The EH tests show:

- `try` and `try_table` are not handled identically
- pop-sensitive rewrites rely on refinalization being correct
- `return_call*` inside caught `try_table` can make the surrounding `try_table` removable because the body returns before throwing
- trivial catch-all removal for `try_table` is intentionally deferred to `remove-unused-brs`

## What `vacuum` does not do

Binaryen `vacuum` does **not**:

- perform CFG or liveness analysis
- try to be a complete DCE pass
- remove ordinary explicit `unreachable` just because TNH is on
- delete calls merely because their results are dropped
- delete loops that may not return
- synthesize arbitrary replacement values for non-defaultable or non-zeroable types
- normalize all `try_table` catch-all-to-throw cases on its own
- replace the later cleanup passes that follow it in the scheduler

## Current Starshine comparison

Current Starshine `vacuum` is much narrower.

### What Starshine does today

`src/passes/pass_manager.mbt` implements:

- `hot_pass_remove_region_nops(...)`
  - recursively scan root / block / loop / if / try / try_table regions
  - remove explicit `HotOp::Nop` region entries

The registry summary in `src/passes/optimize.mbt` accurately describes **that** implementation:

- remove `nop` roots and region entries through hot IR cleanup

### What Starshine does not yet do

It does not yet model upstream Binaryen `vacuum` features such as:

- unused-result wrapper elimination via effect analysis
- constant / unreachable condition `if` cleanup
- `then` / `else` flipping with branch-hint updates
- loop-to-nop cleanup for empty loop bodies
- `drop(local.tee(...)) -> local.set(...)`
- result-block pop logic with branch-target safety
- `try` / `try_table` no-throw simplification
- TNH trap-path cleanup inside blocks and `if`s
- whole-function nopping based on observable effects
- explicit-unreachable preservation at function scope

### What Starshine already learned locally anyway

Even with the narrower semantics, the repo has already accumulated `vacuum`-specific operational knowledge:

- `optimize_test.mbt` locks a real `simplify-locals -> vacuum` late cleanup residue case
- `pass_manager.mbt` has a dedicated `vacuum` writeback-validation guard because earlier artifact corruption looked like a `vacuum` boundary failure even when the root cause lived elsewhere
- raw investigations `0106` and `0107` showed the retired slot-23 / slot-33 failures were replay-boundary symptoms, not evidence that upstream-style `vacuum` itself should synthesize typed carrier repairs

## Future Starshine port invariants

A future parity port must preserve at least these Binaryen contracts:

1. **type safety beats eagerness**
   - no removing an unused concrete value unless a valid replacement story exists
2. **explicit `unreachable` still propagates**
   - especially in the whole-function TNH case
3. **dropped tee becomes set**
4. **flipped `if` conditions also flip branch hints**
5. **named result blocks cannot lose carried values just because the outer drop disappeared**
6. **TNH cleanup stays conservative around calls, may-not-return, control transfer, and `pop`**
7. **`try` and `try_table` keep their current asymmetry unless a later Binaryen source change says otherwise**
8. **refinalization is mandatory after rewrite**

## Validation plan for future parity work

If the repo later expands Starshine `vacuum` toward Binaryen parity, the most useful signoff set will be:

- direct compare against Binaryen `version_129` for isolated `--vacuum`
- focused WAT families derived from the shipped tests above
- explicit TNH and ignore-implicit-traps lanes
- GC, strings, descriptors, atomics, and EH coverage
- saved-artifact replay on the four observed top-level `vacuum` slots
- nested-rerun replay once the relevant optimizing boundary passes exist in-tree

## Performance notes

`vacuum` is not one of the worst runtime offenders in the current local audit, but it is repeated often enough that cheapness matters.

Local saved-artifact evidence suggests:

- top-level `vacuum` slots are real but moderate-cost cleanup points
- nested reruns dominate the total execution count
- the pass's design staying local and effect-based, rather than CFG-wide, matches that repeated-cleanup role

## Open questions and uncertainty

- I did **not** audit every helper implementation detail inside `EffectAnalyzer`, `ShallowEffectAnalyzer`, or `BlockUtils` line-by-line for this note.
  - My claims about them are limited to what `Vacuum.cpp` directly relies on and what the shipped tests make observable.
- The exact `--ignore-implicit-traps` behavior is an inference from source structure plus tests, not from a dedicated `Vacuum.cpp` option branch.
- The repo's older raw notes `0106` and `0107` still contain the earlier misattributed Chromium hash because raw research notes are archival sources.
  - The living pages updated from this note should carry the corrected interpretation explicitly.

## Bottom line

Binaryen `vacuum` is a small but surprisingly rich cleanup pass.

Its real job is:

- prune unused results
- preserve effectful children
- keep types valid
- simplify blocks / ifs / drops / EH shapes
- exploit TNH conservatively
- and leave explicit `unreachable` available for later propagation

That is a much more accurate description than either of these shallow summaries:

- “just remove nops”
- “just run DCE later anyway”

Both miss behavior a future Starshine parity port must preserve.
