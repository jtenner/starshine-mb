# 0220 - `remove-unused-names` source-confirmation follow-up

## Status

- Date: 2026-04-21
- Type: Source-confirmation follow-up
- Scope: deepen the existing Binaryen `remove-unused-names` dossier with one compact implementation/test-map page, tighten the living docs around the real owner files and proof surface, and record that this deep implemented folder no longer lacks that compact source-confirmed home.

## Why this follow-up was justified

The tracker no longer had obvious `none` targets, and this thread had to avoid a long exclusion list that covered most of the recently refreshed dossiers.
`remove-unused-names` was still eligible under those rules.

It already had a strong beginner-facing dossier, but it still lacked one compact page answering a narrower recurring question:

- which upstream files actually own the pass contract, and
- which shipped tests directly prove the visible rewrite families?

That gap mattered because `remove-unused-names` is easy to mis-teach in two opposite directions:

- too small: “it just strips cosmetic labels”
- too vague: “it sort of flattens blocks somehow”

A compact source-confirmed implementation/test map is the cleanest way to keep both mistakes out of the living wiki.

## Repo and local sources re-read first

Per repo rules, I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- the existing `docs/wiki/binaryen/passes/remove-unused-names/` folder
- the local implementation/tests:
  - `src/passes/remove_unused_names.mbt`
  - `src/passes/remove_unused_names_test.mbt`
  - `src/passes/optimize.mbt`
  - `src/cmd/cmd_wbtest.mbt`

`agent-todo.md` has **no dedicated `remove-unused-names` / `RUN` implementation slice** today.
It mentions the pass only as part of larger ordered-prefix and scheduler notes.
That made the compact living source map more valuable, not less: without a dedicated backlog slice, the wiki is the main durable place to preserve the exact upstream owner/test split.

## Official Binaryen `version_129` sources reviewed

### Main implementation / registration / helpers

- `src/passes/RemoveUnusedNames.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedNames.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/ir/branch-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- `src/shared-constants.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/shared-constants.h>

### Shipped dedicated and neighboring pass tests reviewed

