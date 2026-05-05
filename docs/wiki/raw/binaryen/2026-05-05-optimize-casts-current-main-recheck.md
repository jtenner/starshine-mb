# Binaryen `optimize-casts` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/optimize-casts/` dossier

## Scope

This file captures the primary online sources rechecked for the 2026-05-05 `optimize-casts` freshness pass. It complements the tagged-source manifest:

- [`2026-04-22-optimize-casts-primary-sources.md`](./2026-04-22-optimize-casts-primary-sources.md)

Use the living pages for interpretation:

- [`../../binaryen/passes/optimize-casts/index.md`](../../binaryen/passes/optimize-casts/index.md)
- [`../../binaryen/passes/optimize-casts/binaryen-strategy.md`](../../binaryen/passes/optimize-casts/binaryen-strategy.md)
- [`../../binaryen/passes/optimize-casts/implementation-structure-and-tests.md`](../../binaryen/passes/optimize-casts/implementation-structure-and-tests.md)
- [`../../binaryen/passes/optimize-casts/two-phase-dataflow.md`](../../binaryen/passes/optimize-casts/two-phase-dataflow.md)
- [`../../binaryen/passes/optimize-casts/wat-shapes.md`](../../binaryen/passes/optimize-casts/wat-shapes.md)
- [`../../binaryen/passes/optimize-casts/starshine-strategy.md`](../../binaryen/passes/optimize-casts/starshine-strategy.md)

## Official sources consulted

### Pass owner

- `OptimizeCasts.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeCasts.cpp>
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeCasts.cpp>

Teaching-relevant source landmarks observed during the recheck:

- `OptimizeCasts` still owns the outer GC gate, the earlier-motion half, the later-reuse half, and both `ReFinalize` calls.
- `EarlyCastFinder` remains the stricter earlier-motion walker.
- `BestCastFinder` / `FindingApplier` remain the later-reuse walker plus materializer pair.
- The current `main` file still keeps the same `ref.cast` / `ref.as_non_null` teaching scope and does not widen the pass into `ref.test`, descriptor casts, or extern conversions.

### Scheduler and helper surfaces

- `pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `opt-utils.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `passes.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>

### Helper contracts used by the pass

- `linear-execution.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/linear-execution.h>
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- `properties.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/properties.h>
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `effects.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `utils.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/utils.h>
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>

### Official test surface

- `optimize-casts.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-casts.wast>
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-casts.wast>

The lit file still covers the same teaching families used by the living dossier:

- later refined-local reuse through a fresh carrier local
- same-index `local.set` invalidation
- later reuse across calls where the cast trap point does not move
- multiple independent locals
- earlier cast movement with type-safety guards
- side-effect and same-index-set barriers for earlier movement
- `ref.as_non_null` movement/reuse families

## Durable observations

- The 2026-05-05 current-main recheck did **not** surface teaching-relevant drift from the `version_129` contract recorded on 2026-04-22.
- `optimize-casts` remains a GC/local cast-flow pass, not a generic `ref.test`, `br_on_cast`, descriptor-cast, or extern-conversion optimizer.
- The implementation/test split remains valuable to document directly because the folder now has the owner/helper/lit-test map plus the exact local prerequisite code map.
- The most important implementation boundary remains the asymmetry between the two halves:
  - earlier movement can move trap timing and therefore needs stricter effect/control barriers
  - later reuse preserves the original cast site and can use a looser adjacent-block window
- Current Starshine still has no `src/passes/optimize_casts.mbt` owner file; the relevant local status remains the removed-name registry entry, `OC` backlog slice, GC instruction/modeling primitives, and neighboring `heap2local -> local-subtyping -> coalesce-locals -> local-cse` dossiers.

## Uncertainties and non-claims

- This bridge is a focused source-map and no-teaching-drift check, not a complete semantic diff of every current-main commit since `version_129`.
- The checked upstream sources do not justify broadening Starshine's planned `OC` slice to `ref.test` or wider cast-family rewrites. The existing backlog wording remains broader than the reviewed upstream pass and should be treated as a planning caveat until a deliberate local design widens the pass.

## Consumability rule

Cite this file for current-main source provenance and freshness. Cite [`2026-04-22-optimize-casts-primary-sources.md`](./2026-04-22-optimize-casts-primary-sources.md) for the original tagged-source manifest, and cite the living dossier pages for the beginner-to-advanced explanation.