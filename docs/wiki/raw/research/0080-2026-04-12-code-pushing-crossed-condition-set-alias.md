# 0080 - Code-Pushing Crossed Condition-Set Alias Guard Narrowing

## Scope

- Recheck whether the crossed condition-set carrier alias guard is still broader
  than Binaryen's actual `code-pushing` surface.
- Reduce a case where an earlier explicit-exit carrier exists, but the crossed
  condition-set does **not** alias the same carried local.
- Compare that against the current Starshine guard in
  `cp_push_to_pushpoint_has_condition_set_crossed_carrier_alias_guard`.

## Primary Sources

- Existing project study:
  [`docs/0073-2026-04-02-code-pushing-binaryen-plan.md`](../../../0073-2026-04-02-code-pushing-binaryen-plan.md)
- Existing frontier pages:
  - [`docs/wiki/binaryen/passes/code-pushing/artifact-frontiers.md`](../../binaryen/passes/code-pushing/artifact-frontiers.md)
  - [`docs/wiki/binaryen/passes/code-pushing/starshine-hot-ir-strategy.md`](../../binaryen/passes/code-pushing/starshine-hot-ir-strategy.md)
- Current in-tree implementation and tests:
  - [`src/passes/code_pushing.mbt`](/home/jtenner/Projects/starshine-mb-code-pushing/src/passes/code_pushing.mbt)
  - [`src/passes/code_pushing_test.mbt`](/home/jtenner/Projects/starshine-mb-code-pushing/src/passes/code_pushing_test.mbt)

## Reduced Binaryen Probe

Input:

```wat
(module
  (func (param i32 i32) (result i32)
    (local i32 i32 i32 i32)
    (local.set 2
      (block $carrier (result i32)
        (block $work
          (if (local.get 0)
            (then
              (br $work)))
          (br $carrier (local.get 1))
          unreachable)
        (local.get 1)))
    (if (local.get 0)
      (then
        nop))
    (local.get 1)
    (local.set 3)
    (local.get 0)
    (local.set 4)
    (if
      (local.get 4)
      (then
        nop))
    (local.get 4)
    (local.set 5)
    (local.get 3)))
```

Binaryen `wasm-opt --code-pushing -S` output:

- keeps the earlier explicit-exit carrier in place
- keeps the crossed condition-set `local.set 4 (local.get 0)` before the later
  `if`
- but moves the carried alias `local.set 3 (local.get 1)` to immediately after
  that later `if`

So Binaryen does **not** treat the mere existence of an earlier explicit-exit
carrier as enough to block the move.

## Diagnosis

- Starshine's crossed condition-set carrier alias guard was still too broad.
- The old guard only required:
  - the candidate was an alias `local.set(local.get source_local)`
  - an earlier explicit-exit carrier matched that same `source_local`
  - the crossed root before the target `if` was some `local.set`
  - the later `if` condition read that crossed local
- That was wider than the real intended case.
- The older reduced negative fixture already described the real blocker more
  narrowly: the kept condition-set must itself alias the same carried local.
- In the reduced Binaryen probe above, the crossed condition-set is
  `local.set 4 (local.get 0)`, which does **not** alias the carried local
  `1`, so Binaryen still moves the candidate alias after the later `if`.

## Kept Repository Change

- `src/passes/code_pushing.mbt` now narrows
  `cp_push_to_pushpoint_has_condition_set_crossed_carrier_alias_guard`.
- The guard now requires the crossed condition-set to also be an alias
  `local.set(local.get source_local)` for that same carried source local.
- The reduced positive case is now pinned in
  `src/passes/code_pushing_test.mbt` alongside the existing reduced negative
  case where the condition-set really does alias the same carried local.

## Validation

- `moon test src/passes`
- `moon test src/cmd/cmd_test.mbt`
- `bun scripts/pass-fuzz-compare.ts --pass code-pushing --generator gen-valid --count 10000 --max-failures 5 --out-dir .tmp/pass-fuzz-code-pushing-20260412c`
- `bun scripts/pass-fuzz-compare.ts --pass code-pushing --generator wasm-smith --count 1000 --max-failures 5 --out-dir .tmp/pass-fuzz-code-pushing-20260412d`

## Practical Decision

- Keep the crossed condition-set carrier alias guard only for the real aliasing
  case it was meant to cover.
- Do not let an unrelated condition-set local stand in for that stronger alias
  relation.
- The remaining explicit-exit-carrier-fed `Func 1977` frontier is therefore
  narrower again than the previous Starshine guard implied.
