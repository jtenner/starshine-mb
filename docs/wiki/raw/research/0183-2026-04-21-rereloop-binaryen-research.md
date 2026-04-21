---
kind: research
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../binaryen/passes/tracker.md
  - ../../binaryen/passes/index.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
  - https://github.com/WebAssembly/binaryen/releases/tag/version_129
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReReloop.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_rereloop.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/opt_flatten.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReReloop.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_rereloop.wast
related:
  - ../../binaryen/passes/rereloop/index.md
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/dataflow-optimization/index.md
  - ../../binaryen/passes/tracker.md
---

# Binaryen `rereloop` research

## Why this pass was chosen now

The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only dossier wave are already covered in the local tracker.
That meant this thread needed either:

- a clearly justified major-gap fallback in an already-deep folder, or
- a new source-backed upstream-only registry expansion.

I chose the second path.

`rereloop` is a good expansion target because all of the following are true:

- the local registry in `src/passes/optimize.mbt` still names the pass family under the removed alias `re-reloop`
- upstream Binaryen `version_129` exposes a real public pass named `rereloop`
- upstream `pass.cpp` keeps an explicit `// TODO: add rereloop etc. here` right after the `flatten -> simplify-locals-notee-nostructure -> local-cse` `-O4` slot
- existing local docs already mention it only as a flatten neighbor, not as its own documented pass contract
- `agent-todo.md` currently has **no dedicated `rereloop` / `re-reloop` slice**

So this is not a random expansion. It is a real local-registry pass name with a real upstream implementation, a real public CLI surface, and a real documented relationship to the flatten-era aggressive pipeline.

## Short answer

`rereloop` is not “flatten in reverse.”
It is a two-stage pass:

1. require already-flat Binaryen IR
2. rebuild a control-flow graph from that flat IR and hand it to Binaryen's generic `CFG::Relooper`

The pass's own implementation is small.
Most of the heavy restructuring logic lives in the reusable `cfg/Relooper.*` helper.
So the actual contract is:

- verify the function is flat
- split the flat body into CFG blocks using a small task stack
- represent named block / loop exits as CFG edges
- special-case `br_table` / `switch` edges, returns, and explicit `unreachable`
- reject EH instructions outright
- let `Relooper` synthesize structured wasm again
- refinalize the result

## Source files that matter most

### Core pass files

- `src/passes/ReReloop.cpp`
  - the pass itself
  - the flat-IR-to-CFG builder
  - the EH rejection boundary
  - the function-result repair and `ReFinalize` handoff
- `src/passes/pass.cpp`
  - public registration of `rereloop`
  - the `-O4` aggressive-pipeline TODO that explicitly mentions adding it later

### Helper files the pass actually depends on

- `src/cfg/Relooper.h`
  - the builder API, block/branch model, shape model, and important invariants
- `src/cfg/Relooper.cpp`
  - the generic structured-control reconstruction engine used by the pass
  - especially the multiple-entry label-local machinery and shape rendering
- `src/ir/flat.h`
  - the hard precondition and the precise meaning of “flat”
- `src/wasm-builder.h`
  - used both by the pass and by the generic relooper rendering path

### Tests that define the practical contract

- `test/lit/passes/flatten_rereloop.wast`
  - the real dedicated pass test surface for `--flatten --rereloop`
  - covers skip-empty, branch-table, merging, and helper-block patterns
- `test/lit/passes/opt_flatten.wast`
  - confirms `--flatten --rereloop` works on a simple flatness-oriented `-O1` example too

## Local-vs-upstream naming split

This matters enough to say explicitly.

- upstream public pass name: `rereloop`
- local removed-registry name in `src/passes/optimize.mbt`: `re-reloop`

So future Starshine docs and code should treat `re-reloop` as a local alias for the upstream public pass `rereloop`, not as evidence of two distinct Binaryen passes.

## What the pass sounds like versus what it actually does

### What the name can make people assume

A beginner might guess:

- generic control-flow optimization
- arbitrary CFG simplification
- maybe a post-`flatten` cleanup that just removes temp locals
- maybe a broad inverse of flatten that restores the original source-like structure

### What the reviewed `version_129` implementation actually does

It is much narrower and more mechanical:

- it only accepts already-flat Binaryen IR
- it only understands a limited set of top-level flat control forms while scanning
- it constructs CFG blocks and edges from that flat surface
- it delegates the real shape reconstruction to the reusable `Relooper`
- it deliberately bails out on EH
- it may emit extra structure and a helper label local that later cleanup passes can simplify

That means the pass is best taught as:

- **flat-IR CFG rebuilding plus generic Relooper restructuring**
- not a general-purpose high-level “make control flow pretty again” pass

## Main algorithmic phases in `ReReloop.cpp`

## 1. Verify flatness first

