---
kind: concept
status: supported
last_reviewed: 2026-06-21
sources:
  - ../../../raw/research/0820-2026-06-21-code-pushing-local-get-window-multi-set-movement.md
  - ../../../raw/research/0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md
  - ../../../raw/research/0818-2026-06-20-code-pushing-loop-br-if-movement.md
  - ../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../raw/research/0816-2026-06-20-code-pushing-local-copy-multi-set-movement.md
  - ../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md
  - ../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md
  - ../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md
  - ../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md
  - ../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md
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
2. **Ordinary `if`, dropped `if`, and narrow `br_if` segment movement**
   - The first mutating segment-window consumer moves one SFA `local.set` after an ordinary void `if` when the `if` itself does not read the local and every read is a same-region suffix read after the `if`.
   - The dropped-wrapper extension moves the same single-set family after a dropped value `if` when the dropped push point does not read the local and every read is a same-region suffix read after the wrapper.
   - The `br_if` extension moves the same single-set family after a void-block-target or void-loop-target `br_if` with no branch values when the branch does not read the local and every read is a same-block / same-loop-body suffix read after the branch.
   - The ordered multi-set extension moves adjacent local-independent SFA sets after an ordinary void `if`, dropped value-`if`, or narrow void-block-target / void-loop-target `br_if` in source order when the push point does not read any moved local and every read is a suffix read after the push point.
   - A direct local-copy multi-set extension covers the same push-point family when copied source locals are not moved destinations and are not written by the crossed push point; the single local-copy sink remains able to move later independent copies if an earlier source-sensitive copy must stay before an `if`.
   - Separator-window extensions cover the same push-point family when local-independent SFA sets are separated only by `nop`, `drop(const)`, or `drop(local.get)` roots, leaving those separators before the push point while moving sets after it in source order.
   - The single-set helper requires the non-mutating diagnostic to classify the window as `candidate:if`, `candidate:dropped-if`, or `candidate:conditional-branch` before rewriting; the ordered multi-set helper is currently limited to ordinary-void-`if`, dropped-value-`if`, and no-branch-value `br_if` push points.
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
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 20-110 | Pure/nontrapping movable-value gate plus `global.get` / `local.get` / value-local-read recognizers |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 111-435 | Effect, local get/write, suffix, non-fallthrough, and value-crossing guards |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 436-536 | Non-mutating push-point / segment-window diagnostic inventory |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 537-637 | Branch, unreachable, and dead-context helpers |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 638-726 | Starshine-local dead-block flattening helper |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 727-877 | Guarded `global.get` and local-copy setup movement across later roots |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 878-1054 | Ordered multi-set movement after ordinary void `if`, dropped value-`if`, or narrow `br_if`, including adjacent, direct local-copy, `nop`-separated, `drop(const)`-separated, and `drop(local.get)`-separated windows |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 996-1100 | Single-set ordinary-void-`if`, dropped value-`if`, and narrow `br_if` segment movement helper |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 1101-1249 | Current single-consuming-arm `local.set` into `if` rewrite |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 1250-1364 | Recursive region scan and fixed-point driver |
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
| `Pusher` block segment scan | Non-mutating segment-window diagnostic recognizes selected block-local candidate windows; mutating paths now consume ordinary `if` and dropped-`if` after-movement subsets while remaining bounded and narrower |
| `isPushable(...)` removable-effect value gate | Replaced by stricter pure/nontrapping gate plus guarded `global.get` and local-copy cases; diagnostic reports coarse ordered-before/effect barriers |
| `isPushPoint(...)` over `if`, `switch`, conditional `br`, dropped wrappers | Diagnostic recognizes these where HOT representation is local; mutation targets ordinary void `if`, dropped value-`if` wrappers, and void-block-target / void-loop-target `br_if` subsets |
| `optimizeSegment(...)` ordered multi-set movement | First single-set ordinary-void-`if`, dropped-`if`, and narrow `br_if` after-movement slices implemented; ordered adjacent multi-set movement implemented for local-independent values before ordinary void `if`, dropped value-`if`, narrow void-block-target `br_if`, and narrow void-loop-target `br_if`, plus direct local-copy values when source locals are stable and `nop`-/`drop(const)`-/`drop(local.get)`-separated local-independent windows; broader multi-set, arbitrary separators beyond `nop` / `drop(const)` / `drop(local.get)`, and other push-point movement not implemented generally |
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

The dropped value-`if` segment slice targets this narrow shape:

```wat
(local.set $tmp (i32.const 7))
(drop
  (if (result i32)
    (local.get $cond)
    (then (i32.const 1))
    (else (i32.const 2))))
(drop (local.get $tmp))
```

Current HOT rewrite shape:

- replace the original `local.set` root with `nop`;
- insert a cloned `local.set` immediately after the dropped wrapper;
- leave later same-region suffix reads unchanged.

The narrow block-target `br_if` segment slice targets this shape:

```wat
(block $exit
  (local.set $tmp (i32.const 7))
  (br_if $exit (local.get $cond))
  (drop (local.get $tmp)))
```

Current HOT rewrite shape:

- replace the original `local.set` root with `nop`;
- insert a cloned `local.set` immediately after the `br_if`;
- require a void block target with no branch values;
- leave later same-block suffix reads unchanged.

The narrow loop-target `br_if` segment slice targets the analogous loop-backedge shape:

```wat
(loop $top
  (local.set $tmp (i32.const 7))
  (br_if $top (local.get $cond))
  (drop (local.get $tmp)))
```

Current HOT rewrite shape:

- replace the original `local.set` root with `nop`;
- insert a cloned `local.set` immediately after the `br_if`;
- require a void loop target with no branch values;
- leave later same-loop-body suffix reads unchanged.

