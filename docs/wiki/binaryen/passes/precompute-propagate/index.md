---
kind: entity
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-precompute-propagate-current-main-recheck.md
  - ../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-precompute-propagate-current-main-and-code-map.md
  - ../../../raw/research/0375-2026-04-25-precompute-propagate-current-main-code-map.md
  - ../../../raw/binaryen/2026-04-24-precompute-propagate-primary-sources.md
  - ../../../raw/research/0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0167-2026-04-21-precompute-propagate-binaryen-research.md
  - ../../../raw/research/0198-2026-04-21-precompute-propagate-worklist-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../precompute/index.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-worklist-fallthrough-and-merge-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../precompute/index.md
  - ../dae-optimizing/index.md
  - ../inlining-optimizing/index.md
  - ../simplify-globals-optimizing/index.md
  - ../tracker.md
---

# `precompute-propagate`

## Role

- `precompute-propagate` is an upstream Binaryen function pass.
- It is currently **unimplemented** in Starshine and still lives in the removed-name registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt); see [`./starshine-strategy.md`](./starshine-strategy.md) for the exact local status / port map.
- It shares its core implementation file with [`../precompute/index.md`](../precompute/index.md), but it is still a real separate public pass name in Binaryen `version_129`.
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` top-level path, which still uses plain `precompute`.
- It **does** matter to the broader optimize story because aggressive top-level settings and `optimizeAfterInlining(...)` reruns use this more aggressive variant.

## Why this pass matters

- The main parity queue and the first expansion queue are already dossier-covered, so this folder is an explicit tracker expansion for another real local registry name.
- `agent-todo.md` currently has **no dedicated `precompute-propagate` slice**.
- The pass is already important in neighboring docs:
  - `dae-optimizing` and `inlining-optimizing` both depend on the `precompute-propagate` nested-rerun rule.
  - `simplify-globals-optimizing` is easier to teach once the contrast is explicit: it reruns the default function pipeline **without** prepending `precompute-propagate`.
- The earlier worklist follow-up closed the dossier's biggest algorithm teaching gap with a dedicated page for the exact `propagateLocals(...)` contract.
- The 2026-04-24 follow-up closed the original provenance and local-follow-along gap with an immutable raw primary-source manifest and a dedicated Starshine status / port-strategy page.
- The 2026-05-04 refresh adds a current-main no-drift manifest and a dedicated Starshine port-readiness bridge, so this folder should be treated as a deep dossier rather than only a landing dossier.

## Beginner summary

A good beginner mental model is:

- Binaryen tries to **execute** some expressions at compile time,
- keeps the rewrite only when the result can be emitted honestly,
- preserves child writes when erasing them would be wrong,
- and in `precompute-propagate` mode it also solves a small local get/set consensus problem to unlock one extra evaluator walk.

So the pass is best taught as:

- **semantic precomputation plus a narrow local worklist**,
- not just “constant folding through locals.”

## Most important durable takeaways

- `precompute-propagate` is a real public pass name in Binaryen `version_129`, not just an internal mode nickname.
- It shares the same `Precompute.cpp` core as plain `precompute`, but the propagate variant adds a real extra phase.
- That extra phase uses `LazyLocalGraph` to learn concrete values for some `local.get`s and then reruns the main precompute walk once.
- The propagation step is stricter than the name alone suggests:
  - sets are analyzed through their **fallthrough values**
  - propagated set values must still subtype the original set-value expression type
  - a `local.get` becomes constant only when **all** reaching sets agree on one concrete literal tuple
  - defaultable vars can contribute function-entry zero/default literals, but params and suspicious nondefaultable-local entry reads bail out
- Top-level no-DWARF `-O` / `-Os` still uses plain `precompute`.
- Aggressive schedules and `optimizeAfterInlining(...)` reruns use `precompute-propagate`.
- The pass still depends on the same hard safety boundaries as plain `precompute`:
  - emitability of computed values
  - preservation of child local/global writes
  - bounded loop/depth exploration
  - GC identity and heap-value rules

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation, scheduler placement, helper dependencies, and the propagate-specific extra phase.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./local-worklist-fallthrough-and-merge-boundaries.md`](./local-worklist-fallthrough-and-merge-boundaries.md)
  Focused guide to the exact `propagateLocals(...)` contract: `LazyLocalGraph` worklist edges, fallthrough-value analysis, get-merge consensus, defaultable-versus-param entry behavior, nondefaultable-local bailout, and the one-extra-rerun stopping rule.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, bailout, and easy-to-misread `precompute-propagate` families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future port map: removed registry name, no active sibling descriptor, plain `precompute` as the nearest landing zone, missing HOT get/set propagation, and the nested-rerun scheduler dependency.

## Current maintenance rule

- Treat this folder as the canonical home for future `precompute-propagate` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass for it.
- Keep the relationship to plain `precompute` explicit:
  - shared implementation core
  - different public pass name
  - different scheduler usage
  - different reachable fixed points because of the extra propagation phase
- Treat [`../../../raw/binaryen/2026-04-24-precompute-propagate-primary-sources.md`](../../../raw/binaryen/2026-04-24-precompute-propagate-primary-sources.md) as the tagged-source provenance anchor and [`../../../raw/binaryen/2026-05-04-precompute-propagate-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-precompute-propagate-current-main-recheck.md) as the current-main freshness anchor.
- Keep the exact local-worklist contract explicit too:
  - not generic SCCP
  - not an unbounded fixed-point loop
  - not a bypass around emitability or GC-identity rules
- Keep the exact Starshine status explicit too:
  - removed registry name today
  - no active `precompute-propagate` owner file or descriptor
  - no nested optimizing-rerun scheduler yet
  - current plain `precompute` is a useful landing zone but not an implementation of this sibling

## Sources

- [`../../../raw/binaryen/2026-05-04-precompute-propagate-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-precompute-propagate-current-main-recheck.md)
- [`../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md`](../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-25-precompute-propagate-current-main-and-code-map.md`](../../../raw/binaryen/2026-04-25-precompute-propagate-current-main-and-code-map.md)
- [`../../../raw/research/0375-2026-04-25-precompute-propagate-current-main-code-map.md`](../../../raw/research/0375-2026-04-25-precompute-propagate-current-main-code-map.md)
- [`../../../raw/binaryen/2026-04-24-precompute-propagate-primary-sources.md`](../../../raw/binaryen/2026-04-24-precompute-propagate-primary-sources.md)
- [`../../../raw/research/0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md`](../../../raw/research/0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0167-2026-04-21-precompute-propagate-binaryen-research.md`](../../../raw/research/0167-2026-04-21-precompute-propagate-binaryen-research.md)
- [`../../../raw/research/0198-2026-04-21-precompute-propagate-worklist-followup.md`](../../../raw/research/0198-2026-04-21-precompute-propagate-worklist-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../precompute/index.md`](../precompute/index.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Precompute.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-interpreter.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate-partial.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate_all-features.wast>