The very first operation in `runOnFunction` is:

- `Flat::verifyFlatness(function)`

That means the flatness requirement is not folklore or scheduler advice.
It is a hard correctness precondition.

The formal flatness contract in `ir/flat.h` is important here:

- control-flow structures must not carry concrete values
- local.tee is disallowed
- nested children must be constants, `local.get`, `unreachable`, or `ref.as_non_null`
- the function body itself must not carry a concrete value

That flatness property is what makes the pass's own CFG builder so small.
It never needs to recursively mine arbitrary nested tree structure for outgoing edges.

## 2. Build CFG blocks incrementally

The pass owns two pieces of mutable state while scanning:

- `currCFGBlock`
- `breakTargets`

It also uses a small explicit task stack instead of a recursive structured walker.
The task kinds are:

- `TriageTask`
- `BlockTask`
- `LoopTask`
- `IfTask`
- `BreakTask`
- `SwitchTask`
- `ReturnTask`
- `UnreachableTask`

This is the real implementation structure:

- triage a flat top-level expression
- maybe schedule more tasks
- maybe create more CFG blocks
- maybe add branch edges
- maybe terminate current flow and start a fresh block

## 3. Convert named block structure into join targets

Named `block`s are handled specially.
If a block has a label name:

- the pass creates a fresh later CFG block
- records it in `breakTargets[name]`
- pushes a deferred `BlockTask`
- scans the block body now
- and when the deferred task runs, it adds a fallthrough edge into the later block

So a named block becomes a join target in the temporary CFG.
An unnamed block is just linear sequencing.

This is one of the easiest points to misunderstand.
The pass is not preserving the original block shell directly.
It is translating it into a CFG shape that the generic `Relooper` can later rebuild.

## 4. Convert named loops into loop-entry targets

Named `loop`s are also special:

- before scanning the body, the pass creates a fresh CFG block for the top
- records the loop label name as a break target pointing at that top block
- adds an edge from the pre-loop block to the loop-top block
- then scans the body

This is how a flat `br $loopLabel` later becomes a loop backedge candidate for the generic relooper.

## 5. Lower `if` into condition, then-arm, else-arm, and after blocks

The `IfTask` is the most stateful local helper.
Its flow is:

- remember the current CFG block as the condition block
- create a block for `ifTrue`
- add a conditional branch from the condition block to the true block
- scan `ifTrue`
- after that, create an `after` block and add the false/fallthrough edge
- if there is an `ifFalse`, scan that too and finally join both ends to a new `after`

So the pass's own `if` lowering is not a tree rewrite.
It is CFG edge construction.

Because the IR is already flat, the condition expression can be used directly as the edge condition.
That is safe because flatness bans complicated nested control-value producers there.

## 6. Lower `br` and `br_if`

`BreakTask` reuses the current break condition directly:

- add a branch from the current block to `breakTargets[curr->name]`
- if the break is conditional, also create a fallthrough `after` block
- if the break is unconditional, stop control flow immediately

The important subtlety is the unconditional case.
The pass does not try to be clever about unreachable suffixes there.
It just calls `stopControlFlow()`, which begins a fresh CFG block for any later code.

That later code may end up dead or may be skipped/merged by the generic relooper.

## 7. Lower `switch` / `br_table`

`SwitchTask` uses `before->SwitchCondition = curr->condition` and then groups table indices by target label.
So the pass does not emit one branch per table entry.
It emits grouped switch branches per target CFG block.

A small but important corner case appears when the default target is also one of the explicit case targets.
In that situation the pass creates a temporary CFG block so the default edge is not a duplicate branch to the same target.

That behavior is easy to miss if you only look at the public pass description.
It is an actual implementation detail that shapes the rendered output.

## 8. Reuse `return` and `unreachable` directly

For `return` and explicit `unreachable`, the pass simply appends the instruction to the current CFG block and then stops control flow.

This is another useful teaching point:

- `rereloop` does not invent semantic terminators here
- it preserves the explicit terminator when it already exists

## 9. Reject EH entirely

If triage sees `Try`, `Throw`, or `Rethrow`, the pass does not try to preserve them.
It hard-fails with:

- `ReReloop does not support EH instructions yet`

So EH is a hard unsupported boundary in `version_129`.
This is stronger than a silent no-op bailout.

## 10. Patch dead-end CFG blocks before calling the generic relooper

After the temporary CFG is built, `runOnFunction` iterates every CFG block.
If a block has no outgoing CFG branches and its code block is not already `unreachable`, Binaryen appends:

- `return` for a `none`-result function
- `unreachable` for a non-void function

This is crucial.
Without it, a CFG dead end could accidentally fall through into whatever structured code the generic renderer places next.

So this dead-end patch is part of correctness, not optional polish.

## 11. Render through the generic `CFG::Relooper`

