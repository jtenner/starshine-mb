# 0143 - Binaryen `remove-unused-names` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the new `reorder-locals` dossier.
- Follow the repo wiki process in `docs/README.md`.
- Re-check the upstream implementation against Binaryen `version_129`.
- Deepen the existing `remove-unused-names` landing page into a real multi-page dossier.
- Teach the pass in beginner-friendly language without flattening the important semantic details about Binaryen control names, implicit blocks, and delegate targets.
- File the durable conclusions back into:
  - `docs/wiki/binaryen/passes/remove-unused-names/`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/index.md`
  - `docs/wiki/log.md`

## Candidate selection

I followed the campaign instructions in order:

1. read `docs/README.md`
2. read `docs/wiki/binaryen/passes/tracker.md`
3. read `docs/wiki/binaryen/passes/index.md`
4. read `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
5. re-checked `agent-todo.md`

At the start of this thread, the updated tracker said:

- the saved-audit `none` queue was already clear
- `reorder-locals` had just been promoted to `deep`
- `remove-unused-names` was now the **last implemented pass** still marked only `landing`

That made `remove-unused-names` the correct pick for this run.

## Why this pass was still worth deepening

`remove-unused-names` is easy to under-document because the implementation file is tiny.

That would be a mistake.

This pass matters because:

- it appears repeatedly in the canonical no-DWARF function pipeline
- it also appears repeatedly in the saved generated-artifact `-O4z` audit
- the pass edits **control labels**, not the wasm name section or debug metadata
- Binaryen block names are semantic because branch targets are name-based in Binaryen IR
- removing a name can make a block become an implicit block that disappears on emission
- the pass has a special delegate-to-caller rule that is easy to miss if you only skim the block/loop logic
- the existing folder only had a landing page and a parser-gap note, so the actual Binaryen implementation, scheduler meaning, and WAT-shape teaching surface were still missing

This is exactly the kind of pass that sounds simpler than it really is.

## Official Binaryen source inventory

Primary `version_129` sources used for this research:

- implementation:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedNames.cpp>
- scheduler / pass registration:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- branch and label helper surface:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- control-name and implicit-block semantics:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/README.md>
- delegate caller sentinel:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/shared-constants.h>

Official Binaryen `version_129` test surfaces used here:

- dedicated pass test:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names.txt>
- nearby-pass interaction tests:
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

## Freshness check

I also did a narrow direct source diff against current GitHub `main` for:

- `src/passes/RemoveUnusedNames.cpp`
- `test/passes/remove-unused-names.wast`
- `test/passes/remove-unused-names.txt`

Result:

- no diff in those core pass surfaces

So the durable freshness rule for this dossier is:

- treat Binaryen `version_129` as the released oracle
- current `main` does not presently show core implementation or dedicated-test drift for this pass

I did **not** do a full current-main diff for every neighboring combo test file, so the no-drift statement above is intentionally narrow.

## Repo-local sources used for context

Starshine-side files relevant to this dossier:

- implementation:
  - `src/passes/remove_unused_names.mbt`
- focused tests:
  - `src/passes/remove_unused_names_test.mbt`
- registry and preset placement:
  - `src/passes/optimize.mbt`
  - `src/passes/registry_test.mbt`
- CLI and artifact-path references:
  - `src/cmd/cmd_wbtest.mbt`
- canonical schedule guide:
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- artifact audit summary:
  - `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`
- existing folder note:
  - `docs/wiki/binaryen/passes/remove-unused-names/invalid-tag-index-parser-gap.md`

There is still **no dedicated `RUN` slice** in `agent-todo.md` today.
The only local backlog mentions are indirect, mainly:

- the canonical no-DWARF ordered path
- the shared post-SSA cleanup replay note, which records that the old giant RUN raw-noop hotspot was retired and the pass now skips many functions cheaply when there are no candidates

## High-level conclusion

`remove-unused-names` is not a name-section cleanup pass.

It is a small, function-parallel **control-label simplifier** for Binaryen IR.

What it actually does is:

- track which scope names are still used by branches or delegates in the current subtree
- clear control names that no remaining branch uses
- merge a named one-child block into its named child when both blocks have the same type
- retarget branches from the parent name to the child name when doing that merge
- demote a loop into its body when the loop name is no longer needed and the body has the same type
- special-case delegate-to-caller bookkeeping so the function ends with no stray pending label uses

What it does **not** do:

- remove wasm name-section metadata
- analyze effects, dominance, CFG, or liveness
- prove whether a syntactically present branch is dynamically unreachable
- flatten arbitrary nested blocks directly
- delete dead branches by itself
- run generic type repair or refinalization helpers

The most important beginner correction is:

