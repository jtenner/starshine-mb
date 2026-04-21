---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0143-2026-04-20-remove-unused-names-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedNames.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/shared-constants.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/README.md
related:
  - ./index.md
  - ./control-names-implicit-blocks-and-delegates.md
  - ./wat-shapes.md
  - ./invalid-tag-index-parser-gap.md
  - ../../no-dwarf-default-optimize-path.md
  - ../dead-code-elimination/index.md
  - ../remove-unused-brs/index.md
---

# Binaryen `remove-unused-names` strategy

## Upstream source rule

Use Binaryen `version_129` as the primary source oracle for this pass.

Primary files:

- `src/passes/RemoveUnusedNames.cpp`
- `src/passes/pass.cpp`
- `src/ir/branch-utils.h`
- `src/shared-constants.h`
- `README.md`

Most important official test surfaces for this dossier:

- `test/passes/remove-unused-names.wast`
- `test/passes/remove-unused-names.txt`
- the neighboring combo tests that pair this pass with `precompute`, `vacuum`, `remove-unused-brs`, `code-folding`, and `merge-blocks`

I also did a narrow 2026-04-20 freshness check against current GitHub `main` for:

- `RemoveUnusedNames.cpp`
- `remove-unused-names.wast`
- `remove-unused-names.txt`

Durable result:

- those core surfaces still match `version_129` exactly

So the wiki should keep treating `version_129` as the semantic oracle here without an active core-trunk-drift warning.

## High-level intent

Binaryen uses `remove-unused-names` to simplify control structure **by removing dead control labels**, not by doing a broad control-flow rewrite.

The pass works because Binaryen IR has three relevant properties:

- branches target names rather than nesting depth
- names are unique in Binaryen IR
- nameless blocks may become implicit and disappear on emission

That lets Binaryen do a cheap but powerful cleanup:

- delete labels no remaining branch needs
- merge a named parent block into a named child block when they are semantically equivalent as branch targets
- remove loop wrappers that no longer matter as continue targets

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Collect scope-name uses | Walk expressions and record used target names in `branchesSeen` | Learn which labels are still live in the current descendant region |
| Handle current target | Clear a name if unused, or erase its pending map entry if used | Remove dead labels and pop scope bookkeeping |
| Merge same-type one-child blocks | Retarget parent-targeting branches to the child name, then replace the parent with the child | Collapse redundant named wrapper layers |
| Demote dead-label loops | Replace a loop with its body when the label is gone and the body type matches | Remove loop wrappers that no longer matter as continue targets |
| Clean delegate caller sentinel | Drop `DELEGATE_CALLER_TARGET` at function end and assert the map is empty | Finish delegate bookkeeping without leaking fake in-function targets |

## Registered surface

`pass.cpp` registers:

- `remove-unused-names`
  - removes names from locations that are never branched to

That description is accurate but incomplete.

A more implementation-faithful summary is:

- Binaryen removes dead control labels, merges compatible named block layers, demotes dead-label loops, and relies on implicit-block emission plus nearby cleanup passes for the rest.

## Canonical no-DWARF placement

In `pass.cpp`, the default no-DWARF function pipeline uses `remove-unused-names` three times:

1. right after `dce`
2. right after the first `remove-unused-brs`
3. late again after `merge-blocks -> remove-unused-brs`

That tells us the scheduler meaning is not just “strip names once.”

Instead:

- DCE can leave behind typed or named control wrappers whose labels are now useless.
- `remove-unused-brs` can make more labels dead by deleting or retargeting exits.
- `merge-blocks` can expose new single-child structures that then interact with label removal again.

So Binaryen reruns this pass at exactly the points where label liveness keeps changing.

## Pass shape: one tiny function-parallel walker

`RemoveUnusedNames.cpp` defines:

- `struct RemoveUnusedNames : public WalkerPass<PostWalker<RemoveUnusedNames, UnifiedExpressionVisitor<RemoveUnusedNames>>>`

Two pass-level properties immediately frame the contract:

- `isFunctionParallel() == true`
- `requiresNonNullableLocalFixups() == false`

The first means:

- the pass is intentionally per-function and cheap to parallelize

The second means:

- clearing names is expected to help or preserve validation, not force Binaryen's generic local-type repair path

The source comment explicitly ties that to README behavior around nameless blocks.

## Core state: `branchesSeen`

Binaryen stores one important pass-global structure:

- `std::map<Name, std::set<Expression*>> branchesSeen`

It maps each currently relevant scope name to the exact descendant expressions that still use that target.

### Why this is a set of expressions, not a count

The pass needs more than a live/dead bit because one rewrite requires exact users:

- when merging a named parent block into a named child block
- every branch targeting the parent must be rewritten to the child name

That is why the set stores `Expression*` values.

### Why a single map is enough

Binaryen README rules say scope names are unique in the IR.
That means the pass can key directly by `Name` without a depth stack for shadowed labels.

That is easy to miss if you are thinking in raw wasm depth indices instead of Binaryen's named IR.

## Phase 1: collect scope-name uses

The generic visitor is:

- `visitExpression(Expression* curr)`

It calls:

- `BranchUtils::operateOnScopeNameUses(curr, ...)`

That helper iterates scope-name **uses** in the current expression.
In practice, that means more than plain `br`:

- branch targets
- switch / `br_table` targets
- `br_on*` family targets
- delegate-style targets
- other scope-name use fields covered by Binaryen's delegation macros

