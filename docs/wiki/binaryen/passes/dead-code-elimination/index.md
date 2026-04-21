---
kind: entity
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0134-2026-04-20-dead-code-elimination-binaryen-research.md
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
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_vacuum_remove-unused-names.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-stack-switching.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadCodeElimination.cpp
  - https://github.com/WebAssembly/binaryen/tree/main/test/lit/passes
related:
  - ./binaryen-strategy.md
  - ./typed-control-voidification-and-eh.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../vacuum/index.md
  - ../remove-unused-brs/index.md
  - ../remove-unused-names/index.md
  - ../optimize-instructions/index.md
---

# `dead-code-elimination`

## Role

- `dead-code-elimination` is an active implemented **hot pass** in Starshine.
- In upstream Binaryen `version_129`, the public `pass.cpp` description for `dce` is only:
  - `removes unreachable code`

That description is true, but too small.

A better beginner summary is:

- Binaryen first removes work that is provably unreachable after non-fallthrough children,
- then removes dead pure values whose results are unused,
- keeps effectful work in order when only the value is dead,
- turns dead typed control wrappers into **void** control instead of deleting them unsafely,
- and finally repairs locals, EH shape, and expression types.

So this pass is not just “delete code after `return`.”
It is the early structural cleanup pass for dead results and unreachable tails.

## Why this pass matters

- When this thread started, `docs/wiki/binaryen/passes/tracker.md` named `dead-code-elimination` as the strongest remaining implemented landing-page target.
- In the canonical no-DWARF `-O` / `-Os` function scheduler, DCE is the **first** cleanup pass after `ssa-nomerge`:
  - `ssa-nomerge -> dce -> remove-unused-names -> remove-unused-brs -> ...`
- The saved generated-artifact `-O4z` audit observed the same top-level slot at Binaryen slot `12`.
- The saved Binaryen debug log contains `18` `running pass: dce` lines in total, so nested reruns matter here too.
- The saved slot-12 audit result is unusually revealing:
  - `normalizedWatEqual = true`
  - `canonicalFuncPrettyEqual = true`
  - `wasmEqual = false`
  - `starshinePassSkippedRaw = true`
- The saved audit summary also puts DCE in the expensive-but-successful cluster:
  - `29.01x` wall ratio
  - `55.89x` pass ratio

That means the durable frontier here is:

- understanding the real Binaryen semantics,
- keeping the early cleanup story coherent with nearby passes,
- and staying honest that current Starshine DCE still has a runtime problem even when the top-level slot outcome is semantically fine.

## Biggest beginner correction

The easy wrong mental model is:

- DCE is a generic dead-code analyzer for everything in the function

The safer mental model is:

- DCE is mostly **unused-result structural cleanup** driven by effect analysis and branch-target awareness
- it removes unreachable suffixes and dead pure values eagerly
- but when a typed `block`, `if`, `loop`, `try`, or `try_table` still matters structurally, it often changes the node to **void** instead of deleting it
- then it repairs locals, EH nested pops, nested blocks, and final expression types

That difference matters a lot.

## What the pass sounds like versus what it actually does

What it sounds like:

- generic unreachable-code stripping

What it actually is in `version_129`:

- a function-parallel post-walk pass with helper walkers that detect live branch targets,
- an effect-based `canRemove(...)` test for unused values,
- child-first unreachable-tail pruning,
- dead-`drop` simplification that preserves side effects,
- dead typed-control **voidification** instead of blind erasure,
- and mandatory post-pass repair through `TypeUpdater`, `EHUtils`, `Flatten`, and `ReFinalize`.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` implementation structure, helper dependencies, scheduler placement, and the algorithmic phases that make DCE more than a simple unreachable-tail sweep.
- [`./typed-control-voidification-and-eh.md`](./typed-control-voidification-and-eh.md)
  - Focused guide to the hardest part of the pass to misunderstand: dead typed-control result removal, explicit-`unreachable` tail repair, local-type updates, and EH nested-pop cleanup.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering unreachable suffixes, pure versus impure dead drops, dead result-block / `if` / `loop` wrappers, branch-targeted bailout shapes, and the main non-goals.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current in-tree Starshine HOT-region strategy, including the local caches, raw-skip heuristics, and the HOT-specific payload-forwarder repairs that are implementation details rather than the upstream Binaryen contract itself.

## Freshness note

A narrow 2026-04-20 source check did **not** show an obvious post-`version_129` drift story here.
What I directly re-confirmed on current `main`:

- the same `DeadCodeElimination.cpp` pass file still exists with the same high-level helper structure
- the same dedicated `dce_all-features`, `dce_vacuum_remove-unused-names`, `dce-eh*`, and `dce-stack-switching` test surfaces still exist

So the current durable rule is:

- treat Binaryen `version_129` as the semantic oracle for this dossier
- keep an eye out for future drift, but do not invent one where the current sources do not show it

## Current maintenance rule

- Treat this folder as the canonical home for future `dead-code-elimination` parity and scheduler research.
- Keep the main correction explicit:
  - DCE is not just unreachable-code deletion
  - and it is not generic dataflow dead-store elimination either
- Keep the typed-control plus repair story explicit whenever future docs or code changes touch this pass.

## Sources

- [`../../../raw/research/0134-2026-04-20-dead-code-elimination-binaryen-research.md`](../../../raw/research/0134-2026-04-20-dead-code-elimination-binaryen-research.md)
- [`../../../../../src/passes/dead_code_elimination.mbt`](../../../../../src/passes/dead_code_elimination.mbt)
- [`../../../../../src/passes/dead_code_elimination_test.mbt`](../../../../../src/passes/dead_code_elimination_test.mbt)
- [`../../../../../src/passes/dead_code_elimination_live_repro_test.mbt`](../../../../../src/passes/dead_code_elimination_live_repro_test.mbt)
- [`../../../../../src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadCodeElimination.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/eh-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- Binaryen `version_129` dedicated test surfaces:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_all-features.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_vacuum_remove-unused-names.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-stack-switching.wast>
- Narrow freshness-check surfaces:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadCodeElimination.cpp>
  - <https://github.com/WebAssembly/binaryen/tree/main/test/lit/passes>
