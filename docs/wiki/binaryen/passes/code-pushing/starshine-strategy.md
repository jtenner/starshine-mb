---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md
  - ../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../agent-todo.md
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
  - ../precompute/index.md
  - ../tuple-optimization/index.md
  - ../simplify-locals-nostructure/index.md
---

# Starshine Strategy For `code-pushing`

## Current status

`code-pushing` is an active explicit HOT pass in Starshine.

The owner file is:

- [`../../../../../src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt)

The current implementation is deliberately narrower than Binaryen `version_129`:

1. **Const-like single-consuming-arm local-set sinking**
   - A root `local.set` immediately before a void `if` can be replaced with `nop`.
   - A cloned `local.set` is inserted into the one `if` arm that contains all reads of that local.
   - Values are limited to const-like HOT ops: `Const`, `RefNull`, and `RefFunc`.
2. **Starshine-local typed/dead-block flattening near unreachable context**
   - A block next to an `unreachable` parent context can be flattened when branch and multivalue guards prove the splice safe.
   - This is local cleanup bundled in the current pass, not a source-confirmed upstream Binaryen `code-pushing` family.

The pass is **not** in the public `optimize` / `shrink` presets yet.
That is intentional: the exact Binaryen scheduler slot still depends on broader `code-pushing` parity and the missing `simplify-locals-nostructure` neighbor.

## Exact local code map

| File | Role |
| --- | --- |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) | Active HOT pass descriptor, summary, const-like value check, local get/write counters, single-arm sink, dead-block flattening helper, recursive region scan, fixed-point pass loop |
| [`src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt) | Focused positive and negative tests for then/else single-arm sinks, both-arm bailout, later-use bailout, dead-block flattening, branch guard, nested later use, and trapping computation guard |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) | Registry entry as `HotPass`; optimize/shrink preset lists; tuple exact-slot gate still requiring `simplify-locals-no-structure` |
| [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) | Registry classification and descriptor coverage for active `code-pushing` |
| [`src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt) | Native / command-surface regression coverage for direct pass behavior and artifact lanes |
| [`agent-todo.md`](../../../../../agent-todo.md) | Remaining `CP` parity slice and validation ladder |
| [`docs/wiki/binaryen/no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md) | Canonical scheduler context: `precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure` neighborhood |

## How local behavior maps to Binaryen

| Binaryen source-backed family | Current Starshine status |
| --- | --- |
| Function-parallel block-local pass | Active HOT per-function pass through Starshine's hot pipeline |
| One-unreachable-arm `if` sinking | Not fully implemented as Binaryen does it; local pass has a narrower single-consuming-arm sink and a separate dead-block flatten helper |
| Generic `tryPush(...)` sibling-root movement before a later use | Not implemented generally |
| `canPushThrough(...)` effect/trap/reference movement predicate | Not implemented generally; local subset avoids most hazards by limiting sink values to const-like nodes |
| Option-sensitive trap behavior | Not implemented generally; trapping computations are guarded out in the current local subset |
| GC/EH source surfaces | Only indirectly safe through the narrow subset; no broad Binaryen GC/EH parity yet |
| Refinalization after mutation | Starshine relies on HOT verification / lowering and final validation; future broader ports need equivalent local retyping discipline |

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

- replace the original `local.set` root with `nop`,
- insert a cloned `local.set` at the beginning of the single consuming arm,
- leave the existing local uses in that arm.

The pass refuses to move when:

- both arms read the local,
- the local is read after the `if`,
- there is more than one write,
- the `if` has a result,
- the source value is not const-like,
- the source value may trap,
- or the target arm does not exist.

## Starshine-local dead-block flattening family

The helper `code_pushing_try_flatten_dead_block_before_unreachable(...)` handles a separate local cleanup shape:

- the current root is a `Block`,
- the surrounding context has neighboring or leading `unreachable`,
- the block body has exactly one `unreachable` at the beginning or end,
- moved non-unreachable roots are not branch-bearing and not multivalue,
- the block body can be spliced safely into the parent region.

This family helps current artifact and validation hygiene, but the wiki should keep it separate from upstream Binaryen `CodePushing.cpp`.

## Preset and tuple-slot status

`src/passes/optimize.mbt` registers `code-pushing` as active, but public presets still omit it.

Reason:

- the canonical Binaryen no-DWARF slot places `code-pushing` before `tuple-optimization`,
- `tuple_optimization_exact_slot_prereqs_ready()` still requires both `code-pushing` and `simplify-locals-no-structure` to be active before claiming the exact slot,
- `simplify-locals-nostructure` remains missing locally,
- and current `code-pushing` is still only a conservative subset.

So the honest local status is:

- direct pass flag: active,
- focused HOT subset: implemented,
- exact Binaryen preset slot: not claimed,
- broader parity: still backlog work.

## Remaining port work

The `CP` slice should focus on these source-backed gaps:

1. model Binaryen's one-unreachable-arm `if` path more faithfully;
2. implement a real local analogue of `canPushThrough(...)`;
3. add generic sibling-root movement before later uses;
4. cover option-sensitive trap behavior or document stricter local behavior;
5. add GC and EH reduced fixtures before widening movement;
6. run direct pass fuzz / artifact parity against Binaryen;
7. only then revisit public preset placement.

## Related local dossiers

Read these together with this page:

- [`../precompute/index.md`](../precompute/index.md)
  - upstream left neighbor that can expose simpler roots before `code-pushing` runs.
- [`../tuple-optimization/index.md`](../tuple-optimization/index.md)
  - intended downstream consumer once exact-slot gating is honest.
- [`../simplify-locals-nostructure/index.md`](../simplify-locals-nostructure/index.md)
  - missing right neighbor for the exact Binaryen early cleanup cluster.

## Bottom line

Current Starshine `code-pushing` is neither absent nor a full Binaryen port.
It is:

- active as a direct HOT pass,
- useful for a narrow const-like single-arm local-set sinking subset,
- carrying one Starshine-local dead-block cleanup helper,
- intentionally outside public presets,
- and still tracked under `CP` for broader Binaryen parity.

## Sources

- [`../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md`](../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md)
- [`../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md`](../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md)
- [`../../../../../src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt)
- [`../../../../../src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
