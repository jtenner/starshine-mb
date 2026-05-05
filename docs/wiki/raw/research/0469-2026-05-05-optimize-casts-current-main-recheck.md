---
kind: research
status: supported
last_reviewed: 2026-05-05
sources:
  - ../binaryen/2026-04-22-optimize-casts-primary-sources.md
  - ../binaryen/2026-05-05-optimize-casts-current-main-recheck.md
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

# `optimize-casts` current-main recheck

## Why this recheck exists

`optimize-casts` already had a living dossier, a tagged Binaryen source manifest, and a 2026-04-25 implementation/test bridge. It still lacked a 2026-05-05 freshness layer, so this note records that current-main source recheck without changing the interpreted contract.

## Primary sources rechecked

Captured immutably in:

- [`../binaryen/2026-05-05-optimize-casts-current-main-recheck.md`](../binaryen/2026-05-05-optimize-casts-current-main-recheck.md)

The important upstream surfaces were the official Binaryen GitHub sources for:

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

The 2026-05-05 review preserves the existing teaching contract:

- GC-gated function-parallel pass
- earlier-motion half duplicates later `ref.cast` / `ref.as_non_null` earlier only inside strict linear windows
- later-reuse half materializes a fresh refined local so later gets can reuse an already-executed cast
- both halves invalidate on same-index local writes
- earlier movement uses stricter effect/control barriers because cast trap timing can move
- later reuse is looser because the cast site stays in place
- refinalization after both halves remains part of the correctness contract

### 2. The recheck is a freshness layer, not a new strategy

The new raw manifest and this note do not change the pass interpretation. They just refresh provenance and keep the owner/helper/test map anchored to current-main source URLs.

### 3. Starshine status is unchanged

`optimize-casts` is still unimplemented in Starshine. The refreshed dossier still points future implementers to the same exact local surfaces:

- `src/passes/optimize.mbt:145-152` for the removed-name registry entry
- `agent-todo.md:355-364` for the `OC` backlog slice and the broader-than-upstream `ref.test` caveat
- the local GC/IR/binary/validator/HOT surfaces listed in the living implementation map page

### 4. The backlog/source mismatch remains explicit

The local `OC` backlog still mentions `ref.test`, nullability, and subtype simplifications. The reviewed upstream pass still covers only `ref.cast` and `ref.as_non_null`. Keep that mismatch visible as a planning caveat rather than silently broadening the pass contract.

## Consumability rule

Cite this note for the 2026-05-05 research trail. Cite the raw manifest for current-main provenance and the living dossier for the explanation layer.