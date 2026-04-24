---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md
  - ../../../raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0183-2026-04-21-rereloop-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReReloop.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./flat-cfg-builder-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Binaryen strategy for `rereloop`

## What the pass really is

The reviewed implementation is a **small function-local restructuring wrapper** around Binaryen's reusable `CFG::Relooper`.
It does not directly perform a large catalog of control-flow optimizations itself.

The real strategy is:

- require already-flat IR
- construct CFG blocks and edges from that flat IR
- let the generic Relooper derive structured shapes
- render those shapes back to wasm
- repair final typing details and refinalize

So the best mental model is:

- **flat IR -> CFG -> generic relooper -> structured IR**
- not a generic one-pass AST simplifier

## Public surface and scheduler meaning

The 2026-04-24 raw source manifest in [`../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md`](../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md) anchors this page to the official `version_129` release and the opened current-`main` spot-check surfaces.

`src/passes/pass.cpp` registers the pass publicly as:

- `rereloop` — `re-optimize control flow using the relooper algorithm`

That public description is directionally true, but it hides two key facts that matter for a port:

1. the pass depends on `flatten` having run first
2. the heavy lifting is delegated to the shared `cfg/Relooper.*` engine

The same upstream file also keeps an explicit TODO in the `optimizeLevel >= 4` path after:

- `flatten`
- `simplify-locals-notee-nostructure`
- `local-cse`

and then says:

- `// TODO: add rereloop etc. here`

So the durable scheduler lesson is:

- `rereloop` is an upstream public pass
- it is not in the current reviewed default no-DWARF `-O` / `-Os` path
- Binaryen still conceptually associates it with the flatten-era aggressive pipeline

## Local-vs-upstream naming split

The local Starshine registry uses:

- `re-reloop`

The upstream public pass name is:

- `rereloop`

That split is a naming mismatch, not an algorithm split.
A future port should document or normalize that alias explicitly.

## Core pass state

`ReReloop.cpp` keeps only a few important pieces of mutable state:

- `std::unique_ptr<CFG::Relooper> relooper`
- `std::unique_ptr<Builder> builder`
- `CFG::Block* currCFGBlock`
- `std::map<Name, CFG::Block*> breakTargets`
- `std::vector<TaskPtr> stack`

That small state footprint is the first clue that the pass is mostly an adapter into the generic relooper.

## Phase 1: verify flatness

The first line of real work in `runOnFunction` is:

- `Flat::verifyFlatness(function)`

This is a hard precondition.
The pass is written with the assumption that:

- control-flow nodes do not produce concrete values
- the function body itself does not produce a concrete value directly
- most nested operands have already been spilled to locals
- `local.tee` is gone

This matters because the pass later reuses branch and if conditions directly as CFG edge conditions.
That is only safe because flatness makes those conditions simple enough.

## Phase 2: build CFG blocks from flat IR

The helper methods are tiny but important:

- `makeCFGBlock()` creates an empty CFG block backed by an empty wasm block
- `setCurrCFGBlock(...)` finalizes the previous current block before switching
- `startCFGBlock()` starts a fresh current CFG block
- `finishBlock()` finalizes the backing wasm block

The pass therefore incrementally emits code into temporary CFG blocks while scanning flat expressions.
It is not editing the final structured wasm directly.

## Phase 3: map flat labels into CFG targets

The `breakTargets` map is the bridge between named flat control flow and CFG edges.

### Named `block`

When a `block` has a name:

- the pass creates a fresh later CFG block
- records it under that name in `breakTargets`
- scans the block contents first
- and later adds a fallthrough branch into the join block

### Named `loop`

When a `loop` has a name:

- the pass creates a fresh top CFG block for the loop entry
- records that top block under the loop name
- adds a branch from the pre-loop block to the new top block
- then scans the body

That is the actual shape-preserving contract for labeled blocks and loops.
They become CFG destinations first, and only later become structured shapes again.

## Phase 4: task-driven CFG construction

The pass uses an explicit task stack rather than a recursive walker over arbitrary nested structure.
That makes sense because the input is already flat.

## `TriageTask`

This is the dispatcher.
It checks the current expression kind and forwards to a more specific task or local handling path.

## `BlockTask`

This handles named-block join creation and linear sequencing of block contents.
The block body list is pushed onto the task stack in reverse order so execution order is preserved when tasks are popped.

## `LoopTask`

This handles loop-top target creation and entry-edge insertion.
The body is then scanned normally.

## `IfTask`

This is the most involved task.
It effectively lowers one flat `if` into a CFG pattern with:

- one remembered condition block
- one true-entry block
- optional false-body scan
- one or more `after` blocks that join the arms

The pass itself does not attempt sophisticated branch simplification here.
It only creates a faithful CFG for the generic relooper.

## `BreakTask`

This converts a flat `br` or `br_if` into a CFG edge.
If the break is conditional, the pass also creates a fallthrough block.
If it is unconditional, it stops control flow immediately.

