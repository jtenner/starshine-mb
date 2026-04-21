---
kind: entity
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0148-2026-04-21-simplify-locals-binaryen-research.md
  - ../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./variant-matrix-and-scheduler.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./implementation-map.md
  - ./effect-ordering-and-barriers.md
  - ./raw-lane-and-writeback.md
  - ./validation-and-signoff.md
  - ./performance-and-artifact-frontiers.md
  - ./parity.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../simplify-locals-nostructure/index.md
  - ../simplify-locals-notee-nostructure/index.md
---

# `simplify-locals`

## Role

- `simplify-locals` is an active implemented **hot pass** in Starshine.
- In upstream Binaryen `version_129`, `simplify-locals` is not one pass name with one behavior.
  It is a **family** of five public passes built from one templated implementation in `SimplifyLocals.cpp`.
- The public `pass.cpp` summary is short:
  - `miscellaneous locals-related optimizations`

That summary is true, but much too small.

A better beginner summary is:

- Binaryen counts local uses,
- sinks `local.set` values toward later `local.get`s when effect ordering still allows it,
- optionally creates `local.tee` when later uses still need the local,
- optionally rewrites blocks / `if`s / loops to return values directly,
- then runs a separate equivalent-copy cleanup and final dead-set cleanup.

So this pass is **not** just dead-local removal and **not** just adjacent set/get peepholes.

## Why this pass matters

- `simplify-locals` still sits in one of the most scheduler-relevant parts of the Binaryen pipeline:
  - an early no-structure variant runs before the main local-cleanup cluster
  - the full structured pass runs later after `coalesce-locals` and optional `local-cse`
- The active `SL` backlog slice in `agent-todo.md` still depends on understanding that late slot and its surrounding cleanup neighborhood correctly.
- This thread picked `simplify-locals` as an explicitly justified major-gap fallback after the tracker showed that:
  - the `none` queue was already clear
  - the implemented-landing queue was already clear
  - the older tuple / RUME / RUB / DFE fallback gaps were already closed
- The old folder was already deep, but it was still missing a newer-style `version_129` implementation/test map and explicit public-variant page.

## Most important durable takeaways

- Binaryen `simplify-locals` is **not** generic CFG-based local dataflow.
- Binaryen `simplify-locals` is **not** just dead-set cleanup.
- The real `version_129` contract is a staged family built from:
  1. `LocalGetCounter` use counting
  2. a first cycle biased toward single-use sinks
  3. later tee-aware linear-trace sinking cycles
  4. optional block / `if` / loop result synthesis
  5. a separate late equivalent-copy optimizer
  6. `UnneededSetRemover` final dead-set cleanup
  7. in-pass `ReFinalize` plus pass-runner nondefaultable-local fixups
- The three semantic axes are real and user-visible:
  - tee creation
  - structure creation
  - whether new nesting is allowed at all
- Current `main` shows only a tiny checked drift beyond `version_129` here:
  - `map/set` -> `unordered_map/unordered_set` container cleanup in `SimplifyLocals.cpp`
  - the major dedicated lit files checked for this dossier are unchanged

## Biggest beginner correction

The easy wrong mental model is:

- `simplify-locals` just removes obvious `local.set` / `local.get` pairs

The safer mental model is:

- Binaryen uses a cheap linear-execution model to move pending local writes through later code,
- effect ordering decides when that move is still legal,
- structure synthesis is a separate optional layer,
- and equivalent-copy cleanup plus dead-set cleanup happen later as distinct phases.

That difference explains why:

- the first cycle is intentionally stricter than later cycles
- `simplify-locals-nostructure` and full `simplify-locals` are not interchangeable
- one-armed `if` rewrites are guarded so hard
- equal-local canonicalization can switch a `local.get` to a more refined representative late in the pass

## Page map

### Upstream Binaryen contract

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` implementation, algorithm phases, helper dependencies, and why the pass family is more structured than the public name suggests.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Exact upstream file map plus the official lit roster: what `SimplifyLocals.cpp`, `linear-execution.h`, `equivalent_sets.h`, `local-utils.h`, `pass.cpp`, `opt-utils.h`, and the simplify-locals lit files each prove.
- [`./variant-matrix-and-scheduler.md`](./variant-matrix-and-scheduler.md)
  - Explicit public variant matrix for `simplify-locals`, `-notee`, `-nostructure`, `-notee-nostructure`, and `-nonesting`, plus the exact top-level and nested scheduler placements that give each variant its job.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly upstream WAT-shape catalog covering positive sink / tee / structure families, important bailout families, and nearby-pass interaction shapes.

### Starshine-local port and maintenance surface

- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current in-tree HOT-IR and raw-lane port strategy.
- [`./implementation-map.md`](./implementation-map.md)
  - Concrete map from the dossier to the actual MoonBit helper clusters and tests in tree.
- [`./effect-ordering-and-barriers.md`](./effect-ordering-and-barriers.md)
  - Current in-tree barrier model for local motion.
- [`./raw-lane-and-writeback.md`](./raw-lane-and-writeback.md)
  - Exact-instruction fallback lane and lowered cleanup policy.
- [`./validation-and-signoff.md`](./validation-and-signoff.md)
  - What each local test lane and compare lane proves.
- [`./performance-and-artifact-frontiers.md`](./performance-and-artifact-frontiers.md)
  - Runtime and artifact-hotspot maintenance notes.
- [`./parity.md`](./parity.md)
  - Current local parity status.

## Freshness note

A narrow 2026-04-21 source check found no meaningful semantic drift on the checked upstream surfaces.

What I directly re-confirmed:

- `SimplifyLocals.cpp` on current `main` differs from `version_129` only by container choice cleanup
- the checked dedicated lit surfaces are unchanged:
  - `simplify-locals-gc.wast`
  - `simplify-locals-gc-nn.wast`
  - `simplify-locals-gc-validation.wast`
  - `simplify-locals-eh.wast`
  - `simplify-locals-tnh.wast`
  - `global-effects_simplify-locals.wast`

So the current durable rule is:

- treat Binaryen `version_129` as the semantic oracle for this dossier
- mention current-main drift only when it is more than container cleanup

## Current maintenance rule

- Treat this folder as the canonical home for future `simplify-locals` parity and scheduler research.
- Keep the main correction explicit:
  - Binaryen `simplify-locals` is a staged locals pass family, not one adjacent-peephole transform
- Keep the variant matrix, late equivalent-copy phase, and split validation-repair story explicit whenever future docs or code changes touch this pass.
- Keep the older Starshine-port pages, but do not let them silently replace the official Binaryen `version_129` contract on the landing page.

## Sources

- [`../../../raw/research/0148-2026-04-21-simplify-locals-binaryen-research.md`](../../../raw/research/0148-2026-04-21-simplify-locals-binaryen-research.md)
- [`../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md`](../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md)
- [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
- [`../../../../../src/passes/simplify_locals_test.mbt`](../../../../../src/passes/simplify_locals_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../tracker.md`](../tracker.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
- Narrow freshness-check surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>
