---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md
  - ../../../raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0183-2026-04-21-rereloop-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../index.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flat-cfg-builder-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../flatten/index.md
  - ../dataflow-optimization/index.md
---

# `rereloop`

## Role

- `rereloop` is a real public Binaryen pass.
- It is currently **unimplemented** in Starshine's active optimizer and still lives in the local **removed** registry under the alias **`re-reloop`** in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- It is also **not** one of the already-audited saved generated-artifact `-O4z` skipped slots.
- Upstream `pass.cpp` does, however, keep an explicit `// TODO: add rereloop etc. here` immediately after the `flatten -> simplify-locals-notee-nostructure -> local-cse` `-O4` cluster.
- `agent-todo.md` currently has **no dedicated `rereloop` or `re-reloop` slice**.

## Why this pass matters

The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only dossier wave are already covered, so this folder is an explicit tracker expansion for another real local-registry pass.

`rereloop` is worth documenting because it fills a very specific teaching gap:

- existing local docs already explain `flatten`
- existing local docs already mention `flatten_rereloop.wast`
- but they only mention `rereloop` as a neighbor, not as its own pass contract

That omission matters because the pass is easy to mis-teach.
It is **not** just “undo flatten.”
The real `version_129` contract is:

- require flat IR first
- rebuild a CFG from that flat IR
- run Binaryen's generic `Relooper`
- render a new structured body
- refinalize the result

## Beginner summary

A good beginner mental model is:

1. `flatten` makes control flow easier to reason about mechanically.
2. `rereloop` then takes that flat form and turns it back into valid structured wasm.
3. The pass itself only builds a temporary CFG and hands it to Binaryen's reusable `Relooper` helper.
4. The final output can have different block labels, helper blocks, and a helper label local; it is a valid restructured form, not a source-faithful restoration.

So this pass is best taught as:

- **flat-IR CFG rebuilding plus generic structured rendering**
- not a default optimize pass
- not a generic EH-capable optimizer
- not a promise to reconstruct the original structure exactly

## Most important durable takeaways

- The local name `re-reloop` and the upstream public name `rereloop` refer to the same pass family.
- `Flat::verifyFlatness(function)` is a hard precondition, not just a scheduler hint.
- The pass only handles a narrow top-level flat control surface directly:
  - `block`
  - `loop`
  - `if`
  - `br`
  - `switch` / `br_table`
  - `return`
  - `unreachable`
- EH instructions are a hard unsupported boundary in `version_129`.
- Named blocks and loops become temporary CFG targets before the generic relooper rebuilds structure.
- Dead-end CFG blocks are patched with explicit `return` or `unreachable` before rendering.
- Rendering always allocates an `i32` helper local for the generic `RelooperBuilder` label variable.
- If a result-typed function renders to an apparent `none` body, the pass appends `unreachable` and then runs `ReFinalize`.
- A narrow 2026-04-24 current-main spot check did not surface teaching-relevant drift in the opened `ReReloop.cpp` and `flatten_rereloop.wast` surfaces.
- Current Starshine tracks only the local `re-reloop` spelling as a removed pass name, parses the explicit `--re-reloop` CLI flag, rejects it before writing output, hides it from help, and has no owner file or active backlog slice.

## What this pass sounds like versus what it actually does

What it sounds like:

- re-optimize control flow in general
- reverse flatten
- clean up ugly CFGs automatically

What it actually is in reviewed `version_129` sources:

- a small function-parallel pass that translates already-flat Binaryen IR into CFG blocks and edges
- a thin wrapper around the reusable `cfg/Relooper.*` engine
- a hard-EH-boundary, post-flatness, refinalizing restructuring pass

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Main implementation walkthrough: flatness precondition, task stack, CFG construction, generic Relooper render, and the post-render repair story.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./flat-cfg-builder-and-boundaries.md`](./flat-cfg-builder-and-boundaries.md)
  Focused guide to the easiest part to misread: the pass-local CFG builder, label-target handling, helper-label-local semantics, and the unsupported boundaries.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing the main positive restructuring families, the visible helper-block boilerplate, and the hard bailout cases.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future-port map: removed-registry `re-reloop` tracking, CLI parse and command rejection coverage, help-output hiding, Batch 2 breadcrumb, no owner file, no active backlog slice, and the flat-IR CFG/rendering proof a faithful port would need.

## Current maintenance rule

- Treat this folder as the canonical home for future `rereloop` / `re-reloop` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass for it.
- Keep the split from [`../flatten/index.md`](../flatten/index.md) explicit: `flatten` creates the required flat IR, but `rereloop` is the later CFG-to-structured rebuild step.
- Keep the split from default no-DWARF parity work explicit too: this pass may matter to future aggressive `-O4` parity work, but it is not in today's canonical `-O` / `-Os` queue.

## Sources

- [`../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md`](../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md)
- [`../../../raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md`](../../../raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0183-2026-04-21-rereloop-binaryen-research.md`](../../../raw/research/0183-2026-04-21-rereloop-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cli/cli_test.mbt`](../../../../../src/cli/cli_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReReloop.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_rereloop.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/opt_flatten.wast>
- Narrow freshness-check sources captured in [`../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md`](../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md):
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReReloop.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_rereloop.wast>