Binaryen inserts the current expression into `branchesSeen[name]` for each name use it finds.

### Important limitation

`RemoveUnusedNames.cpp` does not use a heavier reachability helper like `isBranchReachable(...)` from `branch-utils.h`.
So the pass should be understood as:

- syntactic label-use tracking
- not deep branch-reachability reasoning

That is why nearby passes such as `remove-unused-brs`, `precompute`, and `vacuum` still matter so much.

## Phase 2: handle the current break target name

Shared helper:

- `handleBreakTarget(Name& name)`

Behavior:

- if the name exists and no branch uses were recorded for it, clear the name
- otherwise erase the map entry for that name

So one helper does both:

- dead-label removal
- scope-pop cleanup once the current labeled scope has been processed

This is the pass's main liveness rule.

## Phase 3: block-specific merge logic

`visitBlock(Block* curr)` handles the most visible explicit rewrite.

Binaryen checks whether all of these hold:

- `curr` has a name
- `curr` has exactly one child
- that child is a `Block`
- the child also has a name
- `child->type == curr->type`

If so, Binaryen can make the parent and child share the child's label instead of keeping both block layers.

### Rewrite sequence

1. read the set `branchesSeen[curr->name]`
2. for each recorded branch expression:
   - call `BranchUtils::replacePossibleTarget(branch, curr->name, child->name)`
3. `child->finalize(child->type)`
4. `replaceCurrent(child)`
5. `handleBreakTarget(curr->name)`

### Why the type equality matters

A branch to the parent and a branch to the child are interchangeable here only if the blocks agree on the value type they yield.

That is why same-type matching is not optional polish; it is the semantic safety check.

### Easy-to-miss nuance

This merge path only runs when the child still has a name.
If the child name was already removed earlier, then explicit merge is unnecessary or different because:

- the child may already be on the path to becoming an implicit nameless block
- later emission or cleanup will often erase that layer anyway

So explicit merge and implicit-block disappearance are related, but they are not the same mechanism.

## Phase 4: loop demotion

`visitLoop(Loop* curr)` does:

1. `handleBreakTarget(curr->name)`
2. if the loop name is now gone and `curr->body->type == curr->type`, `replaceCurrent(curr->body)`

This is a narrow rule.

A loop matters semantically only if someone branches to its label as a continue target.
Once no remaining name use needs the label, the loop wrapper can collapse into its body **when** type equality makes that safe.

Important negative rule:

- no unused-label loop demotion on type mismatch

The dedicated official test covers that exact family.

## Phase 5: try / delegate handling

`visitTry(Try* curr)` is special:

1. `handleBreakTarget(curr->name)`
2. `visitExpression(curr)`

The explicit generic visit is required because a `try` carries not only its own scope name definition but also an optional delegate target use.

So this pass has a real delegate story, even though most examples focus only on blocks and loops.

## Phase 6: function-end sentinel cleanup

`visitFunction(Function* curr)` does two things:

- `branchesSeen.erase(DELEGATE_CALLER_TARGET)`
- `assert(branchesSeen.empty())`

`DELEGATE_CALLER_TARGET` is the shared pseudo-name for delegating to the caller rather than to an in-function scope.

This means the final invariant is:

- every real in-function scope-name use must have been consumed by the time we leave the function
- only the caller sentinel is allowed to survive to the final cleanup point

## What this pass depends on

- `WalkerPass` / `PostWalker`
- `BranchUtils::operateOnScopeNameUses(...)`
- `BranchUtils::replacePossibleTarget(...)`
- the `DELEGATE_CALLER_TARGET` sentinel
- Binaryen control-name uniqueness and implicit-block rules from `README.md`
- simple node-type checks and type equality

## What this pass does **not** depend on

- CFG analyses
- dominance
- liveness
- `Effects`
- `LocalGraph`
- `ReFinalize`
- type-updating helpers
- EH repair helpers
- non-nullable-local fixups

That absence is a big teaching point.
The pass sounds more global than it really is.

## Why neighboring passes are part of the meaning

The official combo tests show that `remove-unused-names` is best understood as a cleanup enabler inside a cluster, not as a self-sufficient control optimizer.

- `precompute` can make a branch destination constant, which then makes labels removable.
- `remove-unused-brs` can delete or retarget exits, which then makes labels removable.
- `vacuum` can erase inert wrappers exposed by label removal.
- `merge-blocks` and `code-folding` benefit when unnecessary named wrappers are already gone.

So the honest summary is not just:

- removes dead names

It is also:

- repeatedly removes dead control labels at the exact moments when nearby cleanup passes have opened new opportunities.

## What this pass does **not** do

These non-goals are important to keep explicit:

- no wasm name-section stripping
- no generic dead-branch proof
- no arbitrary flattening of all nested blocks
- no code motion
- no trap reasoning
- no type repair beyond the very local same-type checks in the source
- no broad structural cleanup without help from other passes

## Bottom line

Binaryen `remove-unused-names` is deliberately tiny.

Its defining rule is:

- keep only control labels that syntactic scope-name uses still need, and collapse the narrow block/loop wrapper families that become equivalent once those labels are gone.

The reason it still deserves a real dossier is that the surrounding contract includes:

- Binaryen control-name semantics
- implicit-block emission behavior
- delegate caller bookkeeping
- and repeated scheduler placement after other cleanup passes change label liveness

A future parity port that only “removes some unused labels” without preserving those surrounding rules is still incomplete.
