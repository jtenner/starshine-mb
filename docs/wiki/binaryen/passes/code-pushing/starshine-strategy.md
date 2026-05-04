---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md
  - ../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
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

The current implementation is deliberately narrower than Binaryen:

1. **Const-like single-consuming-arm local-set sinking**
   - A root `local.set` immediately before a void `if` can be replaced with `nop`.
   - A cloned `local.set` is inserted into the one `if` arm that contains all reads of that local.
   - Values are limited to const-like HOT ops: `Const`, `RefNull`, and `RefFunc`.
2. **Starshine-local typed/dead-block flattening near unreachable context**
   - A block next to an `unreachable` parent context can be flattened when branch and multivalue guards prove the splice safe.
   - This is local cleanup bundled in the current pass, not a source-confirmed upstream Binaryen `code-pushing` family.

The pass is **not** in the public `optimize` / `shrink` presets yet. That is intentional: the exact Binaryen scheduler slot still depends on broader `code-pushing` parity and ordered replay around `simplify-locals-nostructure`, which is now active locally.

## Exact local code map

| File | Role |
| --- | --- |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 2-18 | Active HOT pass descriptor and summary |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 20-29 | Const-like value gate (`Const`, `RefNull`, `RefFunc`) |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 31-181 | Local get/write counting helpers and local-set clone helper |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 184-318 | Branch/multivalue guard plus dead-block flattening helper |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 320-389 | Current single-consuming-arm `local.set` into `if` rewrite |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) lines 391-493 | Recursive region scan and fixed-point driver |
| [`src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt) lines 70-263 | Focused positives and negatives for current behavior |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lines 212-220 | Registry entry as `HotPass` |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lines 382-419 | Tuple exact-slot prerequisite and preset omission |
| [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) | Registry classification and descriptor coverage |
| [`src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt) | Native / command-surface regression coverage for direct pass behavior |
| [`docs/wiki/binaryen/no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md) | Canonical scheduler context: `precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure` neighborhood |

## How local behavior maps to Binaryen

| Binaryen source-backed family | Current Starshine status |
| --- | --- |
| Function-local `LocalAnalyzer` SFA scan | Not implemented generally; local subset has per-candidate get/write counting |
| `Pusher` block segment scan | Not implemented generally; only immediate `local.set` before `if` |
| `isPushable(...)` removable-effect value gate | Replaced by stricter const-like gate |
| `isPushPoint(...)` over `if`, `switch`, conditional `br`, dropped wrappers | Only void `if` path is supported |
| `optimizeSegment(...)` ordered multi-set movement | Not implemented generally |
| `optimizeIntoIf(...)` one-consuming-arm sink | Partially implemented for all reads in one arm and no post-if reads |
| Unreachable-arm post-use allowance | Not implemented yet |
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

The pass refuses to move when:

- both arms read the local;
- the local is read after the `if`;
- there is more than one write;
- the `if` has a result;
- the source value is not const-like;
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
- focused HOT subset: implemented;
- exact Binaryen preset slot: not claimed;
- broader parity: still backlog work.

## Remaining port work

Read [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the detailed first-slice ladder.

The short version:

1. add an analyzer-only SFA candidate classifier;
2. add segment-window and push-point discovery without mutation;
3. expand const-like segment movement before widening value effects;
4. add unreachable-arm post-use support;
5. only then widen to Binaryen's broader effect-checked value movement;
6. test GC, EH, trap-option, switch, and conditional-branch families explicitly;
7. revisit public preset placement last.

## Related local dossiers

Read these together with this page:

- [`../precompute/index.md`](../precompute/index.md)
  - upstream left neighbor that can expose simpler roots before `code-pushing` runs.
- [`../tuple-optimization/index.md`](../tuple-optimization/index.md)
  - intended downstream consumer once exact-slot gating is honest.
- [`../simplify-locals-nostructure/index.md`](../simplify-locals-nostructure/index.md)
  - now-active right neighbor for the exact Binaryen early cleanup cluster; preset placement still needs ordered replay proof.

## Bottom line

Current Starshine `code-pushing` is neither absent nor a full Binaryen port. It is active as a direct HOT pass, useful for a narrow const-like single-arm local-set sinking subset, carrying one Starshine-local dead-block cleanup helper, intentionally outside public presets, and now has a source-correct first-slice plan for broader Binaryen parity.

## Sources

- [`../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md)
- [`../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md)
- [`../../../../../src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt)
- [`../../../../../src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