- in Binaryen, block / loop / try names are part of control-flow semantics
- so “remove unused names” is really “remove unused control labels, then let implicit-block emission and nearby cleanup passes erase now-unnecessary structure”

## Why the pass is subtle despite being tiny

The source file is only about `100` lines long, but it sits on top of three important Binaryen IR rules from the README:

1. branches target names, not nesting depth
2. block names must be unique in Binaryen IR
3. nameless blocks cannot be branch targets and may be emitted implicitly, meaning the block node itself need not appear in printed / binary wasm

That means clearing a name can have a structural consequence even when the pass does not literally splice instruction lists itself.

A lot of the visible simplification happens because:

- a name disappears
- the block becomes implicit
- later printing or nearby passes stop needing the wrapper

## Exact Binaryen implementation structure

`RemoveUnusedNames.cpp` defines one pass struct:

- `struct RemoveUnusedNames : public WalkerPass<PostWalker<RemoveUnusedNames, UnifiedExpressionVisitor<RemoveUnusedNames>>>`

Two pass-level properties matter immediately:

- `isFunctionParallel() == true`
- `requiresNonNullableLocalFixups() == false`

That second point is source-commented explicitly.
Binaryen says removing names can only help validation because nameless blocks are ignored in the relevant validation story.

## Core state: `branchesSeen`

The entire pass revolves around one data structure:

- `std::map<Name, std::set<Expression*>> branchesSeen`

This map records:

- for each currently relevant scope name
- the set of branch-like expressions in already-visited descendants
- that still target that name

Two details matter here:

### The pass stores branch expressions, not just counts

That is because block merging needs to do targeted rewrites:

- when a parent block is merged into its child block
- every branch that previously targeted the parent name must be retargeted to the child name

A simple boolean or count would be insufficient.

### The pass relies on Binaryen's unique-name rule

Because Binaryen IR canonicalizes names to be unique, the pass can use one global `map<Name, ...>` rather than a depth stack of potentially shadowed labels.

That is a real source-backed simplification.
It would not be safe in raw wasm depth-index space without an equivalent uniqueness layer.

## Phase 1: collect scope-name uses in descendants

The generic visitor is:

- `visitExpression(Expression* curr)`

It calls:

- `BranchUtils::operateOnScopeNameUses(curr, ...)`

That helper walks every scope-name **use** inside the current expression.
In practice that includes more than just plain `br`:

- ordinary breaks
- switch / br_table destinations
- br_on family destinations
- try / rethrow delegate-style targets
- other scope-name users covered by `wasm-delegations-fields.def`

The pass inserts the current expression pointer into `branchesSeen[name]` for each used name.

Important consequence:

- this is a syntactic name-use collector
- it is not an effect-aware or reachability-aware branch liveness proof

### Labeled inference

This next point is an inference from source structure, not an explicit Binaryen comment:

- `branch-utils.h` contains `isBranchReachable(...)`
- `RemoveUnusedNames.cpp` does **not** call it
- therefore this pass appears to treat syntactically present scope-name uses as keeping the target alive, even if another pass could prove the branch never fires

That matches the overall scheduler story:

- `remove-unused-brs`, `precompute`, and `vacuum` do the stronger cleanup nearby
- `remove-unused-names` itself keeps a much cheaper syntactic contract

## Phase 2: handle the current break target name

The shared helper is:

- `handleBreakTarget(Name& name)`

It does exactly two things:

- if the current scope name has **no** recorded uses in `branchesSeen`, clear the name
- otherwise, erase the map entry for that name

The erase step matters because it is effectively a scope-pop operation:

- once we leave this scope, outer logic should no longer see this target as pending work

The clear step is the source of the pass name:

- unused control labels disappear here

## Block logic

The block visitor is the most important part of the pass:

- `visitBlock(Block* curr)`

### Same-type single-child named-block merge

Binaryen checks all of these conditions:

- the current block has a name
- it has exactly one child
- that child is also a block
- the child also has a name
- `child->type == curr->type`

If so, then the pass can collapse the parent label layer.

Why this is legal:

- breaking out of the child reaches the same destination as breaking out of the parent when the parent contains only that child and both have the same result type

What Binaryen does then:

1. fetch all branches currently targeting the parent name from `branchesSeen[curr->name]`
2. rewrite each such branch target from `curr->name` to `child->name` using `BranchUtils::replacePossibleTarget(...)`
3. `finalize` the child
4. `replaceCurrent(child)`

Then it calls `handleBreakTarget(curr->name)`.

### Important nuance: merging is not the same thing as implicit-block disappearance

A beginner can easily miss this distinction.

