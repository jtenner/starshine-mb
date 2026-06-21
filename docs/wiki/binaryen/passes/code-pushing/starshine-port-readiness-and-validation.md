---
kind: concept
status: supported
last_reviewed: 2026-06-20
sources:
  - ../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md
  - ../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md
  - ../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md
  - ../../../raw/research/0810-2026-06-20-code-pushing-dedicated-genvalid-profile.md
  - ../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md
  - ../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md
  - ../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../raw/research/0806-2026-06-20-code-pushing-unreachable-arm-post-use.md
  - ../../../raw/research/0527-2026-05-06-code-pushing-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md
  - ../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md
  - ../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/passes/code_pushing_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
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

The third 2026-06-20 audit slice added non-mutating segment-window inventory in [`0808`](../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md). `code_pushing_push_point_kind(...)` recognizes ordinary `if`, dropped push-point wrappers, locally representable conditional branches, and switch/`br_table` roots; `code_pushing_segment_window_diagnostic(...)` reports SFA/use/effect rejection reasons before any broad `optimizeSegment(...)` movement is enabled. Whitebox tests cover `candidate:if`, `candidate:dropped-if`, `candidate:conditional-branch`, `reject:prefix-local-read`, `reject:multiple-local-writes`, and `reject:ordered-before-barrier`.

The fourth 2026-06-20 audit slice added the first mutating consumer of that inventory in [`0809`](../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md). `code_pushing_try_sink_set_after_if_push_point(...)` moves one SFA set after an ordinary void `if` when the `if` does not read the local and all reads are same-region suffix reads after the `if`. Focused tests cover the Binaryen-backed positive, a prefix-read negative, and a coarse ordered-before barrier negative.

The fifth 2026-06-20 audit slice added the dedicated GenValid profile in [`0810`](../../../raw/research/0810-2026-06-20-code-pushing-dedicated-genvalid-profile.md). `code-pushing-all` initially sampled `code-pushing-if-arm` and `code-pushing-after-if`, the two implemented positive movement families at that point, and the bounded native profile lane was green under `--normalize local-cleanup-debris` because Starshine removes standalone `nop`/empty-else debris that Binaryen leaves.

The sixth 2026-06-20 audit slice added dropped value-`if` segment movement in [`0811`](../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md). `code_pushing_try_sink_set_after_if_push_point(...)` now accepts `candidate:dropped-if`, unwraps the inner value `if` for local-use checks, and inserts the cloned set after the dropped wrapper when all local reads are same-region suffix reads. The `code-pushing-all` profile now includes `code-pushing-dropped-if`; a bounded native profile lane compared `300/300` with `0` raw mismatches/failures under `--normalize local-cleanup-debris`.

The seventh 2026-06-20 audit slice added narrow `br_if` segment movement in [`0812`](../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md). `code_pushing_try_sink_set_after_if_push_point(...)` now accepts `candidate:conditional-branch` only for a no-branch-value `BrIf` to a void block label, and inserts the cloned set after the branch when the branch does not read the local and every read is a same-block suffix read. The `code-pushing-all` profile now includes `code-pushing-br-if`; a bounded native profile lane compared `400/400` with `0` raw mismatches/failures under `--normalize local-cleanup-debris`.

The eighth 2026-06-20 audit slice added ordered multi-set movement in [`0813`](../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md). `code_pushing_try_sink_ordered_sets_after_void_if(...)` moves adjacent local-independent SFA sets after an ordinary void `if` in source order when neither arm reads any moved local and every read is a same-region suffix read. The `code-pushing-all` profile now includes `code-pushing-multi-set`; a bounded native profile lane compared `500/500` with `0` raw mismatches/failures under `--normalize local-cleanup-debris`.

The accepted criteria are pass-wide: match Binaryen semantics, emit valid wasm after safe transforms, and stay at least 50% as fast as Binaryen on comparable pass-local measurements (`starshine_time <= 2 * binaryen_time`). The current debug-artifact timing, about 1658ms for Starshine versus about 1311ms for Binaryen, clears that floor.

Current Starshine code locations:

| Location | Role |
| --- | --- |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 2-18 | Descriptor and summary for the active direct pass |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 20-110 | Pure/nontrapping movable-value gate plus `global.get` / `local.get` / value-local-read recognizers |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 111-435 | Effect, local get/write, suffix, non-fallthrough, and value-crossing guards |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 436-536 | Non-mutating push-point / segment-window diagnostic inventory |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 537-637 | Branch, unreachable, and dead-context helpers |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 638-726 | Starshine-local dead-block flattening helper |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 727-877 | Guarded `global.get` and local-copy setup movement across later roots |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 878-995 | Ordered adjacent multi-set movement after ordinary void `if` |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 996-1100 | Single-set ordinary-void-`if`, dropped value-`if`, and narrow `br_if` segment movement helper |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 1101-1249 | Current `local.set` into single-consuming `if` arm rewrite |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 1250-1364 | Recursive region scan and fixed-point driver |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lines 212-220 | Registry entry as an active `HotPass` |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lines 382-419 | Tuple exact-slot gate plus preset arrays that still omit `code-pushing` |
| [`src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt) | Focused positives and guard tests for mutating behavior |
| [`src/passes/code_pushing_wbtest.mbt`](../../../../../src/passes/code_pushing_wbtest.mbt) | Whitebox segment-window inventory and rejection-reason tests |
| [`src/validate/gen_valid.mbt`](../../../../../src/validate/gen_valid.mbt) | Dedicated `code-pushing-all` / leaf profile generation |
| [`src/validate/gen_valid_tests.mbt`](../../../../../src/validate/gen_valid_tests.mbt) | Profile resolution, sampling, validating-module, and candidate-shape tests |

## Gap to Binaryen

Binaryen's source-backed strategy is broader than the local subset:

| Binaryen strategy surface | Starshine today | Port implication |
| --- | --- | --- |
| `LocalAnalyzer` SFA proof over all locals | Non-mutating diagnostic now reports prefix-read and multiple-write SFA rejection reasons; mutating paths still use per-candidate counters | Grow the diagnostic toward a fuller analyzer before broad mutation |
| `Pusher` block segment scan | Segment-window diagnostic recognizes selected block-local candidate windows; ordinary-void-`if`, dropped value-`if`, and narrow `br_if` after-movement slices consume `candidate:if` / `candidate:dropped-if` / `candidate:conditional-branch`; other mutating paths remain bounded and narrower | Continue consuming the discovery layer in one safe movement family at a time |
| `isPushable(...)` effect/removability gate | Pure nontrapping values plus guarded `global.get` and local-copy shapes; diagnostic can report coarse ordered-before/effect barriers | Preserve strictness unless local effect modeling proves more; `version_130` movement checks require ordered-before reasoning, not only coarse invalidation |
| `isPushPoint(...)` over `if`, `switch`, conditional `br`, dropped forms | Diagnostic recognizes these families where HOT representation is local; mutation now targets ordinary void `if`, dropped value-`if` wrappers, and a no-branch-value `br_if` to a void block label | Add one remaining push-point mutation family at a time |
| `optimizeSegment(...)` ordered multi-set pushing | First single-set ordinary-void-`if`, dropped-`if`, and narrow `br_if` after-movement slices implemented; first adjacent local-independent multi-set movement after ordinary void `if` implemented; broader movement remains one set at a time or unimplemented | Keep order-preservation tests as multi-set support grows beyond this first ordinary-`if` slice |
| `optimizeIntoIf(...)` post-if-read / unreachable-arm allowance | First conservative slice implemented for same-region suffix reads when the opposite arm ends in non-fallthrough roots such as `unreachable` | Broaden only with source-backed control-flow proofs; keep fallthrough post-use negative coverage |
| GC/EH/trap/atomics option surfaces | Mostly guarded out | Treat as explicit follow-up slices, not incidental wins; `code-pushing-atomics.wast` is now part of the current proof surface |
| Public preset placement | Omitted | Do not schedule until `simplify-locals-nostructure` and parity lanes are ready |

## Optional future widening slices

1. **Analyzer/segment-window inventory slice**
   - Initial non-mutating inventory is complete in [`0808`](../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md): it reports SFA/use/effect rejection reasons and recognizes ordinary `if`, dropped `if`, conditional branch, and switch/`br_table` push-point kinds.
   - Future analyzer work can widen this into a fuller `LocalAnalyzer` equivalent, especially for tee writes, parameter locals, nested regions, and atomics/GC/EH barriers.
2. **Safe segment movement**
   - First ordinary-void-`if` after-movement completed in [`0809`](../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md): a single SFA set moves after the `if` when all reads are later suffix reads.
   - Dropped value-`if` after-movement completed in [`0811`](../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md): a single SFA set moves after a dropped value-`if` when all reads are later suffix reads and the dropped push point does not read the local.
   - Narrow `br_if` after-movement completed in [`0812`](../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md): a single SFA set moves after a no-branch-value `br_if` to a void block label when all reads are later suffix reads and the branch does not read the local.
   - Ordered multi-set ordinary-`if` movement completed in [`0813`](../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md): adjacent local-independent SFA sets move after an ordinary void `if` in source order.
   - Future work should add other push points or broader multi-set movement only one family at a time.
   - Keep all trap/GC/EH candidates negative.
3. **Unreachable-arm post-use slice**
   - First conservative slice completed in [`0806`](../../../raw/research/0806-2026-06-20-code-pushing-unreachable-arm-post-use.md): same-region suffix reads are allowed when the non-consuming arm cannot fall through. Future work can broaden the non-fallthrough proof beyond the current simple root-ending helper only with source-backed tests.
4. **Effect-checked widening**
   - Only after the earlier slices are green, widen beyond the current strict movable-value gates using Starshine's effect model.
5. **Dedicated profile growth**
   - `code-pushing-all` now covers the implemented `if`-arm, after-`if`, dropped-`if`, narrow `br_if`, and ordinary-`if` ordered multi-set positive families. Add leaves when switch/`br_table`, broader conditional branches, broader ordered multi-set movement, or atomics/GC/EH/trap-policy slices land.
6. **Preset slice**
   - Revisit public `optimize` / `shrink` placement only after direct-pass semantic parity and the neighboring `simplify-locals-nostructure` work are honest.

## Validation ladder

The 2026-05-09 direct revalidation for the current explicit HOT subset is accepted: `moon info`, `moon fmt`, `moon test`, and `bun scripts/pass-fuzz-compare.ts --pass code-pushing --count 10000 --seed 0x5eed --max-failures 20 --out-dir .tmp/pass-fuzz-code-pushing` completed with 6759/10000 compared cases, 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen/tool command failures. The direct debug-artifact replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1687067` reports `Normalized WAT equal: yes` and `Canonical function compare equal: yes`; canonical wasm/text remain unequal, but that drift is representation-only and not a blocker. Pass-local timing, about 1658ms for Starshine versus about 1311ms for Binaryen, is above the required 50%-of-Binaryen floor. `[CP]002` is therefore closed; preset scheduling remains deferred to ordered-neighborhood / tuple-slot work.

Current dedicated-profile evidence from [`0810`](../../../raw/research/0810-2026-06-20-code-pushing-dedicated-genvalid-profile.md), [`0811`](../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md), [`0812`](../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md), and [`0813`](../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md): focused generator tests for `code-pushing` profiles passed `3/3` across the `*code-pushing*` filter after adding `code-pushing-multi-set`. `moon build --target native --release src/cmd` produced `_build/native/release/build/cmd/cmd.exe` in this checkout. The refreshed native `code-pushing-all` lane with `--normalize local-cleanup-debris` compared `500/500`, with `227` normalized matches, `273` cleanup-normalized matches, `0` raw mismatches, `0` validation/generator/property/command failures, and selected subprofiles `code-pushing-after-if: 91`, `code-pushing-multi-set: 85`, `code-pushing-if-arm: 97`, `code-pushing-dropped-if: 121`, `code-pushing-br-if: 106`. The earlier non-normalized probe stopped after `65` raw mismatches, all classified as bounded local-cleanup drift from Starshine removing standalone `nop`/empty-else debris.

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

Starshine's older direct `code-pushing` subset remains supported by its 2026-05 evidence, but `[O4Z-AUDIT-CP]` is active and not closed under the current release-gating standard. The analyzer/segment inventory, ordinary-void-`if` segment movement, dropped value-`if` segment movement, narrow `br_if` movement, ordered ordinary-`if` multi-set movement, and dedicated GenValid profile are now in-tree, so the next useful work is another source-backed push-point or movement family while keeping ordered-before / atomics boundaries carried forward from the `version_130` refresh. Public preset scheduling remains separate ordered-neighborhood work.

## Sources

- [`../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- [`../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md`](../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md)
- [`../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md`](../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md)
- [`../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md`](../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md)
- [`../../../raw/research/0810-2026-06-20-code-pushing-dedicated-genvalid-profile.md`](../../../raw/research/0810-2026-06-20-code-pushing-dedicated-genvalid-profile.md)
- [`../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md`](../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md)
- [`../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md`](../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md)
- [`../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- [`../../../raw/research/0806-2026-06-20-code-pushing-unreachable-arm-post-use.md`](../../../raw/research/0806-2026-06-20-code-pushing-unreachable-arm-post-use.md)
- [`../../../raw/research/0527-2026-05-06-code-pushing-direct-revalidation.md`](../../../raw/research/0527-2026-05-06-code-pushing-direct-revalidation.md)
- [`../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md)
- [`../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md)
- [`../../../../../src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt)
- [`../../../../../src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt)
- [`../../../../../src/passes/code_pushing_wbtest.mbt`](../../../../../src/passes/code_pushing_wbtest.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
