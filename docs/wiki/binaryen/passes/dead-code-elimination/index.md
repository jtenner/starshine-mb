---
kind: entity
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-dead-code-elimination-primary-sources.md
  - ../../../raw/research/0250-2026-04-22-dead-code-elimination-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0134-2026-04-20-dead-code-elimination-binaryen-research.md
  - ../../../raw/research/0203-2026-04-21-dead-code-elimination-source-confirmation-followup.md
  - ../../../../../src/passes/dead_code_elimination.mbt
  - ../../../../../src/passes/dead_code_elimination_test.mbt
  - ../../../../../src/passes/dead_code_elimination_live_repro_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadCodeElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_vacuum_remove-unused-names.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh-legacy.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-stack-switching.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadCodeElimination.cpp
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./typed-control-voidification-and-eh.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../vacuum/index.md
  - ../remove-unused-brs/index.md
  - ../remove-unused-names/index.md
---

# `dead-code-elimination`

## Role

- `dead-code-elimination` is an active implemented **hot pass** in Starshine.
- In upstream Binaryen `version_129`, the public pass name is `dce`.
- `pass.cpp` describes it tersely as:
  - `removes unreachable code`

After a direct source-confirmation follow-up, that short description turns out to be much closer to the truth than the older local dossier was.

## Biggest correction from the follow-up

The older local pages overstated this pass.
They described a much broader engine with helper walkers, effect-driven dead-result analysis, general typed-control voidification, flattening, and refinalization.

A direct reread of `src/passes/DeadCodeElimination.cpp` in Binaryen `version_129` shows the real pass is smaller:

- one function-parallel postwalk,
- centered on `TypeUpdater`,
- trimming dead suffixes after the first unreachable child,
- preserving earlier still-executing children by turning them into `drop`s when needed,
- changing some control nodes' type to `unreachable`,
- and doing one narrow end-of-function EH pop fixup when DCE introduced blocks into a function that contains `pop`.

So the safe beginner summary is now:

- **Binaryen `dce` is an early unreachable-shape cleanup pass, not a generic dead-result optimizer.**

## Why this pass matters

- In the canonical no-DWARF `-O` / `-Os` function pipeline, Binaryen runs it immediately after `ssa-nomerge`:
  - `ssa-nomerge -> dce -> remove-unused-names -> remove-unused-brs -> ...`
- The saved generated-artifact `-O4z` audit observed the same top-level slot at slot `12`.
- The full saved Binaryen debug log contains many `running pass: dce` lines because nested cleanup reruns reach it too.
- `agent-todo.md` still has dedicated `DCE` slices, so this pass remains directly relevant to Starshine work rather than being purely archival.

## What the pass really does

The source-confirmed `version_129` contract is:

- if a **non-control** expression becomes unreachable because one child is unreachable,
  - keep the first unreachable child,
  - keep earlier children as `drop`s,
  - remove later children,
  - and materialize a `block` if multiple preserved pieces remain;
- if a `block` contains an unreachable child,
  - trim the dead suffix after that child,
  - maybe collapse the block to the lone `unreachable`,
  - and maybe change the block type to `unreachable` if no `break`s target it;
- if an `if` has an unreachable condition,
  - replace the `if` with the condition;
- if an `if` has both arms unreachable,
  - change its type to `unreachable`;
- if a `loop` body is literally unreachable,
  - replace the loop with the body;
- if `try` or `try_table` can no longer finish normally,
  - change their type to `unreachable`;
- if DCE added blocks in a function containing `pop`,
  - run `EHUtils::handleBlockNestedPops(...)`.

## What the pass does **not** do here

The follow-up matters because the real file does **not** contain:

- `BranchSeeker` / `UnneededBlockSeeker`
- `EffectAnalyzer`
- `canRemove(...)`
- a dedicated `visitDrop(...)` dead-result engine
- a general control-voidification pipeline
- `Flatten::flatten(...)`
- `ReFinalize`
- `TypeUpdater::handleNonDefaultableLocals(...)`

Those older claims were the main documentation gap this follow-up closes.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Source-confirmed algorithm overview for the real `version_129` pass, centered on `TypeUpdater`, control-vs-non-control handling, and narrow EH repair.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Exact owner-file and lit-test map for the pass, including the direct correction of the older over-broad local description.
- [`./typed-control-voidification-and-eh.md`](./typed-control-voidification-and-eh.md)
  - Focused guide to the actual control-type and EH rules the source does implement: type-to-`unreachable` changes, not a generic voidification engine.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog for the real `version_129` rewrite surface.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current in-tree Starshine HOT-region strategy, exact MoonBit code map, raw-skip/writeback guard story, and remaining parity/perf work.

## Freshness note

The reviewed official Binaryen GitHub `version_129` release page was re-checked on 2026-04-22 and showed publish date **2026-04-01**.
A narrow `version_129` versus current-`main` spot check on `src/passes/DeadCodeElimination.cpp`, `pass.cpp`, and representative `dce` lit files did not surface a new teaching-relevant contract drift.
So the tagged source remains a strong current oracle for this folder.

## Current maintenance rule

Keep this folder honest about the main correction:

- Binaryen `dce` is broader than only deleting code after `return`,
- but **much narrower** than the older local story of general effect-based dead-result cleanup.

If future work mentions DCE as a reason for dead `drop` or broad typed-control simplification, re-check the source before attributing that behavior to this pass.
