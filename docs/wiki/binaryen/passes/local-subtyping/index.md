---
kind: entity
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md
  - ../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md
  - ../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./lubs-and-dominance.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `local-subtyping`

## Role

- `local-subtyping` is an upstream Binaryen GC/local cleanup pass.
- It is currently **unimplemented** in Starshine and still appears under the removed pass names in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- The 2026-04-22 source refresh corrected an earlier over-broad local reading: Binaryen `version_129` uses this pass for a **small definition-driven local-type tightening job**, not a broad `local.get` / `ref.as_non_null` collector and not a `LocalUpdater`-driven copy-local rewrite engine.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` function pipeline runs `local-subtyping` in the GC/local cleanup cluster after `optimize-casts` and before `coalesce-locals` plus `local-cse`.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - top-level slot `29`
- The repo backlog already treats it as a real parity blocker under slice `LS` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- It is one of the missing scheduler neighbors that still block fully honest preset placement around the already-implemented `reorder-locals` and future `coalesce-locals` work.
- This folder now also has an immutable raw primary-source manifest and the missing dedicated Starshine status/port-map page, so the pass is no longer only upstream-facing research.

## Beginner summary

A safe beginner mental model is:

- start from the local's declared type,
- look at the concrete types written into the local,
- compute one common narrower type that still fits those writes,
- keep that narrowing only when Binaryen's helper and dominance checks say it is safe,
- then retag the local declaration and the matching `local.get` / `local.tee` expression types.

That is narrower than “infer all local subtypes from every use and definition.”

## Current durable takeaways

- Binaryen only schedules this pass in the GC-gated local cleanup cluster.
- The reviewed `version_129` pass body collects new evidence from **`local.set` / `local.tee` definitions only**.
- Parameters are deliberately skipped.
- Tuple locals are still excluded by `TypeUpdating::canHandleAsLocal(...)`.
- Candidate narrowing is limited to reference-typed locals.
- `LocalStructuralDominance` still matters, but as a guard for **non-nullability tightening** and safe get-retagging, not as a generic `LocalUpdater` rewrite engine.
- The reviewed pass directly rewrites local declarations plus `local.get` / `local.tee` expression types; it does **not** use `LocalUpdater(...).changeType(...)`, helper-added copy locals, or a trailing `ReFinalize()` step in `version_129`.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the corrected Binaryen `version_129` implementation: GC gate, set-driven LUB collection, reference-local-only narrowing, dominance-gated non-nullability, direct declaration/get/tee retagging, and the scheduler rule that it must run before `coalesce-locals`.
- [`./lubs-and-dominance.md`](./lubs-and-dominance.md)
  Dedicated guide to the easiest parts of the pass to misunderstand after the 2026-04-22 source correction: why the LUB is seeded from declarations but fed by defs, why dominance still matters, and why the older copy-local / `LocalUpdater` story was too broad.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog covering set-driven narrowing, common-parent LUBs, tee retagging, dominance-gated non-nullability, and the important preserved non-rewrite families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact current Starshine status and port-planning bridge: removed-name registry tracking, backlog slice `LS`, canonical no-DWARF slot, the reviewed upstream-vs-backlog scope mismatch, and the practical neighboring pass cluster a future local port would need to join honestly.

## Current maintenance rule

- Treat this folder as the canonical home for future `local-subtyping` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass.
- Keep the 2026-04-22 source correction explicit whenever future work touches this folder; do not silently revert to the older over-broad `LocalUpdater` / `ref.as_non_null` reading.

## Sources

- [`../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md`](../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md)
- [`../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md`](../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md)
- [`../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md`](../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-structural-dominance.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>
