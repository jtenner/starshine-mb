# 0079 - Code-Pushing One-Off Alias Tail Prefix Narrowing

## Scope

- Recheck whether the current one-off alias-if-tail fence is broader than the
  real Binaryen surface.
- Reduce a current Binaryen artifact slice where a plain alias `local.set` moves
  past a later decref-style `if`, even though Starshine's kept one-off-tail
  guard still blocks the same shape.
- Decide whether the real blocker is the tail pattern itself, or only the
  explicit-exit-carrier-fed subset that originally motivated the `Func 1977`
  fence.

## Primary Sources

- Existing project study:
  [`docs/0073-2026-04-02-code-pushing-binaryen-plan.md`](../../../0073-2026-04-02-code-pushing-binaryen-plan.md)
- Existing `code-pushing` frontier pages:
  - [`docs/wiki/binaryen/passes/code-pushing/artifact-frontiers.md`](../../binaryen/passes/code-pushing/artifact-frontiers.md)
  - [`docs/wiki/binaryen/passes/code-pushing/starshine-hot-ir-strategy.md`](../../binaryen/passes/code-pushing/starshine-hot-ir-strategy.md)
- Current in-tree implementation and tests:
  - [`src/passes/code_pushing.mbt`](/home/jtenner/Projects/starshine-mb-code-pushing/src/passes/code_pushing.mbt)
  - [`src/passes/code_pushing_test.mbt`](/home/jtenner/Projects/starshine-mb-code-pushing/src/passes/code_pushing_test.mbt)
- Saved Binaryen artifact slice:
  - [`.tmp/bin-current-funcs/bin-no-1956.wat`](/home/jtenner/Projects/starshine-mb-code-pushing/.tmp/bin-current-funcs/bin-no-1956.wat)
  - [`.tmp/bin-current-funcs/bin-yes-1956.wat`](/home/jtenner/Projects/starshine-mb-code-pushing/.tmp/bin-current-funcs/bin-yes-1956.wat)

## Reduced Binaryen Probe

Input:

```wat
(module
  (memory 1)
  (func $incref (param i32))
  (func $free (param i32))
  (func $mk (param i32 i32) (result i32)
    i32.const 0)
  (func (param i32 i32) (result i32)
    (local i32 i32 i32 i32 i32 i32)
    local.get 0
    i32.load offset=8
    local.set 3
    local.get 0
    i32.load
    local.tee 5
    i32.const 1
    i32.gt_s
    if
      local.get 5
      i32.const 1
      i32.sub
      local.set 6
      local.get 0
      local.get 6
      i32.store
      local.get 3
      if
        local.get 3
        call $incref
      end
    else
      local.get 5
      i32.const 1
      i32.eq
      if
        local.get 0
        call $free
      end
    end
    local.get 1
    local.set 2
    local.get 1
    i32.load offset=8
    local.set 4
    local.get 1
    i32.load
    local.tee 5
    i32.const 1
    i32.gt_s
    if
      local.get 5
      i32.const 1
      i32.sub
      local.set 6
      local.get 1
      local.get 6
      i32.store
      local.get 4
      if
        local.get 4
        call $incref
      end
    else
      local.get 5
      i32.const 1
      i32.eq
      if
        local.get 1
        call $free
      end
    end
    local.get 2
    local.set 3
    local.get 4
    local.set 5
    local.get 3
    local.get 5
    call $mk))
```

Binaryen `wasm-opt --code-pushing -S` output keeps the first refcount `if`
unchanged, leaves the second kept `local.set 4` before the second `if`, but
moves the alias `local.set 2 (local.get 1)` to immediately after that second
`if`.

## Artifact Corroboration

- The saved current Binaryen artifact slice at body index `1956`
  (absolute function index `1977` after `21` imported funcs) shows the same
  local pattern.
- Binaryen moves:
  - `local.set $45 (local.get $51)`
- from before a later decref-style `if`
- to after that `if`
- while keeping the neighboring `local.set $50 (...)` before the `if` because
  the `if` itself still uses that local.

## Diagnosis

- Starshine's current one-off alias-if-tail fence was broader than the actual
  bad family.
- The kept guard in `cp_push_to_pushpoint_has_high_risk_alias_if_tail` used only
  local root shape:
  - earlier `if`
  - moved alias `local.set(local.get ...)`
  - crossed `local.set`
  - later `if`
  - later alias `local.set`
- That blocked plain safe one-off tails even when no earlier explicit-exit
  carrier fed the alias local at all.
- The older `Func 1977` invalid family came from a narrower source: the moved
  alias was fed by an earlier explicit-exit carried-result block. The tail shape
  alone was not enough.

## Kept Repository Change

- `src/passes/code_pushing.mbt` now narrows
  `cp_push_to_pushpoint_has_high_risk_alias_if_tail` again.
- The one-off alias-if-tail fence now fires only when the moved alias's source
  local is preceded by an earlier risky explicit-exit block carrier in the same
  reachable prefix.
- Plain one-off alias tails without that carrier provenance are now admitted
  again.
- `src/passes/code_pushing_test.mbt` now pins the reduced positive case and also
  validates the lowered output through `pass_test_run_pipeline`.

## Validation

- `moon test src/passes`
- `moon test src/cmd/cmd_test.mbt`
- `bun scripts/pass-fuzz-compare.ts --pass code-pushing --generator gen-valid --count 10000 --max-failures 5 --out-dir .tmp/pass-fuzz-code-pushing-20260412a`
- `bun scripts/pass-fuzz-compare.ts --pass code-pushing --generator wasm-smith --count 1000 --max-failures 5 --out-dir .tmp/pass-fuzz-code-pushing-20260412b`

## Practical Decision

- Do not treat the one-off alias-if-tail shape by itself as the real safety
  boundary.
- Keep fencing the explicit-exit-carrier-fed subset that motivated the old
  `Func 1977` guard.
- Readmit plain one-off alias tails when no risky explicit-exit carrier feeds
  the alias source local.