Only after all of that does the pass call:

- `relooper->Calculate(entry)`
- `relooper->Render(builder)`

The builder used here is `CFG::RelooperBuilder`, not the ordinary `Builder` alone.
The pass also allocates one fresh local:

- `builder.addVar(function, Type::i32)`

That helper local is the label variable used by the generic relooper for multiple-entry shapes.
It is not evidence that the original flat function needed another semantic variable.
It is Relooper bookkeeping.

## 12. Repair the function result type and refinalize

After render, the pass has one more correctness repair:

- if the function should return a value but the rendered body has type `none`, append `unreachable`

The source comment explains why: the generic relooper can emit boilerplate switch-handling structure that appears to fall out structurally even though the path is actually unreachable.

Finally the pass runs:

- `ReFinalize().walkFunctionInModule(function, module)`

So refinalization is part of the official pass contract.
A future Starshine port must preserve it.

## What `cfg/Relooper.*` adds beyond the pass itself

The pass implementation is only half the story.
The helper `cfg/Relooper.*` explains the rest of the behavior readers will see in tests.

Important durable pieces:

- shapes are `Simple`, `Multiple`, and `Loop`
- `Multiple` shapes use a helper i32 label local for multi-entry dispatch
- block breaks are named `block$<id>$break`
- loop continues are named `shape$<id>$continue`
- branch conditions must be side-effect free because the generic relooper may reorder or eliminate condition checks

That last point is especially important.
`rereloop` itself does not prove arbitrary condition purity.
It relies on the already-flat input discipline to make those conditions simple enough.

## What the tests prove

### `flatten_rereloop.wast`

This file is the real contract surface.
It shows:

- simple flat `if` inputs turning into structured `if` + `return` / `unreachable` forms
- branch-table ladders becoming structured block/switch wrappers
- chains of empty labeled blocks getting collapsed into smaller breakable shells
- merging of if/else-exit shapes into one final `return`
- skip opportunities when one branch is empty or unreachable
- helper local and helper block boilerplate that later passes may simplify

### `opt_flatten.wast`

This file is smaller, but it proves that the `flatten -> rereloop` combination works on a simple optimization example and still respects flatness-oriented constraints such as `ref.as_non_null` remaining legal in flat mode.

## Current-main drift check

I compared the reviewed upstream `version_129` `ReReloop.cpp` and `flatten_rereloop.wast` surfaces against current `main`.

Result:

- no implementation drift was observed in those reviewed files

So `version_129` remains a good release oracle for this dossier.

## Most important beginner-facing misunderstandings to avoid

### Misunderstanding 1: this is a default optimization pass

It is not in the current no-DWARF `-O` / `-Os` path.
Upstream `pass.cpp` only leaves a TODO to maybe add it in the `-O4` flatten-era cluster later.

### Misunderstanding 2: this pass runs flatten internally

It does not.
It requires flatten first and aborts if the IR is not flat.

### Misunderstanding 3: this is a generic EH-capable CFG optimizer

It is not.
`Try`, `Throw`, and `Rethrow` are hard unsupported boundaries in the pass itself.

### Misunderstanding 4: `rereloop` restores the original structured AST exactly

It does not attempt source-faithful round-tripping.
It rebuilds **a valid structured form** through the generic Relooper, which may introduce helper label locals and extra block structure.

## Porting takeaways for Starshine

A faithful future Starshine port would need to preserve at least these invariants:

- local alias `re-reloop` should map to upstream `rereloop`
- enforce the hard Flat IR precondition
- build CFG blocks from flat top-level structure, not from arbitrary nested trees
- model named block and loop labels as CFG targets
- preserve the special grouped `br_table` / default-target handling
- hard-stop or explicitly scope EH support instead of silently miscompiling it
- patch dead-end CFG blocks before rendering
- allocate and thread the helper label local for multi-entry shapes
- repair apparent `none`-typed fallthroughs in result functions with explicit `unreachable`
- refinalize after rendering

## Confidence and remaining uncertainty

Confidence is high on the central behavior because:

- the implementation file is short enough to audit directly
- the helper API and comments in `cfg/Relooper.h` explain the rendering model explicitly
- the dedicated lit file covers the main visible rewrite families
- current `main` matches the reviewed release on the checked surfaces

The main remaining uncertainty is not about the pass contract itself.
It is about future scheduler policy:

- upstream `pass.cpp` still says `// TODO: add rereloop etc. here`

So any statement about future default-pipeline placement would be an inference, not an established `version_129` fact.

## Practical conclusion

`rereloop` is a real, well-defined Binaryen pass, but its real contract is much narrower than the name suggests.
It is best understood as:

- **a Flat-IR-only CFG reconstruction pass that delegates structured rendering to the generic Relooper**

That is the durable lesson future Starshine work should preserve.