## `SwitchTask`

This lowers `switch` / `br_table` by:

- storing the switch condition on the current CFG block
- grouping case indices by branch target
- adding grouped switch edges
- handling the duplicate-default-target case via a temporary CFG block

That last detail is a real visible implementation rule, not an accident.
It prevents duplicate edges to the same target in the CFG representation.

## `ReturnTask` and `UnreachableTask`

These are deliberately simple.
The pass reuses the original `return` or `unreachable`, appends it to the current block, and then stops control flow.

## Hard EH boundary

`triage(...)` explicitly checks:

- `Try`
- `Throw`
- `Rethrow`

and aborts with a fatal error saying `ReReloop does not support EH instructions yet`.

That is a hard source-backed boundary.
A future Starshine port must keep EH unsupported or widen it intentionally with new research, not by accident.

## Phase 5: stop control flow by creating a fresh block

`stopControlFlow()` just calls `startCFGBlock()`.
That is an important design choice.

Instead of proving all later code unreachable immediately, the pass:

- closes the current flow
- starts a fresh block
- lets later CFG analysis and rendering decide what survives and what becomes dead/skip structure

This is one reason the rendered output can contain helper blocks or visible boilerplate that later cleanup passes can still simplify.

## Phase 6: patch dead-end CFG blocks before render

After the temporary CFG exists, the pass scans all CFG blocks.
If a block has no outgoing branches and its backing wasm block is not already `unreachable`, it appends:

- `return` if the function result is `none`
- `unreachable` otherwise

This is a correctness patch.
Without it, a dead-end CFG block might accidentally flow into whatever the generic renderer places afterward.

## Phase 7: call the generic relooper

The next steps are:

- `relooper->Calculate(entry)`
- build a fresh helper local `temp : i32`
- construct `CFG::RelooperBuilder builder(*module, temp)`
- `function->body = relooper->Render(builder)`

That i32 helper local is not a semantic program variable.
It is the label variable used by the generic relooper when rendering multiple-entry shapes.

This is one of the easiest visible surprises in test output.
The extra local is part of the generic restructuring machinery.

## What the generic `cfg/Relooper.*` helper contributes

The helper files make several durable facts explicit.

### Shape model

The generic relooper rebuilds structure from three shape kinds:

- `Simple`
- `Multiple`
- `Loop`

### Label-local model

Multiple-entry shapes may require an i32 label variable.
The helper emits:

- `local.set` into the label helper
- checks against that label helper
- block break names like `block$<id>$break`
- loop continue names like `shape$<id>$continue`

### Condition purity rule

`cfg/Relooper.h` explicitly documents that branch conditions must not have side effects because the generic relooper may reorder or eliminate condition checking.

For `rereloop`, that purity requirement is satisfied by construction only if the input is already flat enough.
That is another reason the flatness precondition is essential, not cosmetic.

## Phase 8: final result-type repair and `ReFinalize`

After render, the pass checks one more corner case.
If the function should return a value but the rendered body has type `none`, Binaryen appends an explicit `unreachable` sequence.

The source comment explains the reason:

- the generic relooper may emit structurally fallthrough-looking boilerplate for switch handling even when the path is actually unreachable

Finally the pass runs:

- `ReFinalize().walkFunctionInModule(function, module)`

So the real contract ends with refinalization.

## Why later cleanup passes still matter

The pass intentionally focuses on correctness and structured reconstruction first.
It does not try to erase every helper block or helper label artifact it creates.

That is why later cleanup passes such as `merge-blocks`, `remove-unused-brs`, `remove-unused-names`, `vacuum`, or other local simplifiers can still matter after a future `rereloop` slot.

This is a source-backed inference from the implementation shape and the visible boilerplate in `flatten_rereloop.wast`.

## Important implementation boundaries

## 1. No automatic flattening

The pass does not run `flatten` itself.
Trying to teach it that way will hide the real dependency.

## 2. No EH support

This is a hard fatal boundary, not a silent no-op.

## 3. No source-faithful round-trip promise

The pass reconstructs valid structure, not the original source author's exact nesting.

## 4. No default-pipeline status today

The explicit `-O4` TODO is not the same thing as an active optimize-path slot.

## 5. Helper boilerplate is part of the contract

The helper label local, helper blocks, and dead-end terminator repair are intentional pieces of the implementation.
A port must preserve them before later cleanup passes smooth them out.

## Beginner-facing summary of the real contract

If you want the shortest accurate rule, it is this:

- require flat IR
- translate flat top-level control constructs into CFG blocks and edges
- let Binaryen's generic relooper rebuild structured wasm
- repair any apparent missing result path with `unreachable`
- refinalize the result

That is the real Binaryen strategy for `rereloop`.

## Sources

- [`../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md`](../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md)
- [`../../../raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md`](../../../raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0183-2026-04-21-rereloop-binaryen-research.md`](../../../raw/research/0183-2026-04-21-rereloop-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReReloop.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
