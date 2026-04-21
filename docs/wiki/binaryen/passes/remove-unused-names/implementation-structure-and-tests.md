---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0143-2026-04-20-remove-unused-names-binaryen-research.md
  - ../../../raw/research/0220-2026-04-21-remove-unused-names-source-confirmation-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedNames.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/shared-constants.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_precompute.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_precompute.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_vacuum.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_vacuum.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_vacuum_ignore-implicit-traps.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_vacuum_ignore-implicit-traps.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_remove-unused-brs_vacuum.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_remove-unused-brs_vacuum.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_code-folding.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_code-folding.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_merge-blocks_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_merge-blocks_all-features.txt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./control-names-implicit-blocks-and-delegates.md
  - ./wat-shapes.md
  - ./invalid-tag-index-parser-gap.md
---

# Upstream implementation structure and test map for `remove-unused-names`

This page is the compact file/test map for the real Binaryen `version_129` `remove-unused-names` contract.

## Main implementation file

## `src/passes/RemoveUnusedNames.cpp`

This is the real pass file.
It owns almost all of the visible behavior:

- the `WalkerPass<PostWalker<RemoveUnusedNames, UnifiedExpressionVisitor<...>>>` pass body
- `isFunctionParallel() == true`
- `requiresNonNullableLocalFixups() == false`
- the one important state map
  - `std::map<Name, std::set<Expression*>> branchesSeen`
- `visitExpression(...)` for collecting scope-name uses
- `handleBreakTarget(...)` for clearing dead labels or retiring used-scope bookkeeping
- `visitBlock(...)` for same-type one-child parent/child merges plus branch retargeting
- `visitLoop(...)` for dead-label loop demotion
- `visitTry(...)` for the special “handle my own name, then also visit generic scope-name uses” rule
- `visitFunction(...)` for `DELEGATE_CALLER_TARGET` cleanup and the final empty-map assertion

That file layout proves the most important compact beginner fact:

- `remove-unused-names` is not a wide optimizer family spread across many pass files
- it is one tiny function-parallel postwalk over Binaryen's control-label surface

## Direct helper ownership that affects visible behavior

## `src/ir/branch-utils.h`

This helper file matters because `RemoveUnusedNames.cpp` depends on exactly two generic scope-target operations from it:

- `operateOnScopeNameUses(...)`
- `replacePossibleTarget(...)`

That source split proves two durable points.

First, the pass does **not** hand-code only plain `br` and `br_table`.
It asks Binaryen's generic scope-name-use helper what the current expression uses.
So the pass's real target surface is:

- whatever Binaryen currently marks as a scope-name use in its delegation tables

Second, parent-to-child block merges are not a special case for one branch opcode.
`replacePossibleTarget(...)` retargets the whole generic scope-name-use surface.

So the compact owner summary should teach:

- `RemoveUnusedNames.cpp` decides *when* a label can die or a parent/child block pair is equivalent
- `branch-utils.h` owns *how* matching scope-target uses are found and rewritten

## `src/shared-constants.h`

This file owns one small but real part of the contract:

- `DELEGATE_CALLER_TARGET`

That is why the pass has a dedicated function-end cleanup step.
When the walker reaches the function body, it erases the caller-delegate sentinel and then asserts that no other pending scope-name uses remain.

This keeps the delegate story honest:

- the pass is not only about blocks and loops
- it also has a special pseudo-target cleanup rule for delegations to the caller

## Registration and scheduler file

## `src/passes/pass.cpp`

This file proves three durable things:

- `remove-unused-names` is a real public pass name
- the public summary string is only `removes names from locations that are never branched to`
- the default no-DWARF function pipeline runs the pass three times, not once

The repeated placements are source-important:

1. after `dce`
2. after the first `remove-unused-brs`
3. again after `merge-blocks -> remove-unused-brs`

The file also keeps the late reason explicit:

- `remove-unused-brs opens opportunities`

So the best compact teaching split is:

- `RemoveUnusedNames.cpp` owns the rewrite legality
- `pass.cpp` owns the public identity and the repeated cleanup-cluster placement

## One useful owner boundary from the pass runner

`RemoveUnusedNames.cpp` says:

- `requiresNonNullableLocalFixups() == false`

and `pass.cpp` still shows that the generic pass runner only invokes nondefaultable-local fixups when that flag is true.

That makes one compact porting lesson explicit:

- `remove-unused-names` is intentionally outside Binaryen's generic local-type repair path
- its edits are supposed to preserve or help validation directly

## Official test files and what each one proves

## `test/passes/remove-unused-names.wast`
## `test/passes/remove-unused-names.txt`

This dedicated base pair is still the main direct proof surface for the pass itself.
It directly proves:

- dead named outer blocks can lose their label and collapse away
- same-type one-child named parent/child blocks can merge
- `br_table` targets retarget along with plain branches
- dead-label loops can demote to their body
- typed mismatch wrappers stay when that equality check fails

