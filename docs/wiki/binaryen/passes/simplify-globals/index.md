---
kind: entity
status: working
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-simplify-globals-primary-sources.md
  - ../../../raw/research/0160-2026-04-21-simplify-globals-binaryen-research.md
  - ../../../raw/research/0222-2026-04-21-simplify-globals-source-confirmation-followup.md
  - ../../../raw/research/0275-2026-04-23-simplify-globals-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./plain-vs-optimizing-and-safety.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-globals-optimizing/index.md
  - ../propagate-globals-globally/index.md
  - ../tracker.md
---

# `simplify-globals`

## Role

- `simplify-globals` is an upstream Binaryen late boundary/module pass.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- The pass shares its upstream implementation file with [`../simplify-globals-optimizing/index.md`](../simplify-globals-optimizing/index.md) and [`../propagate-globals-globally/index.md`](../propagate-globals-globally/index.md).
- The key semantic split is simple but important:
  - `simplify-globals` runs the global rewrite engine only
  - `simplify-globals-optimizing` runs that same engine **plus** a nested default function-optimization rerun on changed functions
  - `propagate-globals-globally` is the startup-only sibling that stops after the initializer/offset propagation subset

## Why this pass matters

- The original campaign queue is closed, so this dossier is an explicit tracker expansion rather than a leftover parity stub.
- `simplify-globals` is already a named local registry entry, so it is a real future port surface.
- The plain pass is easier to misunderstand than the optimizing variant because people often collapse them into one name.
- `agent-todo.md` currently has **no dedicated `simplify-globals` slice**, so this folder is also the first durable pass-specific explanation for the plain variant's current local status.
- This pass sits in the same late-global neighborhood as:
  - `duplicate-import-elimination`
  - `remove-unused-module-elements`
  - `string-gathering`
  - `reorder-globals`
  - `directize`

## Beginner summary

A good beginner mental model is:

- scan the whole module to learn which globals are actually read, written, imported, exported, or only self-guarded,
- discover when a mutable global behaves as effectively immutable,
- fold one-time global initializers into later global initializers,
- remove writes whose value never really matters by turning them into `drop(value)`,
- propagate startup-known constants into later global initializers and segment offsets,
- propagate globally constant or simple current-trace-known values into function code,
- repair surrounding function typing when substitutions become more refined,
- then stop.

That final “then stop” is the big difference from `simplify-globals-optimizing`.

## Current durable takeaways

- `simplify-globals` is a **whole-module global pass**, not a local peephole.
- The pass owns several different rewrite families:
  - practical-immutability discovery
  - single-use global-init folding
  - dead and same-as-init write cleanup
  - `read-only-to-write` self-guard elimination
  - immutable copy-chain canonicalization
  - startup-time constant propagation
  - cheap runtime current-trace constant propagation
- Startup-time propagation and runtime propagation use **different safety models**.
- The source insists on actual `global.get` / `global.set` nodes for the key `read-only-to-write` matcher; effect summaries alone are not enough.
- Removed writes preserve operand evaluation as `drop(value)`.
- Some substitutions can force `ReFinalize()` because the replacement type is more refined than the original `global.get` type.
- The plain pass does **not** own the nested cleanup rerun that the optimizing suffix adds.
- The dossier now also has an immutable raw primary-source manifest and a dedicated Starshine status/port-strategy page, closing the biggest remaining provenance and local-status gaps in this folder.
- On 2026-04-23 the reviewed official Binaryen `version_129` release page still showed publish date **2026-04-01**, and a narrow current-`main` spot check on the shared implementation plus key tests did not surface a new teaching-relevant contract drift beyond the updated dossier claims.

## Page map

- [`../../../raw/binaryen/2026-04-23-simplify-globals-primary-sources.md`](../../../raw/binaryen/2026-04-23-simplify-globals-primary-sources.md)
  Immutable manifest of the official Binaryen release, source, and test URLs reviewed for this dossier on 2026-04-23.
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: phases, helper dependencies, scheduler placement, and what the plain pass really owns.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Compact source-confirmed file/test map for the shared `SimplifyGlobals.cpp` family, the public registration split in `pass.cpp`, the pass-runner boundary, and the official lit roster that proves the real plain-pass contract.
- [`./plain-vs-optimizing-and-safety.md`](./plain-vs-optimizing-and-safety.md)
  Focused guide to the easiest things to blur together: startup-vs-runtime propagation, the exact `read-only-to-write` safety model, and the semantic split from `simplify-globals-optimizing`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, bailout, preserved, and easy-to-misread rewrite families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact current Starshine status and port map: boundary-only registry tracking, request-guard behavior, neighboring planning surfaces, and the practical local landing shape for a future module-pass port.

## Current maintenance rule

- Treat this folder as the canonical home for future `simplify-globals` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real boundary/module pass for it.
- Keep the relationship to [`../simplify-globals-optimizing/index.md`](../simplify-globals-optimizing/index.md) and [`../propagate-globals-globally/index.md`](../propagate-globals-globally/index.md) explicit instead of silently teaching the plain pass only through one sibling.

## Sources

- [`../../../raw/binaryen/2026-04-23-simplify-globals-primary-sources.md`](../../../raw/binaryen/2026-04-23-simplify-globals-primary-sources.md)
- [`../../../raw/research/0160-2026-04-21-simplify-globals-binaryen-research.md`](../../../raw/research/0160-2026-04-21-simplify-globals-binaryen-research.md)
- [`../../../raw/research/0222-2026-04-21-simplify-globals-source-confirmation-followup.md`](../../../raw/research/0222-2026-04-21-simplify-globals-source-confirmation-followup.md)
- [`../../../raw/research/0275-2026-04-23-simplify-globals-primary-sources-and-starshine-followup.md`](../../../raw/research/0275-2026-04-23-simplify-globals-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-dominance.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-nested.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-non-init.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-offsets.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-prefer_earlier.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-read_only_to_write.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-single_use.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals_func-effects.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