- `test/passes/remove-unused-names.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names.wast>
- `test/passes/remove-unused-names.txt`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names.txt>
- `test/passes/remove-unused-names_precompute.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_precompute.wast>
- `test/passes/remove-unused-names_precompute.txt`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_precompute.txt>
- `test/passes/remove-unused-names_vacuum.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_vacuum.wast>
- `test/passes/remove-unused-names_vacuum.txt`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_vacuum.txt>
- `test/passes/remove-unused-names_vacuum_ignore-implicit-traps.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_vacuum_ignore-implicit-traps.wast>
- `test/passes/remove-unused-names_vacuum_ignore-implicit-traps.txt`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_vacuum_ignore-implicit-traps.txt>
- `test/passes/remove-unused-names_remove-unused-brs_vacuum.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_remove-unused-brs_vacuum.wast>
- `test/passes/remove-unused-names_remove-unused-brs_vacuum.txt`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_remove-unused-brs_vacuum.txt>
- `test/passes/remove-unused-names_code-folding.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_code-folding.wast>
- `test/passes/remove-unused-names_code-folding.txt`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_code-folding.txt>
- `test/passes/remove-unused-names_merge-blocks_all-features.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_merge-blocks_all-features.wast>
- `test/passes/remove-unused-names_merge-blocks_all-features.txt`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_merge-blocks_all-features.txt>

## Source-confirmed implementation structure

## 1. `RemoveUnusedNames.cpp` really is almost the entire pass

The compact owner answer is now clear:

- `src/passes/RemoveUnusedNames.cpp` owns nearly all of the real pass behavior.

The file is tiny and very explicit.
It owns:

- the pass type itself
  - `WalkerPass<PostWalker<RemoveUnusedNames, UnifiedExpressionVisitor<...>>>`
- `isFunctionParallel() == true`
- `requiresNonNullableLocalFixups() == false`
- the single important state map
  - `std::map<Name, std::set<Expression*>> branchesSeen`
- `visitExpression(...)` for collecting scope-name uses
- `handleBreakTarget(...)` for dead-label clearing or map-entry retirement
- `visitBlock(...)` for one-child same-type parent/child block merges plus branch retargeting
- `visitLoop(...)` for dead-label loop demotion
- `visitTry(...)` for the special “handle my own name, then also visit generic scope-name uses” rule
- `visitFunction(...)` for `DELEGATE_CALLER_TARGET` cleanup and the final `branchesSeen.empty()` assertion

That source layout confirms the most important compact teaching point:

- Binaryen `remove-unused-names` is not spread across a large helper family
- it is a tiny function-parallel postwalk whose behavior is concentrated in one file

## 2. `branch-utils.h` is the real helper surface, not background trivia

`RemoveUnusedNames.cpp` depends on exactly two visible helper entry points from `src/ir/branch-utils.h`:

- `operateOnScopeNameUses(...)`
- `replacePossibleTarget(...)`

That file matters because it answers two otherwise-fuzzy questions.

First, what counts as a scope-name use?
The helper delegates over every Binaryen expression field marked as a scope-name use in `wasm-delegations-fields.def`.
So the pass is intentionally generic over scope-targeting IR forms rather than manually hardcoding only plain `br` and `br_table`.

Second, how does parent-to-child retargeting work during a same-type block merge?
The helper's `replacePossibleTarget(...)` function rewrites any matching target in that generic scope-name-use surface.
So the block-merge story is not “rewrite one branch opcode”; it is “rewrite whatever Binaryen currently marks as a scope-name use.”

That is the right source-confirmed owner split to teach:

- `RemoveUnusedNames.cpp` decides when a label can die or when a parent/child block pair is equivalent
- `branch-utils.h` owns how generic scope-target uses are found and retargeted

## 3. `shared-constants.h` matters for one tiny but real part of the contract

`src/shared-constants.h` exposes:

- `DELEGATE_CALLER_TARGET`

That is the tiny but real reason the pass has a dedicated function-end cleanup step.
At function exit it erases the caller-delegate sentinel and then asserts the map is empty.

This confirms the honest delegate story:

- the pass is not only about block and loop labels
- it also has a special pseudo-target cleanup rule for delegations to the caller

## 4. `pass.cpp` proves identity and repeated slot placement

`src/passes/pass.cpp` proves four durable things.

- Public registration:
  - `registerPass("remove-unused-names", "removes names from locations that are never branched to", createRemoveUnusedNamesPass)`
- Canonical no-DWARF early placement:
  - after `dce`
- Canonical no-DWARF mid placement:
  - after the first `remove-unused-brs`
- Canonical no-DWARF late placement:
  - after `merge-blocks -> remove-unused-brs`

The comments in `pass.cpp` still make the late rerun reason explicit too:

- `remove-unused-brs opens opportunities`

So the source-confirmed scheduler meaning is stronger than the short public summary.
The pass is deliberately rerun at the exact spots where neighboring cleanup passes tend to make more labels dead.

## 5. The no-fixup story is source-backed, not just an inference

`RemoveUnusedNames.cpp` says:

- `requiresNonNullableLocalFixups() == false`

and `pass.cpp` still shows that the pass runner only invokes local fixups when that flag is true.

So the dossier can now say this more precisely:

- `remove-unused-names` is intentionally outside Binaryen's nondefaultable-local repair path
- its contract is supposed to simplify or preserve validity directly, not mutate labels and then ask a later local-type repair step to save it

## Source-confirmed test map

## 1. The dedicated base pair proves the core contract

### `remove-unused-names.wast`
### `remove-unused-names.txt`

This base pair is still the direct proof surface for the pass itself.
It directly proves the main core families:

- dead named outer blocks lose their label and can disappear
- same-type one-child named parent/child blocks can merge
- `br_table` targets retarget along with plain branches
- dead-label loops can demote to their body
- typed mismatch cases stay wrapped instead of being over-collapsed

This pair is still the canonical first file to read when implementing the pass.

## 2. `precompute` proves why the pass lives in a cleanup cluster

### `remove-unused-names_precompute.wast`
### `remove-unused-names_precompute.txt`

This pair proves an important scheduler lesson rather than a new local legality rule:

- once `precompute` makes a dynamic branch choice constant,
- `remove-unused-names` can clear the now-dead label layer that the original branch structure required.

That is why the pass is best taught as a repeated cleanup consumer inside a pipeline, not as a one-shot standalone rewrite.

## 3. `vacuum` proves the implicit-block and wrapper-cleanup handoff

### `remove-unused-names_vacuum.wast`
### `remove-unused-names_vacuum.txt`
### `remove-unused-names_vacuum_ignore-implicit-traps.wast`
### `remove-unused-names_vacuum_ignore-implicit-traps.txt`

These files prove the next important scheduler truth:

- `remove-unused-names` often exposes simpler wrappers,
- but nearby cleanup like `vacuum` is what finishes some of the visible cleanup,
- especially in trap-sensitive or unreachable-heavy shapes.

The `ignore-implicit-traps` variant matters because it keeps the beginner story honest:

- label removal is not the same thing as permission to ignore trap semantics

## 4. `remove-unused-brs` + `vacuum` proves the repeated cleanup neighborhood

### `remove-unused-names_remove-unused-brs_vacuum.wast`
### `remove-unused-names_remove-unused-brs_vacuum.txt`

This larger combo pair is the most direct shipped proof for the canonical repeated-cluster story:

- branch cleanup makes more labels removable
- label cleanup exposes more inert structure
- `vacuum` then removes the leftovers

That matches the real no-DWARF slot placement in `pass.cpp`.

## 5. `code-folding` and `merge-blocks` prove downstream structural consumers

### `remove-unused-names_code-folding.wast`
### `remove-unused-names_code-folding.txt`
### `remove-unused-names_merge-blocks_all-features.wast`
### `remove-unused-names_merge-blocks_all-features.txt`

These files prove that `remove-unused-names` is not only a local “clean up labels and stop” pass.
It also prepares structure for later neighbors that benefit from fewer named wrappers.

The important beginner framing is:

- the pass does not itself do generic tail-sharing or generic block flattening
- but it removes one class of structural obstacle that those later passes care about

## What the shipped tests do not isolate cleanly

The current official test surface is broad enough to map the visible rewrite families, but it does **not** isolate everything equally well.

Most importantly, I did **not** find a dedicated `remove-unused-names` lit file focused purely on:

- `try` / `delegate`
- `rethrow`
- or the `DELEGATE_CALLER_TARGET` sentinel

So the honest source-backed teaching split is:

- block / loop / `br_table` / cleanup-cluster behavior is directly lit-backed
- delegate behavior is source-confirmed from `visitTry(...)`, `operateOnScopeNameUses(...)`, and the function-end sentinel cleanup, but not highlighted by a dedicated standalone named lit file

That absence should stay explicit in the living docs.
It is not a contradiction, but it is a real difference between:

- what the source owns, and
- what the shipped tests isolate by filename.

## Current-main drift check

I compared the key core surfaces on upstream `main` against `version_129`.
Their raw contents still match exactly for:

- `src/passes/RemoveUnusedNames.cpp`
- `test/passes/remove-unused-names.wast`
- `test/passes/remove-unused-names.txt`

So the existing dossier's “no semantic current-main drift on the core surface” note still stands.
This follow-up does not overturn it.

## Local-Starshine contrast re-checked

The local MoonBit port still deliberately teaches a smaller subset than upstream Binaryen's generic scope-name-use surface.
`src/passes/remove_unused_names_test.mbt` already covers:

- same-type nested block peeling
- type-index block-wrapper preservation
- parent-target retargeting after peeling
- bailout when a nested `if` still targets a peeled scope
- bailout when a `try_table` catch still targets a peeled scope
- loop demotion when the continue target is dead
- loop preservation when the continue target is still live

That means the local tests already line up with the most important direct core families.
The remaining wiki gap was mainly upstream owner/test mapping, not local regression blindness.

## Wiki filing result

This follow-up should land as:

- a new `docs/wiki/binaryen/passes/remove-unused-names/implementation-structure-and-tests.md` page
- landing / strategy / WAT-shape / tracker / index / log refreshes that point to it
- an explicit tracker note that the `remove-unused-names` folder's compact implementation/test-map gap is now closed

## Bottom line

The compact source-confirmed answer is now:

- `remove-unused-names` is almost entirely a **single-file pass** in `RemoveUnusedNames.cpp`
- `branch-utils.h` is the real helper surface because it owns generic scope-name-use discovery and target retargeting
- `shared-constants.h` matters only for the tiny but real `DELEGATE_CALLER_TARGET` cleanup rule
- `pass.cpp` owns the public name and the three canonical no-DWARF cleanup slots
- the shipped test surface directly proves the block/loop/cleanup-cluster story, while the delegate story is source-confirmed but not isolated by a dedicated standalone lit file

That is the compact owner/test-map clarification the previous deep dossier still lacked.