If you want the one file pair that proves the core contract, start here.

## `test/passes/remove-unused-names_precompute.wast`
## `test/passes/remove-unused-names_precompute.txt`

This pair proves the scheduler-neighbor story rather than a new local legality rule.
It shows that once `precompute` makes a dynamic branch choice constant, `remove-unused-names` can strip the now-dead label layer that old control shape required.

That is why the pass is best taught as a repeated cleanup consumer, not as a one-shot standalone transformation.

## `test/passes/remove-unused-names_vacuum.wast`
## `test/passes/remove-unused-names_vacuum.txt`
## `test/passes/remove-unused-names_vacuum_ignore-implicit-traps.wast`
## `test/passes/remove-unused-names_vacuum_ignore-implicit-traps.txt`

These files prove the next handoff:

- `remove-unused-names` often exposes simpler wrappers
- `vacuum` is what finishes some of the visible cleanup
- trap-sensitive and unreachable-heavy cases still matter after label removal

The `ignore-implicit-traps` variant is especially useful because it keeps the dossier from overclaiming that all newly nameless structure can simply disappear.

## `test/passes/remove-unused-names_remove-unused-brs_vacuum.wast`
## `test/passes/remove-unused-names_remove-unused-brs_vacuum.txt`

This larger combo pair is the best direct shipped proof for the repeated cleanup neighborhood:

- branch cleanup makes more labels removable
- label cleanup exposes more inert structure
- `vacuum` removes what is left

That pair matches the real repeated placement in `pass.cpp`.

## `test/passes/remove-unused-names_code-folding.wast`
## `test/passes/remove-unused-names_code-folding.txt`

This pair proves that fewer named wrappers can help later tail-sharing and cleanup families.
The pass is not itself a code-folder, but it removes one structural obstacle those later passes care about.

## `test/passes/remove-unused-names_merge-blocks_all-features.wast`
## `test/passes/remove-unused-names_merge-blocks_all-features.txt`

This pair proves the same broader lesson for the structural cleanup neighbor at full feature surface.
It shows that `remove-unused-names` belongs in the same late-control-cleanup neighborhood as `merge-blocks`, not in some isolated “cosmetic labels only” bucket.

## What the official tests do **not** isolate cleanly by themselves

The shipped test surface is broad enough to map the main visible rewrite families.
But one important part of the contract is easier to confirm from source ownership than from test filenames:

- there is no dedicated standalone `remove-unused-names` lit file focused purely on `try` / `delegate` / caller-sentinel behavior

So the safest teaching split is:

- block / loop / `br_table` / cleanup-cluster behavior is directly lit-backed
- delegate behavior is source-confirmed from `visitTry(...)`, `operateOnScopeNameUses(...)`, and `DELEGATE_CALLER_TARGET` cleanup, but not isolated by a dedicated named lit file

That absence should stay explicit in the living docs.

## Practical reading order for future Starshine parity work

1. `src/passes/RemoveUnusedNames.cpp`
   - understand the tiny core algorithm and exact state map
2. `src/ir/branch-utils.h`
   - understand the real generic scope-name-use surface and retarget helper
3. `src/shared-constants.h`
   - keep the caller-delegate sentinel story honest
4. `src/passes/pass.cpp`
   - confirm public identity and the three repeated no-DWARF slots
5. the dedicated `remove-unused-names` test pair
   - confirm the core block / loop / `br_table` shapes
6. the combo test pairs
   - map the real cleanup-cluster neighborhood

## Porting checklist that falls out of this file map

Before calling a future Starshine port faithful, verify all of these against the official files:

- the pass is function-parallel and postwalk-shaped, not CFG-shaped
- dead-label tracking is keyed by scope name and backed by exact user sets, not just counts
- same-type one-child parent/child block merges retarget all generic scope-name uses, not only plain `br`
- dead-label loops demote only when body type still matches loop type
- `try` handling preserves the separate delegate-target story
- function-end caller-sentinel cleanup exists explicitly
- the scheduler models the three top-level no-DWARF placements separately instead of pretending one run is enough
- parity signoff uses both the dedicated base pair and the cleanup-cluster combo files instead of treating the base pair as the entire pass surface

## Sources

- [`../../../raw/research/0143-2026-04-20-remove-unused-names-binaryen-research.md`](../../../raw/research/0143-2026-04-20-remove-unused-names-binaryen-research.md)
- [`../../../raw/research/0220-2026-04-21-remove-unused-names-source-confirmation-followup.md`](../../../raw/research/0220-2026-04-21-remove-unused-names-source-confirmation-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedNames.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/shared-constants.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_precompute.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_precompute.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_vacuum.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_vacuum.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_vacuum_ignore-implicit-traps.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_vacuum_ignore-implicit-traps.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_remove-unused-brs_vacuum.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_remove-unused-brs_vacuum.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_code-folding.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_code-folding.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_merge-blocks_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_merge-blocks_all-features.txt>
