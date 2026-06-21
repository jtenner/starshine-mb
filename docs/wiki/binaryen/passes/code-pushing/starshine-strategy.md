---
kind: concept
status: supported
last_reviewed: 2026-06-20
sources:
  - ../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
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
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../precompute/index.md
  - ../tuple-optimization/index.md
  - ../simplify-locals-nostructure/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./segment-selection-and-barriers.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../precompute/index.md
  - ../tuple-optimization/index.md
  - ../simplify-locals-nostructure/index.md
---

# Starshine Strategy For `code-pushing`

## Current status

`code-pushing` is an active explicit HOT pass in Starshine.

The owner file is:

- [`../../../../../src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt)

The current implementation is deliberately narrower than Binaryen's full source-level `Pusher` model. Its older direct-pass subset was accepted under the previous semantic criteria, but `[O4Z-AUDIT-CP]` is active under the current release-gating standard:

1. **Safe single-consuming-arm local-set sinking**
   - A root `local.set` before a void `if` can be replaced with `nop`.
   - A cloned `local.set` is inserted into the one `if` arm that contains all in-arm reads of that local.
   - Same-region suffix reads after the `if` are allowed only when the opposite arm cannot fall through under the current conservative root proof.
   - Values are limited to pure nontrapping HOT values plus guarded `global.get` and local-copy setup shapes.
2. **Ordinary-void-`if` segment movement**
   - The first mutating segment-window consumer moves one SFA `local.set` after an ordinary void `if` when the `if` itself does not read the local and every read is a same-region suffix read after the `if`.
   - The helper requires the non-mutating diagnostic to classify the window as `candidate:if` before rewriting.
3. **Non-mutating segment-window inventory**
   - Whitebox-only helpers now classify block-local `local.set` candidate windows and push-point kinds before mutation.
   - Covered labels include ordinary `if`, dropped `if`, locally representable conditional branches, SFA rejections, and coarse ordered-before barriers.
4. **Guarded setup movement across later roots**
   - Selected `global.get` and local-copy `local.set` roots can move later when intervening roots do not invalidate the source value or local proof.
   - Value-producing `if`, source writes, branchy/unreachable control, and effectful invalidation remain conservative barriers.
5. **Starshine-local typed/dead-block flattening near unreachable context**
   - A block next to an `unreachable` parent context can be flattened when branch and multivalue guards prove the splice safe.
   - This is local cleanup bundled in the current pass, not a source-confirmed upstream Binaryen `code-pushing` family.

The pass is **not** in the public `optimize` / `shrink` presets yet. That is intentional: public preset placement requires ordered-neighborhood proof around `precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure`, and is no longer a direct `code-pushing` completion blocker.

The 2026-05-09 direct lane is accepted: `.tmp/pass-fuzz-code-pushing` compared 6759/10000 cases with 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures. The debug-artifact replay reached `Normalized WAT equal: yes` and `Canonical function compare equal: yes`; raw wasm/text drift is accepted representation drift. Pass-local timing was about 1658ms for Starshine versus about 1311ms for Binaryen, clearing the 50%-of-Binaryen floor. See [`../../../raw/research/0527-2026-05-06-code-pushing-direct-revalidation.md`](../../../raw/research/0527-2026-05-06-code-pushing-direct-revalidation.md).

## Exact local code map

| File | Role |
| --- | --- |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 2-18 | Active HOT pass descriptor and summary |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 20-86 | Pure/nontrapping movable-value gate plus `global.get` / `local.get` recognizers |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 87-410 | Effect, local get/write, suffix, non-fallthrough, and value-crossing guards |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 412-516 | Non-mutating push-point / segment-window diagnostic inventory |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 519-589 | Branch, unreachable, and dead-context helpers |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 585-673 | Starshine-local dead-block flattening helper |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 674-823 | Guarded `global.get` and local-copy setup movement across later roots |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 825-902 | First ordinary-void-`if` segment movement helper |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 904-1051 | Current single-consuming-arm `local.set` into `if` rewrite |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 1053-1170 | Recursive region scan and fixed-point driver |
| [`src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt) | Focused positives and negatives for current mutating behavior |
| [`src/passes/code_pushing_wbtest.mbt`](../../../../../src/passes/code_pushing_wbtest.mbt) | Whitebox segment-window inventory and rejection-reason tests |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lines 212-220 | Registry entry as `HotPass` |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lines 382-419 | Tuple exact-slot prerequisite and preset omission |
| [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) | Registry classification and descriptor coverage |
| [`src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt) | Native / command-surface regression coverage for direct pass behavior |
| [`docs/wiki/binaryen/no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md) | Canonical scheduler context: `precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure` neighborhood |

## How local behavior maps to Binaryen

