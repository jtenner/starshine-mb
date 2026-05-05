---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
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

`code-pushing` is already an active direct HOT pass, but it is not a full Binaryen port.

Current Starshine code locations:

| Location | Role |
| --- | --- |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 2-18 | Descriptor and summary for the active direct pass |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 20-29 | Const-like value gate: `Const`, `RefNull`, `RefFunc` only |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 31-181 | Local get/write counters and clone helper for the current single-local proof |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 184-318 | Starshine-local dead-block flattening helper and branch/multivalue guards |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 320-389 | Current `local.set` into single-consuming `if` arm rewrite |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 391-493 | Recursive region scan and fixed-point driver |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lines 212-220 | Registry entry as an active `HotPass` |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lines 382-419 | Tuple exact-slot gate plus preset arrays that still omit `code-pushing` |
| [`src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt) lines 70-263 | Focused positives and guard tests |

## Gap to Binaryen

Binaryen's source-backed strategy is broader than the local subset:

| Binaryen strategy surface | Starshine today | Port implication |
| --- | --- | --- |
| `LocalAnalyzer` SFA proof over all locals | Ad hoc exact-one-write / all-reads-in-arm counters for one local | Build analyzer first, ideally with explainable no-rewrite diagnostics |
| `Pusher` block segment scan | Only immediate `local.set` followed by `if` | Add segment-window discovery before widening moved values |
| `isPushable(...)` effect/removability gate | Const-like values only | Preserve current strictness until local effect modeling can prove more |
| `isPushPoint(...)` over `if`, `switch`, conditional `br`, dropped forms | Void `if` only | Add one push-point family at a time |
| `optimizeSegment(...)` ordered multi-set pushing | One set at a time | Keep order-preservation tests when multi-set support appears |
| `optimizeIntoIf(...)` post-if-read / unreachable-arm allowance | Only all reads inside exactly one arm | Add unreachable-arm post-use fixtures before claiming parity |
| GC/EH/trap option surfaces | Mostly guarded out | Treat as explicit follow-up slices, not incidental wins |
| Public preset placement | Omitted | Do not schedule until `simplify-locals-nostructure` and parity lanes are ready |

## Safe next slices

1. **Analyzer-only slice**
   - Add a local SFA candidate classifier mirroring Binaryen's `LocalAnalyzer` concepts.
   - Return no rewrites at first, but test candidate and rejection reasons on small HOT fixtures.
   - This reduces risk because the current pass already mutates correctly for the narrow arm-sink family.
2. **Segment-window slice**
   - Discover candidate block segments ending at a push point without moving anything.
   - Test ordinary `if`, dropped `if`, conditional branch, and `switch` recognition separately.
3. **Const-like segment movement**
   - Reuse the existing const-like gate but allow non-immediate segment movement before a push point.
   - Keep all trap/GC/EH candidates negative.
4. **Unreachable-arm post-use slice**
   - Add the Binaryen `if` nuance where the local can be read after the `if` if the opposite arm cannot fall through.
5. **Effect-checked widening**
   - Only after the earlier slices are green, widen beyond const-like values using Starshine's effect model.
6. **Preset slice**
   - Revisit public `optimize` / `shrink` placement only after direct-pass parity and the neighboring `simplify-locals-nostructure` work are honest.

## Validation ladder

For every mutating slice:

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
- GC reference cases where `ref.func`, casts, or null checks make movement observable;
- EH cases where exceptional control observes the moved value or trap timing.

## Bottom line

Starshine is ready for a careful `code-pushing` parity campaign, but the next useful work is analysis and segment discovery, not broad mutation. The 2026-04-26 source correction makes this clearer: the target is Binaryen's SFA-local `Pusher` model, while the current Starshine pass remains a deliberately strict HOT subset.

## Sources

- [`../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md)
- [`../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md)
- [`../../../../../src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt)
- [`../../../../../src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
