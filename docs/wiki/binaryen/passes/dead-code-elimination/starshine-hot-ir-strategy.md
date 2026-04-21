---
kind: concept
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0134-2026-04-20-dead-code-elimination-binaryen-research.md
  - ../../../raw/research/0203-2026-04-21-dead-code-elimination-source-confirmation-followup.md
  - ../../../../../src/passes/dead_code_elimination.mbt
  - ../../../../../src/passes/dead_code_elimination_test.mbt
  - ../../../../../src/passes/dead_code_elimination_live_repro_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./typed-control-voidification-and-eh.md
  - ./wat-shapes.md
---

# Current Starshine `dead-code-elimination` strategy

This page is the local “what is actually implemented today?” companion to the upstream Binaryen strategy page.

## Short version

The 2026-04-21 source-confirmation follow-up changed the upstream comparison point.
Current Starshine `src/passes/dead_code_elimination.mbt` no longer looks like a HOT-native port of Binaryen `version_129` `DeadCodeElimination.cpp`.
Instead, Starshine currently implements a **broader DCE-like cleanup family** than the real upstream pass.

Binaryen `version_129` uses a much smaller pass:

- one post-walk AST pass
- `TypeUpdater` as the central helper
- dead-suffix trimming after the first unreachable child
- a few narrow control-type-to-`unreachable` rules
- and one conditional `EHUtils::handleBlockNestedPops(...)` repair

Current Starshine uses:

- HOT-region traversal and rewrite helpers
- cached branch-user maps, fallthrough maps, purity maps, and node-use data
- explicit root and region editing helpers
- detached-subtree deletion
- explicit `unreachable` tail materialization
- several HOT-specific payload-forwarder and split-wrapper rewrites needed for artifact-safe lowering
- pass-manager raw-skip heuristics when a function obviously has no DCE candidates

So the local pass is best understood as:

- a larger Starshine-local cleanup pass that overlaps some of Binaryen `dce`'s reachability goals,

not:

- a direct line-by-line port of Binaryen `DeadCodeElimination.cpp`,
- and not even a close one-to-one semantic match for every subfamily named in older local docs.

## What Starshine already models well

## 1. Overlap with the upstream pass is concentrated in unreachable-shape handling

The local pass still overlaps most clearly with Binaryen on:

- unreachable-tail pruning
- explicit tail repair for non-fallthrough final control
- branch-sensitive control cleanup

But unlike real upstream `version_129` `dce`, Starshine also owns broader dead dropped-value and dead typed-control cleanup families locally.

## 2. Branch-target and fallthrough awareness

Binaryen's small `TypeUpdater`-plus-structure checks become a larger cache story locally.
Starshine builds and caches:

- whether any branches exist at all
- incoming branches by label
- branch users by label
- fallthrough facts by node

That is not the same implementation shape as upstream, but it is aiming at the same safety boundary:

- do not simplify control structure as if it were a plain sequence when live branches still care about it

## 3. Dead pure-value cleanup plus side-effect preservation

The local file has explicit purity analysis and dead-subtree cleanup logic.
That matches the Binaryen idea that dead pure values can disappear, while effectful work must remain.

## 4. Explicit `unreachable` tail handling is part of the local contract too

Like Binaryen, current Starshine has explicit helpers for:

- deciding whether a rewritten region still needs a trailing `unreachable`
- checking whether one is already present
- inserting one when it is required

This is an important sign that the local implementation understands the same “simplify, but stay well-typed” rule.

## 5. Artifact-backed reduced coverage is much wider locally than upstream's shipped DCE files

The in-tree local test corpus includes many HOT-specific survival families, including:

- pure-drop preservation and impure-drop retention
- unreachable-root pruning
- typed block / `if` / loop dead-result cleanup
- payload-forwarder rewrites
- split `local.set` wrapper rewrites
- detached label-owner safety
- detached shared-subtree cleanup
- live reproductions for exact lowering-sensitive carrier families
- raw-skip perf coverage
- native debug-artifact replay coverage

That does not automatically mean Starshine is fully upstream-parity complete.
But it does mean the local implementation has already accumulated a lot of real-world HOT-specific lessons.

## Important structural differences from Binaryen

## 1. Binaryen's `visitDrop(...)` becomes a much larger region-rewrite story locally