| Binaryen source-backed family | Current Starshine status |
| --- | --- |
| Function-local `LocalAnalyzer` SFA scan | Non-mutating diagnostic reports prefix-read and multiple-write SFA rejection reasons; mutating paths still use per-candidate get/write counting |
| `Pusher` block segment scan | Non-mutating segment-window diagnostic recognizes selected block-local candidate windows; mutating paths remain bounded and narrower |
| `isPushable(...)` removable-effect value gate | Replaced by stricter pure/nontrapping gate plus guarded `global.get` and local-copy cases; diagnostic reports coarse ordered-before/effect barriers |
| `isPushPoint(...)` over `if`, `switch`, conditional `br`, dropped wrappers | Diagnostic recognizes these where HOT representation is local; mutation still targets the existing void-`if` subset |
| `optimizeSegment(...)` ordered multi-set movement | First single-set ordinary-void-`if` after-movement slice implemented; broader multi-set and other push-point movement not implemented generally |
| `optimizeIntoIf(...)` one-consuming-arm sink | Partially implemented for all reads in one arm, plus same-region suffix reads when the opposite arm cannot fall through |
| Unreachable-arm post-use allowance | First conservative slice implemented for roots ending in `unreachable`, `return`, or tail-return roots |
| `version_130` ordered-before / atomics source surfaces | Not implemented generally; retained as explicit audit gap |
| GC/EH/trap-option source surfaces | Guarded out or not modeled broadly |
| Refinalization / later optimizer cycles | Starshine relies on HOT verification, lowering, and final validation; future broader ports need equivalent local retyping discipline |

## Current local positive family

Starshine targets this narrow shape:

```wat
(local.set $tmp (i32.const 7))
(if
  (local.get $cond)
  (then
    (drop (local.get $tmp))))
```

Current HOT rewrite shape:

- replace the original `local.set` root with `nop`;
- insert a cloned `local.set` at the beginning of the single consuming arm;
- leave the existing local uses in that arm.

The first ordinary-void-`if` segment slice targets this narrow shape:

```wat
(local.set $tmp (i32.const 7))
(if
  (local.get $cond)
  (then
    nop))
(drop (local.get $tmp))
```

Current HOT rewrite shape:

- replace the original `local.set` root with `nop`;
- insert a cloned `local.set` immediately after the void `if`;
- leave later same-region suffix reads unchanged.

The pass refuses to move when:

- both arms read the local;
- the local is read after the `if` and the non-consuming arm can fall through;
- there is more than one write;
- the `if` has a result;
- the source value is not movable under the strict pure/nontrapping or guarded setup gates;
- the source value may trap;
- or the target arm does not exist.

## Starshine-local dead-block flattening family

The helper `code_pushing_try_flatten_dead_block_before_unreachable(...)` handles a separate local cleanup shape:

- the current root is a `Block`;
- the surrounding context has neighboring or leading `unreachable`;
- the block body has exactly one `unreachable` at the beginning or end;
- moved non-unreachable roots are not branch-bearing and not multivalue;
- the block body can be spliced safely into the parent region.

This family helps current artifact and validation hygiene, but the wiki should keep it separate from upstream Binaryen `CodePushing.cpp`.

## Preset and tuple-slot status

`src/passes/optimize.mbt` registers `code-pushing` as active, but public presets still omit it.

Reason:

- the canonical Binaryen no-DWARF slot places `code-pushing` before `tuple-optimization`;
- `tuple_optimization_exact_slot_prereqs_ready()` still requires both `code-pushing` and `simplify-locals-no-structure` to be active before claiming the exact slot;
- `simplify-locals-nostructure` is now active locally; the remaining question is ordered preset replay, not implementation availability.
- and current `code-pushing` is still only a conservative subset.

So the honest local status is:

- direct pass flag: active;
- focused HOT subset: accepted complete under semantic / validity / 50%-speed criteria;
- exact Binaryen preset slot: not claimed;
- broader source-level `Pusher` coverage: active `[O4Z-AUDIT-CP]` work before release-gating closeout.

## Current audit widening

Read [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the detailed first-slice ladder.

The short version:

1. build on the initial analyzer/segment-window diagnostic inventory from [`0808`](../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md) and the first ordinary-void-`if` movement slice from [`0809`](../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md);
2. expand remaining safe segment movement before widening value effects;
3. preserve the first unreachable-arm post-use support and broaden it only with source-backed control-flow proof;
4. only then widen to Binaryen's broader effect-checked / ordered-before value movement;
5. test GC, atomics, EH, trap-option, switch, and conditional-branch families explicitly;
6. revisit public preset placement only with ordered-neighborhood proof.

## Related local dossiers

Read these together with this page:

- [`../precompute/index.md`](../precompute/index.md)
  - upstream left neighbor that can expose simpler roots before `code-pushing` runs.
- [`../tuple-optimization/index.md`](../tuple-optimization/index.md)
  - intended downstream consumer once exact-slot gating is honest.
- [`../simplify-locals-nostructure/index.md`](../simplify-locals-nostructure/index.md)
  - now-active right neighbor for the exact Binaryen early cleanup cluster; preset placement still needs ordered replay proof.

## Bottom line

Current Starshine `code-pushing` is active, but `[O4Z-AUDIT-CP]` is not closed under the current release-gating standard. The older direct subset remains supported by its 2026-05 evidence, the 2026-06-20 post-use slice is implemented, the first analyzer/segment inventory exists, and the first ordinary-void-`if` segment movement slice now consumes that inventory. The next active audit work is still broader source-backed segment/push-point parity, with ordered-before / atomics boundaries carried forward from the `version_130` refresh. The pass remains intentionally outside public presets until ordered-neighborhood proof lands.

## Sources

- [`../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md)
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
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