- If a child name was already removed earlier because nobody branched to it, then `child->name.is()` is false and this explicit merge path does **not** run.
- That is okay because the nameless child may already be eligible to disappear implicitly on emission.

So there are really two simplification mechanisms here:

1. explicit label-layer merge when both names still matter enough to exist
2. later implicit-block disappearance once names have been cleared

Both are important, and they are not the same transformation.

### Another subtle case: parent unused, child used

Because the merge path does not require any actual branches to the parent, it also handles the case where:

- the parent name is unused
- the child name is used

Then `branchesSeen[curr->name]` is just an empty set.
Binaryen still replaces the parent with the child, which is exactly what you want: the child label survives, the unnecessary outer label layer disappears.

## Loop logic

The loop visitor is:

- `visitLoop(Loop* curr)`

Binaryen first calls `handleBreakTarget(curr->name)`.

Then, if both are true:

- the loop now has no name
- `curr->body->type == curr->type`

it does:

- `replaceCurrent(curr->body)`

This is the loop-demotion rule.

A loop label only matters for continue targets.
If no branch targets the loop label anymore, the wrapper can collapse into its body **when** type equality makes that safe.

Important negative rule:

- unnamed loops are **not** always removable
- type mismatch between the loop and its body keeps the wrapper alive

That exact negative family is in the official dedicated test.

## Try / delegate logic

The try visitor is:

- `visitTry(Try* curr)`

It does:

1. `handleBreakTarget(curr->name)`
2. `visitExpression(curr)`

The source comment explains why this is special:

- `try` has a break target name like other control scopes
- but it can also contain an optional delegate target name
- so the generic expression visitor must be called explicitly here to process that use

This is easy to miss if you only focus on block and loop.

## Function-final cleanup

At function end Binaryen runs:

- `branchesSeen.erase(DELEGATE_CALLER_TARGET)`
- `assert(branchesSeen.empty())`

This is the remaining delegate bookkeeping rule.

`DELEGATE_CALLER_TARGET` is a shared sentinel name from `shared-constants.h`.
It represents delegation to the caller rather than a scope defined inside the current function body.

So the pass explicitly discards that sentinel at function end and then asserts there are no leftover scope-name uses.

That is a strong invariant:

- all ordinary in-function label uses must have been matched and popped correctly

## What the pass depends on

Real helper dependencies are narrow:

- `BranchUtils::operateOnScopeNameUses(...)`
- `BranchUtils::replacePossibleTarget(...)`
- the `DELEGATE_CALLER_TARGET` shared constant
- Binaryen control-name uniqueness and implicit-block rules from `README.md`
- ordinary `Block`, `Loop`, and `Try` node shape and type equality

## What it notably does **not** depend on

- `Effects`
- CFG analysis
- dominance
- liveness
- `LocalGraph`
- `ReFinalize`
- type-updating helpers
- EH repair helpers
- non-nullable-local fixups

That absence is part of the real contract.
`remove-unused-names` is intentionally cheap.

## Scheduler placement and what it means

`pass.cpp` registers the pass as:

- `remove-unused-names` = removes names from locations that are never branched to

That description is true but incomplete.
The canonical no-DWARF function pipeline runs it three times:

1. right after `dce`
2. right after the first `remove-unused-brs`
3. late again after `merge-blocks -> remove-unused-brs`

The nearby scheduler comments are revealing:

- the first `remove-unused-names` is part of the early cleanup cluster after DCE
- the second immediately follows `remove-unused-brs`, because branch cleanup opens fresh label-removal opportunities
- the late run comes after `merge-blocks` and another `remove-unused-brs`, when new single-child wrappers and dead label layers can appear again

So the honest scheduler meaning is:

- `remove-unused-names` is small, but Binaryen keeps rerunning it because nearby cleanup passes create more removable control labels over time

## Saved generated-artifact `-O4z` relevance

This pass is also clearly relevant to the saved generated-artifact audit.
The local summary records three observed top-level `remove-unused-names` slots:

- Binaryen slot `13`
- Binaryen slot `15`
- Binaryen slot `41`

Current saved outcomes:

- slot `13`: exact yes, meaningful yes
- slot `15`: exact no, meaningful yes
- slot `41`: exact no, meaningful yes

So the pass is:

- already active in both canonical scheduler documentation and artifact audit evidence
- often meaningfully aligned even when exact bytes differ later in the pipeline

## Official test surfaces and what they prove

### Dedicated pass test: `remove-unused-names.wast`

This file covers the main core families:

- named outer block with no branch target -> value survives without the named wrapper
- loops with real continue edges stay loops
- loops with no remaining continue edges can disappear
- one-child same-type named blocks merge and retarget branch users
- typed block merges still work in an unreachable-heavy case
- loop-with-child-of-other-type shows the type-mismatch bailout explicitly

