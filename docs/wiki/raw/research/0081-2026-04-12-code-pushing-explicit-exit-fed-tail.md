# 0081 - Code-Pushing Explicit-Exit-Fed Alias Tail Readmission

## Scope

- Recheck whether the remaining explicit-exit-fed alias-if-tail fence still
  matches Binaryen's actual `code-pushing` surface.
- Reduce a case where an earlier explicit-exit carrier feeds the moved alias,
  but the later alias / decref ladder is still the ordinary Binaryen reorder.
- Compare that against the current Starshine guard in
  `cp_push_to_pushpoint_has_high_risk_alias_if_tail`.

## Primary Sources

- Existing project study:
  [`docs/0073-2026-04-02-code-pushing-binaryen-plan.md`](../../../0073-2026-04-02-code-pushing-binaryen-plan.md)
- Existing frontier pages:
  - [`docs/wiki/binaryen/passes/code-pushing/artifact-frontiers.md`](../../binaryen/passes/code-pushing/artifact-frontiers.md)
  - [`docs/wiki/binaryen/passes/code-pushing/parity.md`](../../binaryen/passes/code-pushing/parity.md)
  - [`docs/wiki/binaryen/passes/code-pushing/starshine-hot-ir-strategy.md`](../../binaryen/passes/code-pushing/starshine-hot-ir-strategy.md)
- Current implementation and tests:
  - [`src/passes/code_pushing.mbt`](/home/jtenner/Projects/starshine-mb-code-pushing/src/passes/code_pushing.mbt)
  - [`src/passes/code_pushing_test.mbt`](/home/jtenner/Projects/starshine-mb-code-pushing/src/passes/code_pushing_test.mbt)

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
    (local i32 i32 i32 i32 i32 i32 i32)
    (local.set 7
      (block $carrier (result i32)
        (block $work
          (if (local.get 0)
            (then
              (br $work)))
          (br $carrier (local.get 1))
          unreachable)
        (local.get 1)))
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

Binaryen `wasm-opt --code-pushing -S` output keeps the earlier explicit-exit
carrier in place, keeps the loaded condition-set `local.set 4 (...)` before the
later decref `if`, but still moves the alias `local.set 2 (local.get 1)` to
immediately after that later `if`.

## Artifact Corroboration

- The current Binaryen debug-artifact slice for `Func 1977` now shows the same
  thing directly.
- In the later `TypeMetadata.new.inner` ladder, Binaryen moves:
  - `local.set $45 (local.get $51)`
- from before the later decref-style `if`
- to immediately after that `if`
- while still keeping the neighboring loaded condition-set `local.set $50 (...)`
  before the `if` and still rebuilding the paired later locals / call.
- Binaryen also performs the same move in earlier store-only sub-ladders in that
  same function.

## Diagnosis

- Starshine's remaining explicit-exit-fed alias-if-tail fence was still too
  broad.
- The old `cp_push_to_pushpoint_has_high_risk_alias_if_tail` guard still blocked
  a moved alias whenever all of these local root-shape facts held:
  - earlier `if`
  - moved alias `local.set(local.get source_local)`
  - crossed `local.set`
  - later `if`
  - later alias `local.set`
  - earlier explicit-exit carrier feeding that same source local
- That shape was once a useful fail-closed approximation, but the reduced probe
  above plus the current Binaryen `Func 1977` artifact slice show it is not the
  real remaining boundary anymore.
- The narrower same-source crossed-condition-set guard already covers the real
  aliasing hazard that still needs to stay blocked.

## Kept Repository Change

- `src/passes/code_pushing.mbt` no longer rejects pushpoint rewrites through
  `cp_push_to_pushpoint_has_high_risk_alias_if_tail`.
- `src/passes/code_pushing_test.mbt` now pins a reduced positive explicit-exit-
  fed repeated-ladder regression where the moved alias still feeds the later
  reconstruction after the decref `if`.
- `src/cmd/cmd_test.mbt` now raises the native debug-artifact contract too:
  traced replay should show `Func 1977` rewritten rather than merely "not
  skipped".

## Validation

- `moon info`
- `moon test src/passes`
- `moon test src/cmd/cmd_test.mbt`
- `bun scripts/pass-fuzz-compare.ts --pass code-pushing --generator gen-valid --count 10000 --max-failures 5 --out-dir .tmp/pass-fuzz-code-pushing-20260412e`
- `bun scripts/pass-fuzz-compare.ts --pass code-pushing --generator wasm-smith --count 1000 --max-failures 5 --out-dir .tmp/pass-fuzz-code-pushing-20260412f`

## Practical Decision

- Do not keep a dedicated explicit-exit-fed alias-if-tail fence anymore just
  because the moved alias crosses a kept loaded condition-set and later decref
  `if`.
- Keep the narrower same-source crossed-condition-set guard and the existing
  lowering-validity checks instead.
- Treat the next remaining `code-pushing` work as the broader whole-artifact /
  runtime gap after this reopened `Func 1977` parity surface, not as another
  reason to preserve the old tail-specific fence.
