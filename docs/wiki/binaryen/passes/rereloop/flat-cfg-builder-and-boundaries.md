---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-rereloop-current-main-recheck.md
  - ../../../raw/research/0484-2026-05-05-rereloop-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-30-rereloop-current-main-refresh.md
  - ../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md
  - ../../../raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0183-2026-04-21-rereloop-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReReloop.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Flat CFG builder, helper label local, and boundaries in `rereloop`

## Why this page exists

The biggest teaching trap in `rereloop` is assuming the pass just “calls a helper.”
That is only half true.

The pass itself still defines important correctness boundaries:

- what counts as acceptable flat input
- how labels become CFG targets
- how `br_if` / `br_table` are modeled
- when control flow is considered stopped
- when the generic helper must get an extra label local
- what input is rejected outright

This page focuses on that boundary layer.

## The pass-local CFG builder is small but exact

`ReReloop.cpp` builds CFG blocks whose backing code is an ordinary wasm `block`.
As it scans flat IR, it:

- appends simple non-control expressions to the current block
- turns named block/loop structure into CFG targets
- turns `if`, `br`, and `switch` into edges
- starts a fresh block whenever control flow stops

That means the pass-local builder is not trying to invent structure yet.
It is trying to produce a correct CFG for the generic relooper.

## Why flatness is a hard boundary

`flat.h` defines the exact input discipline.
The important consequences for `rereloop` are:

- branch and if conditions are simple enough to reuse as CFG-edge conditions
- control-flow values do not need special phi-like reconstruction at this layer
- `local.tee` is already gone
- complex nested tree patterns have already been spilled to locals

Without that discipline, the pass-local CFG builder would need many more legality checks.

## How labels become CFG destinations

### Named block labels

A named `block` becomes a deferred join target.
The pass records the label name in `breakTargets` and later creates the fallthrough edge into that target.

This is why a source-looking label may reappear in very different rendered structure later.
The original block shell was translated into a CFG join node first.

### Named loop labels

A named `loop` becomes an entry target for backedges.
The pass creates a fresh top CFG block and maps the loop label name to it.

This is the essential bridge from flat `br $loopLabel` traffic to generic loop reconstruction.

## The helper label local is not a user-visible semantic temp

The generic `RelooperBuilder` needs an `i32` local to dispatch among multiple-entry shapes.
`ReReloop.cpp` always allocates one before rendering.

Important beginner rule:

- this local exists for the generic renderer's internal label-dispatch protocol
- it is not evidence that the original function needed a new program variable

The helper's job is to remember which entry in a multi-entry region should run next.

## `switch` handling is more specific than it sounds

The pass-local builder groups switch-table indices by target label.
That means a `br_table` with repeated targets does **not** become one CFG edge per table slot.
It becomes one switch edge per distinct target plus a default edge.

There is also a real special case:

- if the default target is already one of the explicit grouped targets, the pass inserts a temporary CFG block so the default does not duplicate an edge to the same target

That is not generic cleanup trivia.
It is part of the exact `version_129` builder contract.

## What “stop control flow” really means here

`stopControlFlow()` does not prove later code dead in-place.
It simply starts a new CFG block.

That means the pass-local builder preserves later flat code in a fresh CFG region and lets later rendering plus cleanup decide how visibly dead or skipped that region becomes.

This explains why some lit outputs still contain helper blocks that look emptier or more indirect than a hand-written simplifier would emit.

## The dead-end terminator patch is easy to miss

Before rendering, the pass scans all CFG blocks and appends:

- `return` for void functions
- `unreachable` for non-void functions

whenever a block has no outgoing edges and is not already `unreachable`.

This is a crucial correctness rule.
It prevents dead-end CFG blocks from accidentally flowing onward after rendering.

## EH is a hard unsupported boundary

The pass does not quietly skip exception-handling constructs.
It aborts on:

- `Try`
- `Throw`
- `Rethrow`

That tells future Starshine work two things:

- there is no honest partial-EH story in the reviewed pass
- any future widening would need new source-backed design work, not just incremental bug fixes

## The generic helper's side-effect rule matters

`cfg/Relooper.h` says branch conditions must not have side effects because the generic helper may reorder or eliminate condition checks.

A good teaching shortcut is:

- `rereloop` works because flatness has already simplified conditions enough that this helper rule can hold

That is the cleanest reason to keep the flatness precondition and helper contract documented together.

## What is easy to misunderstand

### Misread: `rereloop` is a pretty-printer for CFGs

Not quite.
It is a structured-code generator with very specific helper-label and helper-block semantics.

### Misread: the helper local is optional polish

No.
It is part of the generic multiple-entry rendering protocol.

### Misread: unlabeled and labeled blocks behave the same

No.
Only named blocks become explicit break targets in the pass-local CFG.

### Misread: the pass is safe on arbitrary nested Binaryen IR

No.
It is designed specifically for already-flat input and rejects EH explicitly.

## Porting checklist for this boundary layer

A future Starshine port should preserve these exact rules:

- enforce flatness up front
- map named blocks to deferred join CFG targets
- map named loops to loop-entry CFG targets
- preserve grouped switch-target handling
- preserve the duplicate-default-target temp-block rule
- stop control flow by starting a fresh CFG block
- patch dead-end CFG blocks with explicit terminators before render
- allocate and thread the helper `i32` label local
- keep EH unsupported until widened deliberately

## Sources

- [`../../../raw/binaryen/2026-05-05-rereloop-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-rereloop-current-main-recheck.md)
- [`../../../raw/research/0484-2026-05-05-rereloop-current-main-recheck.md`](../../../raw/research/0484-2026-05-05-rereloop-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md`](../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md)
- [`../../../raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md`](../../../raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0183-2026-04-21-rereloop-binaryen-research.md`](../../../raw/research/0183-2026-04-21-rereloop-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReReloop.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