This dedicated file is the best compact teaching surface for the pass itself.

### `remove-unused-names_precompute.*`

This pair shows a real scheduler interaction:

- `precompute` can make a branch-table choice constant
- once that happens, some scope names become unused
- `remove-unused-names` can then strip or collapse the remaining label structure

That is exactly why the pass appears in cleanup clusters rather than only once.

### `remove-unused-names_vacuum.*` and `remove-unused-names_vacuum_ignore-implicit-traps.*`

These pairs show another key truth:

- name removal often exposes structure that `vacuum` can simplify further
- nameless wrappers around `unreachable`, loops, and simple values become much less important
- trap-sensitive cleanup still belongs to `vacuum`, not to `remove-unused-names`

So `remove-unused-names` is an enabler for structural cleanup, not the whole cleanup story by itself.

### `remove-unused-names_remove-unused-brs_vacuum.*`

This combo pair is especially valuable because it shows the late-cluster reality:

- branch cleanup can make labels dead
- name removal then collapses label structure
- vacuum can then remove leftover inert wrappers or dead scaffolding

That is the best test-backed explanation for why Binaryen orders these passes so tightly.

### `remove-unused-names_code-folding.*` and `remove-unused-names_merge-blocks_all-features.*`

These files show that later structural passes benefit when name removal has already happened.
They demonstrate that:

- explicit labels can inhibit later structural sharing and block merging
- once labels are gone, more wrappers become ordinary unnamed structure that later passes can fold or merge

This is the main reason not to dismiss the pass as “cosmetic.”

## Important shape families

### Positive families

- named block with no remaining branch target -> name cleared, block may become implicit
- named parent block with one same-typed named child -> parent can collapse into child
- parent-targeting `br` / `br_table` users -> retargeted to child name during merge
- named loop with no remaining continue users and equal body type -> loop demotes to body
- late cleanup after `remove-unused-brs` -> newly dead labels removed
- precompute-resolved branch destinations -> leftover label scaffolding removed afterward

### Negative or bailout families

- child block of different type -> no same-type block merge
- loop whose body type differs from loop type -> no loop demotion
- child label still semantically needed -> child name survives, so explicit merge behavior changes
- dead-branch proof beyond syntactic use -> out of scope for this pass
- generic control simplification without label removal -> out of scope for this pass

### Special families easy to misunderstand

- delegate-to-caller target is not a normal in-function scope and must be erased specially at function end
- nameless blocks disappearing in printed output is a Binaryen IR / writer rule, not direct evidence that `remove-unused-names` itself spliced lists at that exact spot

## Difference between the pass name and the actual behavior

What the name suggests:

- clean up optional names
- maybe something adjacent to debug metadata

What the source and tests actually show:

- a cheap control-label liveness and wrapper-canonicalization pass for Binaryen IR

That gap between the name and the behavior is the biggest reason this dossier was worth writing.

## Implications for Starshine

The current in-tree Starshine pass is not a direct AST-name port.
It is a HOT pass over numeric label ids and structured regions.

That means a future maintainer must preserve the **semantic** contract, not the literal C++ data structures:

- track all label-target uses, including branch tables, delegate-style targets, and catch-target-like forms
- peel same-typed nested block layers only when removed labels are not still targeted
- demote loops only when the continue label is genuinely dead and type equality still holds
- keep name / label cleanup separate from parser-gap accounting

The existing `invalid-tag-index-parser-gap.md` page remains relevant here because it reminds us that:

- not every `remove-unused-names` compare failure is a pass mismatch
- some are Binaryen parser-family failures upstream of semantic comparison

## Future-port rules worth preserving explicitly

A future Starshine refactor or reimplementation should preserve these rules:

- control-label removal, not name-section cleanup, is the primary meaning
- syntactic scope-name uses are enough to keep a label alive for this pass
- one-child same-type named-block merge must retarget parent-targeting branches to the child name
- nameless-block disappearance is a separate downstream consequence, not the same rewrite
- loop demotion must check type equality, not just unused labels
- delegate-to-caller cleanup must leave no stray pending targets at function end
- this pass should stay cheap and not silently grow hidden CFG / effects dependencies unless the repo decides to intentionally widen scope

## Bottom line

`remove-unused-names` is small, but it is not trivial.

The correct beginner summary is:

- Binaryen tracks which control labels are still used, clears the dead ones, merges compatible parent/child named blocks by retargeting branches, demotes loops whose labels are no longer used, and then relies on implicit-block emission plus nearby cleanup passes to erase the now-unnecessary structure.

That is the durable contract this dossier should preserve.
