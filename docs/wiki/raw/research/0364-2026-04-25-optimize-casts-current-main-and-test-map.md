---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-22-optimize-casts-primary-sources.md
  - ../binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md
  - ../../binaryen/passes/optimize-casts/index.md
  - ../../binaryen/passes/optimize-casts/binaryen-strategy.md
  - ../../binaryen/passes/optimize-casts/implementation-structure-and-tests.md
  - ../../binaryen/passes/optimize-casts/two-phase-dataflow.md
  - ../../binaryen/passes/optimize-casts/wat-shapes.md
  - ../../binaryen/passes/optimize-casts/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/ir/hot_core.mbt
  - ../../../../src/ir/hot_flags.mbt
  - ../../../../src/ir/hot_lift.mbt
  - ../../../../src/ir/hot_lower.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../agent-todo.md
---

# `optimize-casts` current-main and test-map follow-up

## Why this follow-up exists

The `optimize-casts` dossier already had the required overview, Binaryen strategy, two-phase guide, WAT-shape catalog, and Starshine status page. It still had two practical wiki-health gaps:

- no dedicated implementation/test-map page, unlike neighboring local-cleanup dossiers
- no 2026-04-25 current-main bridge tying the owner/helper/test surfaces to exact Starshine prerequisite code locations

This follow-up adds that missing map without changing the top-level pass interpretation.

## Primary sources rechecked

Captured immutably in:

- [`../binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md`](../binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md)

The most important online primary surfaces were official Binaryen GitHub sources for:

- `src/passes/OptimizeCasts.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`
- `src/passes/passes.h`
- `src/ir/linear-execution.h`
- `src/ir/properties.h`
- `src/ir/effects.h`
- `src/ir/utils.h`
- `test/lit/passes/optimize-casts.wast`

## Durable findings

### 1. No teaching-relevant current-main drift was found

The 2026-04-25 recheck preserves the existing `version_129` teaching contract:

- GC-gated function-parallel pass
- first half duplicates later `ref.cast` / `ref.as_non_null` earlier only inside strict linear windows
- second half materializes a fresh refined local so later gets can reuse an already-executed cast
- both halves invalidate on same-index local writes
- earlier movement uses stricter effect/control barriers because cast trap timing can move
- later reuse is looser because the cast site stays in place
- refinalization after both halves is part of the correctness contract

### 2. The new living page is an owner/helper/test map, not a new strategy

The new page:

- maps `OptimizeCasts.cpp` to the two walkers and applier
- maps `pass.cpp`, `opt-utils.h`, and `passes.h` to registry/scheduler/nested-rerun surfaces
- maps helper headers to the exact safety claims already taught in the strategy pages
- maps `optimize-casts.wast` to positive, negative, and caveat test families
- maps current Starshine to exact prerequisite source locations rather than implying an implementation exists

### 3. Starshine status is unchanged but easier to follow

`optimize-casts` is still unimplemented in Starshine. The refreshed dossier now points future implementers to these exact current surfaces:

- `src/passes/optimize.mbt:145-152` for the removed-name registry entry
- `agent-todo.md:355-364` for the `OC` backlog slice and the broader-than-upstream `ref.test` caveat
- `src/lib/types.mbt:723-764`, `src/lib/types.mbt:3995-3996`, and `src/lib/types.mbt:4170-4171` for instruction constructors and cast-family modeling
- `src/wast/lower_to_lib.mbt:1297-1298` for WAT-to-lib lowering of `ref.as_non_null`
- `src/binary/encode.mbt:2580` and `src/binary/encode.mbt:2897-2912` for binary encoding of `ref.as_non_null` and `ref.cast`
- `src/binary/decode.mbt:3116-3124` for binary decoding of `ref.cast`
- `src/validate/typecheck.mbt:3228` and `src/validate/typecheck.mbt:3265` for validation dispatch
- `src/ir/hot_core.mbt:70-73`, `src/ir/hot_flags.mbt:81`, `src/ir/hot_lift.mbt:612-625`, `src/ir/hot_lift.mbt:764-818`, and `src/ir/hot_lower.mbt:1080-1084` for HOT representation, trap flags, lift arity/classification, and lowering support

### 4. The backlog/source mismatch remains explicit

The local `OC` backlog still mentions `ref.test`, nullability, and subtype simplifications. The reviewed upstream pass still covers only `ref.cast` and `ref.as_non_null`. This is not a contradiction to resolve by rewriting history; it is a planning caveat:

- follow Binaryen for parity work unless Starshine deliberately broadens the pass in a future design
- keep `ref.test`, `br_on_cast`, descriptor-cast, and extern-conversion work out of `optimize-casts` teaching unless a future source changes that contract

## Files changed because of this follow-up

- Added [`../binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md`](../binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md)
- Added [`../../binaryen/passes/optimize-casts/implementation-structure-and-tests.md`](../../binaryen/passes/optimize-casts/implementation-structure-and-tests.md)
- Refreshed the existing `optimize-casts` overview, Binaryen strategy, two-phase guide, WAT-shape catalog, and Starshine strategy pages.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/log.md`, and `CHANGELOG.md` so the new source bridge and implementation/test map are discoverable.

## Maintenance rule

Future `optimize-casts` updates should keep these pages in sync:

1. overview for the beginner pass contract
2. `wat-shapes.md` for before/after and bailout families
3. `binaryen-strategy.md` for upstream algorithm rules
4. `implementation-structure-and-tests.md` for owner/helper/lit proof surfaces
5. `two-phase-dataflow.md` for the asymmetry between earlier movement and later reuse
6. `starshine-strategy.md` for local status and future-port prerequisites

Do not create a near-duplicate `optimize-casts` page for a new finding; file it into this folder and cite the raw source bridge that supports it.
