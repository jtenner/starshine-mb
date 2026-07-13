---
kind: entity
status: supported
last_reviewed: 2026-07-12
sources:
  - ../../../raw/binaryen/2026-07-11-ssa-current-main-and-local-admission-recheck.md
  - ../../../raw/binaryen/2026-04-26-ssa-port-readiness-primary-sources.md
  - ../../../raw/research/0402-2026-04-26-ssa-port-readiness.md
  - ../../../raw/research/0321-2026-04-24-ssa-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0207-2026-04-21-ssa-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/passes/ssa.mbt
  - ../../../../../src/passes/ssa_test.mbt
  - ../../../../../src/passes/ssa_nomerge.mbt
  - ../../../../../src/ir/ssa_local.mbt
  - ../../../../../src/ir/ssa_destroy.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/LocalGraph.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/ssa.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/gtest/local-graph.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/SSAify.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/ssa.wast
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./merge-locals-entry-prepends-and-default-values.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../ssa-nomerge/index.md
  - ../tracker.md
---

# `ssa`

## Role

- `ssa` is a real public upstream Binaryen pass.
- It is part of the local Starshine pass registry as an **active partial** hot-pass name for non-merge families plus the first simple explicit-write merge-local slice.
- Starshine now has an active partial full-`ssa` hot pass for direct lit-compatible non-merge families and simple explicit-write merge locals; parameter-entry/default-entry merge materialization remains fail-closed.
- It is worth tracking here because the repo already has a deep dossier for the implemented sibling [`ssa-nomerge`](../ssa-nomerge/index.md), and that dossier repeatedly depends on a correct explanation of what full `ssa` would do differently.

The beginner summary is:

- Binaryen analyzes local get/set flow for a whole function,
- gives non-SSA writes fresh locals,
- and when a read has multiple incoming sources, full `ssa` creates a fresh **merge local** and writes each incoming value into that local.

That last step is the big difference from `ssa-nomerge`.

## Why this folder exists

The tracker's earlier obvious gaps are mostly closed.
So this folder is an explicit justified expansion, not a forgotten parity-queue pass.

Why the expansion is worth it:

- `ssa` is publicly registered in upstream `pass.cpp`
- it shares the exact same owning implementation file as `ssa-nomerge`
- the one policy difference between the siblings is important enough to deserve its own home
- without a dedicated folder, full-`ssa` merge-local behavior stays scattered across `ssa-nomerge` caveats and is easy to mis-teach

## What the pass is and is not

## What it is

- a function-parallel local-flow rewrite in shared `SSAify.cpp`
- a sibling of `ssa-nomerge`
- a pass that uses ordinary locals, `local.tee`, and function-entry prepends to model phi-like joins
- a small public pass you run explicitly, not part of the default no-DWARF `-O` / `-Os` path documented for this repo

## What it is not

- not a separate codebase from `ssa-nomerge`
- not a proper AST phi-node pass
- not a generic value-propagation or copy-elimination pass
- not the pass Binaryen uses in the default early optimize slot here

## Biggest durable takeaway

The safe mental model is:

- `ssa-nomerge` renames only single-source regions and leaves merge reads on canonical slots
- full `ssa` does the same initial analysis **and then also materializes merge locals**

That means full `ssa` is not merely "more aggressive renaming."
It has a real extra rewrite surface:

- new merge locals
- `local.tee` inserted on explicit incoming sets
- prepended function-entry `local.set`s for parameter inputs

## Scheduler note

Upstream `pass.cpp` registers both passes:

- `ssa`
- `ssa-nomerge`

But the default no-DWARF function pipeline used in this repo adds only `ssa-nomerge` in the early slot.
So this dossier is primarily here to make the sibling split teachable, not to claim that the local parity path is secretly missing a default `ssa` step.

## Agent-todo note

`agent-todo.md` now tracks dedicated full-`ssa` slices under sibling `[O4Z-AUDIT-SSA-FULL]`, split out from the `SSANM` no-merge backlog by `[SSANM-007c]`. `[SSA-FULL-001]` first made full `ssa` known but boundary-only, `[SSA-FULL-002A]` added the merge-local planner, `[SSA-FULL-002B]` activated direct non-merge rewrite families without aliasing the registry entry to `ssa-nomerge`, and `[SSA-FULL-002C]` now covers the first simple explicit-write merge-local mutation. The remaining `[SSA-FULL-002D]` through `[SSA-FULL-003]` slices still own parameter-entry/default-entry merge handling, loop/branch/EH/typed-control boundaries, and direct `--pass ssa` closeout signoff.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Real `version_129` algorithm structure, scheduler placement, LocalGraph role, and the exact full-`ssa` merge policy.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Upstream owner-file and test map, plus the current-main freshness check.
- [`./merge-locals-entry-prepends-and-default-values.md`](./merge-locals-entry-prepends-and-default-values.md)
  - Focused guide to the full-`ssa`-only behavior: merge locals, incoming `tee`s, parameter entry prepends, and default-value handling.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog, with direct `ssa.wast` positives clearly separated from source-derived merge-local families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current Starshine status and port map: active partial local `ssa` registry entry with simple explicit-write merge-local support, active `ssa-nomerge` sibling, reusable HOT SSA overlay/destruction infrastructure plus LocalGraph facts, and the exact code locations the remaining entry/default/control slices must bridge.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  - Future implementation bridge: registry honesty, source classifier requirements, merge-local rewrite order, `ssa-nomerge` sibling-stability checks, and validation ladder.
- [`./fuzzing.md`](./fuzzing.md)
  - Current compare-pass admission boundary: `ssa` is locally active-partial but absent from the harness allowlist, so this is planned-only rather than a runnable parity command.

## Freshness and admission note

The 2026-07-11 current-main recheck reread `SSAify.cpp`, `pass.cpp`, and `ssa.wast`. The shared full-SSA/no-merge algorithm and the default-pipeline split remain as documented: full `ssa` owns merge-local materialization, while only `ssa-nomerge` occupies the early default function slot. This is a dated source reading, not a byte-for-byte current-main versus `version_130` comparison; [`2026-07-11-ssa-current-main-and-local-admission-recheck.md`](../../../raw/binaryen/2026-07-11-ssa-current-main-and-local-admission-recheck.md) records its precise scope.

The same recheck corrects the local status: Starshine exposes `ssa` as an **active partial** direct pass for non-merge families plus the first simple explicit-write merge-local slice, but the compare-pass harness does not admit `--ssa`. Thus a rejected `compare-pass --pass ssa` request proves only harness admission, not pass parity. Keep `version_129` / `version_130` as the released upstream oracle provenance, and use the living Starshine pages for the active-subset boundary.

## Sources

- [`../../../raw/binaryen/2026-07-11-ssa-current-main-and-local-admission-recheck.md`](../../../raw/binaryen/2026-07-11-ssa-current-main-and-local-admission-recheck.md)
- [`../../../raw/binaryen/2026-04-26-ssa-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-ssa-port-readiness-primary-sources.md)
- [`../../../raw/research/0402-2026-04-26-ssa-port-readiness.md`](../../../raw/research/0402-2026-04-26-ssa-port-readiness.md)
- [`../../../raw/research/0321-2026-04-24-ssa-primary-sources-and-starshine-followup.md`](../../../raw/research/0321-2026-04-24-ssa-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0207-2026-04-21-ssa-binaryen-research.md`](../../../raw/research/0207-2026-04-21-ssa-binaryen-research.md) (historical; superseded for raw-source provenance and local Starshine status)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/LocalGraph.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/ssa.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/gtest/local-graph.cpp>
- Narrow freshness check:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SSAify.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/ssa.wast>