Binaryen's source has one central `visitDrop(...)` function.
Current Starshine distributes the same overall job across a larger helper cluster such as:

- `dead_code_elimination_try_voidify_split_drop_control`
- `dead_code_elimination_voidify_control`
- `dead_code_elimination_finish_nonfallthrough_final_root`
- `dead_code_elimination_ensure_explicit_unreachable_tail`

That is a local HOT/writeback reality, not a contradiction of the upstream contract.

## 2. Starshine has HOT-specific branch-payload and wrapper rewrites that are not visible in upstream AST DCE

The local file contains sizable logic for families like:

- `dead_code_elimination_try_rewrite_branch_payload_forwarder`
- `dead_code_elimination_try_rewrite_split_local_set_wrapper_forwarder`
- `dead_code_elimination_try_fold_nonfallthrough_prefix_into_branch_payload`

Those are local implementation details that exist because HOT lifting/lowering and artifact replay exposed concrete structural hazards there.

Important beginner correction:

- these are part of how Starshine currently survives real HOT/lowering shapes
- they are **not** evidence that upstream Binaryen DCE is secretly defined by those exact helper families

## 3. Detached-node cleanup is more explicit locally

Binaryen largely relies on AST rewrites plus later flatten/refinalize cleanup.
Starshine also has explicit detached-node collection and deletion helpers because HOT nodes and shared subtrees make “was this really detached?” more operationally important in-tree.

## 4. Raw-skip behavior is a deliberate local strategy

`pass_manager.mbt` has explicit raw-skip logic for DCE.
The local pipeline can skip HOT lifting entirely when the raw instruction stream obviously has no DCE candidates.

The perf tests lock several examples of that behavior in place, including:

- straight-line value-returning functions
- straight-line void direct calls
- branchless void structured control
- branchless typed final `if`
- branchy typed final control with only live typed results

And they also lock the opposite boundary:

- real dead-drop work and nonfallthrough typed final control must **not** take the raw-skip fast path.

This is a big local implementation fact because it explains why the top-level saved artifact DCE slot could match Binaryen while still reporting `starshinePassSkippedRaw = true`.

## Current honest parity state

## Top-level generated-artifact audit

The saved generated-artifact `-O4z` audit recorded for the top-level DCE slot:

- `normalizedWatEqual = true`
- `canonicalFuncPrettyEqual = true`
- `wasmEqual = false`
- `starshinePassSkippedRaw = true`

So the honest reading is:

- the local fast path preserved the same normalized semantic outcome there
- but that top-level success is not proof that the full HOT rewrite surface was exercised on that artifact slot

## Debug-artifact replay coverage exists in-tree

`src/cmd/cmd_wbtest.mbt` contains a native regression ensuring:

- `run_cmd_with_adapter validates dead-code-elimination on debug artifact`

That matters because it proves the pass can run through the checked-in large artifact in the main supported path.

## The backlog is now mostly about runtime and the remaining native divergence families

`agent-todo.md` keeps the current frontier explicit.
The local DCE work is no longer framed as a newly isolated pass-local semantic mismatch in the ordinary source-mode path.
The live work is now mainly:

- runtime budget
- valid-baseline ordered-prefix replay proof
- the remaining native-release lowering divergence families that still show up in artifact replay

That is a healthier place to be than the older “DCE still corrupts the chain immediately” story.

## What a future local refactor must preserve

If Starshine rewrites this pass again, keep these durable local lessons:

- preserve the same high-level contract as Binaryen: dead-result cleanup plus unreachable-tail pruning, not generic dead-store elimination
- keep branch-target and fallthrough reasoning explicit
- keep explicit `unreachable` tail insertion honest
- preserve the raw-skip fast path only for genuinely no-op families
- keep HOT-specific payload-forwarder and split-wrapper repairs clearly labeled as local lowering-survival logic, not as the upstream semantic definition of DCE
- preserve detached-subtree cleanup and label-owner safety
- keep artifact-backed reduced repro tests for the known hard shapes

## Best current mental model

Upstream Binaryen tells us **what DCE means**:

- effect-aware unused-result and unreachable cleanup with type/EH repair

Current Starshine tells us **what a HOT-IR implementation needs in order to survive real artifact replay and lowering**.

Both matter.
But when those two stories diverge, treat Binaryen `version_129` as the semantic oracle and the local file as the current execution strategy that still has to keep proving itself against that oracle.
