---
kind: concept
status: supported
last_reviewed: 2026-06-20
sources:
  - ../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../raw/research/0806-2026-06-20-code-pushing-unreachable-arm-post-use.md
  - ../../../raw/research/0527-2026-05-06-code-pushing-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md
  - ../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md
  - ../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./segment-selection-and-barriers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../tuple-optimization/index.md
  - ../simplify-locals-nostructure/index.md
---

# Starshine Port Readiness And Validation For `code-pushing`

## Current local status

`code-pushing` is an active direct HOT pass. Its earlier v0.1.0 direct-pass acceptance is now superseded by the broader active `[O4Z-AUDIT-CP]` behavior-audit track in `agent-todo.md`; future closure must satisfy the repo's current pass-audit standard rather than relying only on the older 2026-05-09 direct revalidation. As of 2026-05-09, direct debug-artifact compare for `tests/node/dist/starshine-debug-wasi.wasm --code-pushing` was semantically/canonically green through the self-opt compare canonical-function fallback (`Normalized WAT equal: yes`, `Canonical function compare equal: yes`). Raw canonical wasm/text still differed because HOT lowering and Binaryen choose different temporary-local / expression-stack shapes.

The first 2026-06-20 audit-widening slice adds Binaryen-backed post-`if` read support when the local is read in exactly one `if` arm and the opposite arm cannot fall through. The note [`0806`](../../../raw/research/0806-2026-06-20-code-pushing-unreachable-arm-post-use.md) records the Binaryen oracle probe, red-first test, implementation guard, and focused evidence.

The second 2026-06-20 audit slice refreshed the current `version_130` Binaryen source/lit surface. The new bridge [`2026-06-20-code-pushing-version-130-source-lit-refresh`](../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md) and research note [`0807`](../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md) supersede the older current-main bridge for release-gating decisions. The refresh found stable owner structure, `effects.orderedBefore(cumulativeEffects)` replacing the older invalidation checks, and a new `code-pushing-atomics.wast` proof surface for GC reads across shared atomic loads/stores.

The accepted criteria are pass-wide: match Binaryen semantics, emit valid wasm after safe transforms, and stay at least 50% as fast as Binaryen on comparable pass-local measurements (`starshine_time <= 2 * binaryen_time`). The current debug-artifact timing, about 1658ms for Starshine versus about 1311ms for Binaryen, clears that floor.

Current Starshine code locations:

| Location | Role |
| --- | --- |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 2-18 | Descriptor and summary for the active direct pass |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 20-86 | Pure/nontrapping movable-value gate plus `global.get` / `local.get` recognizers |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 87-429 | Effect, local get/write, branch, unreachable, and multivalue guards |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 430-518 | Starshine-local dead-block flattening helper |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 519-669 | Guarded `global.get` and local-copy setup movement across later roots |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 670-784 | Current `local.set` into single-consuming `if` arm rewrite |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 786-900 | Recursive region scan and fixed-point driver |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lines 212-220 | Registry entry as an active `HotPass` |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lines 382-419 | Tuple exact-slot gate plus preset arrays that still omit `code-pushing` |
| [`src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt) | Focused positives and guard tests |

## Gap to Binaryen

Binaryen's source-backed strategy is broader than the local subset:

| Binaryen strategy surface | Starshine today | Port implication |
| --- | --- | --- |
| `LocalAnalyzer` SFA proof over all locals | Ad hoc exact-one-write / all-reads-in-arm counters for one local | Build analyzer first, ideally with explainable no-rewrite diagnostics |
| `Pusher` block segment scan | Bounded root lookahead covers selected `if` and later-barrier shapes, but not general Binaryen segment windows | Add segment-window discovery before widening moved values |
| `isPushable(...)` effect/removability gate | Pure nontrapping values plus guarded `global.get` and local-copy shapes | Preserve strictness unless local effect modeling proves more; `version_130` movement checks require ordered-before reasoning, not only coarse invalidation |
| `isPushPoint(...)` over `if`, `switch`, conditional `br`, dropped forms | Void `if` only | Add one push-point family at a time |
| `optimizeSegment(...)` ordered multi-set pushing | One set at a time | Keep order-preservation tests when multi-set support appears |
| `optimizeIntoIf(...)` post-if-read / unreachable-arm allowance | First conservative slice implemented for same-region suffix reads when the opposite arm ends in non-fallthrough roots such as `unreachable` | Broaden only with source-backed control-flow proofs; keep fallthrough post-use negative coverage |
| GC/EH/trap/atomics option surfaces | Mostly guarded out | Treat as explicit follow-up slices, not incidental wins; `code-pushing-atomics.wast` is now part of the current proof surface |
| Public preset placement | Omitted | Do not schedule until `simplify-locals-nostructure` and parity lanes are ready |

## Optional future widening slices

1. **Analyzer-only slice**
   - Add a local SFA candidate classifier mirroring Binaryen's `LocalAnalyzer` concepts.
   - Return no rewrites at first, but test candidate and rejection reasons on small HOT fixtures.
   - This reduces risk because the current pass already mutates correctly for the narrow arm-sink family.
2. **Segment-window slice**
   - Discover candidate block segments ending at a push point without moving anything.
   - Test ordinary `if`, dropped `if`, conditional branch, and `switch` recognition separately.
   - Include source-backed diagnostics for ordered-before / atomic-store barriers before broad movement.
3. **Safe segment movement**
   - Reuse the existing strict movable-value gate but allow non-immediate segment movement before a push point.
   - Keep all trap/GC/EH candidates negative.
4. **Unreachable-arm post-use slice**
   - First conservative slice completed in [`0806`](../../../raw/research/0806-2026-06-20-code-pushing-unreachable-arm-post-use.md): same-region suffix reads are allowed when the non-consuming arm cannot fall through. Future work can broaden the non-fallthrough proof beyond the current simple root-ending helper only with source-backed tests.
5. **Effect-checked widening**
   - Only after the earlier slices are green, widen beyond the current strict movable-value gates using Starshine's effect model.
6. **Preset slice**
   - Revisit public `optimize` / `shrink` placement only after direct-pass semantic parity and the neighboring `simplify-locals-nostructure` work are honest.

## Validation ladder

The 2026-05-09 direct revalidation for the current explicit HOT subset is accepted: `moon info`, `moon fmt`, `moon test`, and `bun scripts/pass-fuzz-compare.ts --pass code-pushing --count 10000 --seed 0x5eed --max-failures 20 --out-dir .tmp/pass-fuzz-code-pushing` completed with 6759/10000 compared cases, 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen/tool command failures. The direct debug-artifact replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1687067` reports `Normalized WAT equal: yes` and `Canonical function compare equal: yes`; canonical wasm/text remain unequal, but that drift is representation-only and not a blocker. Pass-local timing, about 1658ms for Starshine versus about 1311ms for Binaryen, is above the required 50%-of-Binaryen floor. `[CP]002` is therefore closed; preset scheduling remains deferred to ordered-neighborhood / tuple-slot work.

For every future mutating widening slice:

1. Add or update focused tests in [`src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt).
2. Keep direct-pass registry and command tests green.
3. Compare reduced WAT against Binaryen `wasm-opt --code-pushing` for the exact shape family being widened.
4. Run pass-targeted fuzz compare before preset scheduling.
5. Re-run generated-artifact `-O4z` slot checks only after neighboring pass prerequisites are available.

## Required negative fixtures

Do not widen without explicit tests for:

- non-SFA locals: parameter locals, multiple sets, tee writes, and read-before-set cases;
- moved values with visible effects or traps under default options;
- both-arm live uses where duplication would be required;
- post-if reads when the non-consuming arm can fall through;
- multi-set order preservation;
- GC reference and atomics cases where `ref.func`, casts, null checks, shared atomic stores, or ordered-before effects make movement observable;
- EH cases where exceptional control observes the moved value or trap timing.

## Bottom line

Starshine's older direct `code-pushing` subset remains supported by its 2026-05 evidence, but `[O4Z-AUDIT-CP]` is active and not closed under the current release-gating standard. The next useful work is analysis and segment discovery, with ordered-before / atomics boundaries carried forward from the `version_130` refresh. Public preset scheduling remains separate ordered-neighborhood work.

## Sources

- [`../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- [`../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- [`../../../raw/research/0806-2026-06-20-code-pushing-unreachable-arm-post-use.md`](../../../raw/research/0806-2026-06-20-code-pushing-unreachable-arm-post-use.md)
- [`../../../raw/research/0527-2026-05-06-code-pushing-direct-revalidation.md`](../../../raw/research/0527-2026-05-06-code-pushing-direct-revalidation.md)
- [`../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md)
- [`../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md)
- [`../../../../../src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt)
- [`../../../../../src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