The ordered multi-set ordinary-void-`if` slice targets this shape:

```wat
(local.set $a (i32.const 7))
(local.set $b (i32.const 9))
(if
  (local.get $cond)
  (then
    nop))
(drop (local.get $a))
(drop (local.get $b))
```

Current HOT rewrite shape:

- replace both original `local.set` roots with `nop`;
- insert cloned `local.set $a` then `local.set $b` immediately after the void `if`, preserving source order;
- require adjacent local-independent movable values and same-region suffix reads.

The ordered multi-set dropped value-`if` slice targets this shape:

```wat
(local.set $a (i32.const 7))
(local.set $b (i32.const 9))
(drop
  (if (result i32)
    (local.get $cond)
    (then (i32.const 1))
    (else (i32.const 2))))
(drop (local.get $a))
(drop (local.get $b))
```

Current HOT rewrite shape:

- replace both original `local.set` roots with `nop`;
- insert cloned `local.set $a` then `local.set $b` immediately after the dropped wrapper, preserving source order;
- require adjacent local-independent movable values and same-region suffix reads.

The ordered multi-set `br_if` slice targets this shape:

```wat
(block $exit
  (local.set $a (i32.const 7))
  (local.set $b (i32.const 9))
  (br_if $exit (local.get $cond))
  (drop (local.get $a))
  (drop (local.get $b)))
```

Current HOT rewrite shape:

- replace both original `local.set` roots with `nop`;
- insert cloned `local.set $a` then `local.set $b` immediately after the `br_if`, preserving source order;
- require adjacent local-independent movable values and same-block suffix reads.

The separator-window ordered multi-set slices cover the same three push points when only `nop`, `drop(const)`, or `drop(local.get)` roots separate local-independent SFA sets. The `nop` shape is:

```wat
(local.set $a (i32.const 7))
nop
(local.set $b (i32.const 9))
(if
  (local.get $cond)
  (then
    nop))
(drop (local.get $a))
(drop (local.get $b))
```

Current HOT rewrite shape leaves the separator before the push point and inserts cloned `local.set $a` then `local.set $b` after it. The `drop(const)` and `drop(local.get)` shapes are analogous; one uses a dead dropped constant and the other uses a dropped local read between the two sets:

```wat
(local.set $a (i32.const 7))
(drop (i32.const 99))
(local.set $b (i32.const 9))
(if
  (local.get $cond)
  (then
    nop))
(drop (local.get $a))
(drop (local.get $b))
```

The pass refuses to move when:

- both arms read the local;
- the local is read after the `if` and the non-consuming arm can fall through;
- there is more than one write;
- an ordinary `candidate:if` has a result outside the dropped-wrapper case;
- a `candidate:conditional-branch` is not a no-branch-value `br_if` to a void block or loop label;
- ordered multi-set movement would need non-adjacent sets beyond `nop`, `drop(const)`, or `drop(local.get)` separators, push points outside ordinary void `if` / dropped value-`if` / narrow `br_if`, local-copy dependency chains, duplicate locals, arm or branch reads of moved locals, source-local writes, or non-suffix reads;
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

1. build on the initial analyzer/segment-window diagnostic inventory from [`0808`](../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md), the first ordinary-void-`if` movement slice from [`0809`](../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md), the first dropped-`if` movement slice from [`0811`](../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md), the first narrow `br_if` movement slice from [`0812`](../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md), the ordinary-`if` ordered multi-set slice from [`0813`](../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md), the dropped-`if` ordered multi-set slice from [`0814`](../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md), the `br_if` ordered multi-set slice from [`0815`](../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md), the local-copy slice from [`0816`](../../../raw/research/0816-2026-06-20-code-pushing-local-copy-multi-set-movement.md), the `nop`-window slice from [`0817`](../../../raw/research/0817-2026-06-20-code-pushing-nop-window-multi-set-movement.md), the loop-target `br_if` slice from [`0818`](../../../raw/research/0818-2026-06-20-code-pushing-loop-br-if-movement.md), the `drop(const)` window slice from [`0819`](../../../raw/research/0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md), and the `drop(local.get)` window slice from [`0820`](../../../raw/research/0820-2026-06-21-code-pushing-local-get-window-multi-set-movement.md);
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

Current Starshine `code-pushing` is active, but `[O4Z-AUDIT-CP]` is not closed under the current release-gating standard. The older direct subset remains supported by its 2026-05 evidence, the 2026-06-20 post-use slice is implemented, the analyzer/segment inventory exists, and the ordinary-void-`if`, dropped value-`if`, block-target and loop-target `br_if`, ordinary-`if` multi-set, dropped-`if` multi-set, `br_if` multi-set, direct local-copy multi-set, `nop`-window multi-set, `drop(const)`-window multi-set, and `drop(local.get)`-window multi-set segment movement slices now consume that inventory. The next active audit work is still broader source-backed segment/push-point parity, with ordered-before / atomics boundaries carried forward from the `version_130` refresh. The pass remains intentionally outside public presets until ordered-neighborhood proof lands.

## Sources

- [`../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- [`../../../raw/research/0820-2026-06-21-code-pushing-local-get-window-multi-set-movement.md`](../../../raw/research/0820-2026-06-21-code-pushing-local-get-window-multi-set-movement.md)
- [`../../../raw/research/0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md`](../../../raw/research/0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md)
- [`../../../raw/research/0816-2026-06-20-code-pushing-local-copy-multi-set-movement.md`](../../../raw/research/0816-2026-06-20-code-pushing-local-copy-multi-set-movement.md)
- [`../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md`](../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md)
- [`../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md`](../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md)
- [`../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md`](../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md)
- [`../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md`](../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md)
- [`../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md`](../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md)
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
