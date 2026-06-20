---
kind: entity
status: supported
last_reviewed: 2026-06-20
sources:
  - ../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md
  - ../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0170-2026-04-21-global-struct-inference-desc-cast-binaryen-research.md
  - ../../../raw/research/0212-2026-04-21-global-struct-inference-desc-cast-source-confirmation-followup.md
  - ../../../raw/binaryen/2026-05-05-global-struct-inference-desc-cast-current-main-recheck.md
  - ../../../raw/research/0488-2026-05-05-global-struct-inference-desc-cast-current-main-recheck.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../global-struct-inference/index.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./descriptor-singleton-gate-and-dedicated-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../global-struct-inference/index.md
  - ../tracker.md
---

# `global-struct-inference-desc-cast` / upstream `gsi-desc-cast`

## Role

- `global-struct-inference-desc-cast` is the local Starshine registry name for the upstream Binaryen pass published as `gsi-desc-cast`.
- Starshine now has an **active behavior-parity implementation** as of 2026-06-20: the pass is registered as a module pass, dispatches through the GSI-family engine with desc-cast mode enabled, and rewrites closed-world singleton-descriptor casts by inserting the descriptor `global.get` immediately before eligible reachable `ref.cast` instructions. Focused tests cover local/global, nullable, exact-target, structured block/loop/if, select, intervening no-result-instruction stack shapes, and the unreachable-input bailout; the dedicated `gsi-desc-cast` GenValid profile fuzzes those positives and bailout families at scale.
- The old 2026-06-04 boundary-only deferral and the later final-closeout blocker are superseded by the green 2026-06-20 closeout matrix: regular GenValid `100000`, explicit wasm-smith `10000`, dedicated `gsi-desc-cast` `10000`, and broad named `pass-fuzz-stress` GenValid `10000` all have zero Starshine mismatches or validation failures.
- It is a real public upstream pass in Binaryen `version_129`, but it is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` default top-level path.
- It is a **shared-engine sibling** of plain `gsi`, implemented upstream by the same `GlobalStructInference.cpp` file with the desc-cast mode flag enabled.

## Why this pass mattered for a source-confirmation follow-up

The tracker no longer had an obvious remaining `none` target, so this thread revisited an already-dossiered upstream-only registry pass only because the old dossier still had a real major gap.

That gap was twofold:

- it described the desc-cast rewrite too much like a trusted-origin analysis on the **value being cast**
- it missed the real dedicated upstream lit surface for the variant

The refreshed dossier now source-confirms the narrower real contract.
A 2026-05-05 current-main recheck on the same reviewed surfaces found no teaching-relevant drift.

## Beginner summary

A safe beginner mental model is:

- plain `gsi` optimizes trusted struct reads and descriptor reads
- `gsi-desc-cast` runs the same shared engine, but also looks at `ref.cast`
- a cast can become `ref.cast_desc_eq` only when the **target type's descriptor type** is known to have **exactly one** immutable top-level global instance in the closed-world `typeGlobals` map
- the cast target must also either be exact or have no strict subtypes

So this pass is best taught as:

- **a narrow target-descriptor-singleton cast rewrite on top of the `gsi` engine**
- not as a generic cast optimizer
- and not as a cast-input-origin oracle

## Most important durable takeaways

- The official upstream public name is `gsi-desc-cast`.
- The local Starshine registry currently calls it `global-struct-inference-desc-cast`.
- Binaryen `version_129` implements it in the same `GlobalStructInference.cpp` engine as plain `gsi`.
- The desc-cast-specific logic lives in `visitRefCast(RefCast*)`.
- The real cast gate is narrower than the old dossier implied:
  - target type not `unreachable`
  - target heap type has a descriptor type
  - target is exact **or** has no strict subtypes
  - the descriptor heap type maps to exactly one global in `typeGlobals`
- That means the desc-cast-specific rewrite is effectively **closed-world dependent**, because `typeGlobals` is filled in `analyzeClosedWorld(...)`.
- The pass does have dedicated upstream lit coverage:
  - `gsi-to-desc-cast.wast` proves the `--gsi` vs `--gsi-desc-cast` delta directly
  - `gsi-desc.wast` proves nearby descriptor-read / descriptor-un-nesting behavior in the shared engine
- A narrow freshness check found only comment typo fixes in current `main` `GlobalStructInference.cpp`; the inspected logic and dedicated lit files still match `version_129`.

## Why this pass matters

- The main parity queue and first tracker-expansion wave are already dossier-covered, so this folder is an explicit source-backed expansion for another real local registry entry.
- `agent-todo.md` now tracks the remaining `global-struct-inference-desc-cast` parity work separately from ordinary `--gsi`.
- The neighboring `global-struct-inference` folder already proved there is real upstream `gsi-desc-cast` surface; this folder remains the corrected, source-confirmed home for that sibling.
- Without a dedicated folder, the pass is easy to misread as either:
  - a synonym for plain `gsi`, or
  - a generic cast optimizer like `optimize-casts`, or
  - a cast-input-origin analysis when its real desc-cast gate is target-descriptor-singleton based.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Source-confirmed overview of the actual Binaryen `version_129` implementation, scheduler placement, helper dependencies, and the real desc-cast-specific gate.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - File-by-file and test-by-test map of the upstream sources that define the pass contract, including the dedicated `gsi-to-desc-cast.wast` and `gsi-desc.wast` surfaces.
- [`./descriptor-singleton-gate-and-dedicated-tests.md`](./descriptor-singleton-gate-and-dedicated-tests.md)
  - Focused explanation of the exact singleton-descriptor-global gate, the exact-vs-strict-subtype split, and what each dedicated lit family proves.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog showing which `ref.cast` families become `ref.cast_desc_eq`, which stay plain casts, and which still bail out.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current Starshine status and closeout map: active module-pass registry/dispatch, shared plain-GSI sibling engine, exact local code locations, `ref.cast_desc_eq` instruction support, implemented closed-world singleton descriptor-global/subtype gates, final compare evidence, and reopening criteria.

## Current maintenance rule

- Treat this folder as the canonical home for future `global-struct-inference-desc-cast` / `gsi-desc-cast` research and port planning.
- Keep it explicitly marked as **supported / parity-closed** while the 2026-06-20 final closeout evidence in [`./starshine-strategy.md`](./starshine-strategy.md) remains current.
- Keep the naming split explicit:
  - local registry: `global-struct-inference-desc-cast`
  - upstream public pass: `gsi-desc-cast`
- Keep the shared-engine rule explicit too:
  - this is not a separate analysis family
  - it is the `gsi` engine with desc-cast rewriting enabled
- Keep the corrected cast rule explicit:
  - desc-cast rewriting is driven by the **target descriptor type's singleton global**, not by a rich cast-input-origin oracle
- Keep any future current-`main` drift notes explicit instead of silently rewriting the `version_129` contract.

## Sources

- [`../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md`](../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md)
- [`../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md`](../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0170-2026-04-21-global-struct-inference-desc-cast-binaryen-research.md`](../../../raw/research/0170-2026-04-21-global-struct-inference-desc-cast-binaryen-research.md)
- [`../../../raw/research/0212-2026-04-21-global-struct-inference-desc-cast-source-confirmation-followup.md`](../../../raw/research/0212-2026-04-21-global-struct-inference-desc-cast-source-confirmation-followup.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../global-struct-inference/index.md`](../global-struct-inference/index.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-desc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-to-desc-cast.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi.wast>
- Narrow freshness-check sources:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalStructInference.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gsi-desc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gsi-to-desc-cast.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gsi.wast>
