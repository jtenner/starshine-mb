# DAE Func3737 folded-multivalue nested-cleanup unblock

- Date: 2026-07-12
- Scope: `dae-optimizing` nested cleanup after the large-module guard relaxation from note `1562`
- Status: resolved immediate pass-suite blocker; broader DAE audit remains open

## Problem

After removing the coarse `>100` defined-function nested-cleanup skip, `moon test src/passes` was blocked by one unsafe-looking failure: `dae-optimizing removes selected Func3737 wrapper default from folded multivalue callsite` aborted during nested cleanup.

The traced failure reported:

- `DAE nested cleanup pass remove-unused-brs: func[(Func 281)]: lift: InvalidBodyState(stack underflow)`
- after isolating later passes, the first invalid producer was actually the earlier `merge-blocks` slot

The touched caller collapsed to a shared zero-parameter multivalue block that fed both:

- a rooted result carrier, and
- a sibling `drop` that discarded one returned lane.

`merge-blocks` flattened the rooted copy, emptied the shared block body, and left the drop user pointing at an invalid lowered carrier.

## Reduced repro

A direct `merge-blocks` regression reproduces the problem without DAE:

```wat
(module
  (type $pair (func (result i32 i32)))
  (type $callee (func (param i32 i32 i32) (result i32 i32)))
  (func $target (type $callee) (param i32 i32 i32) (result i32 i32)
    local.get 0
    i32.const 9)
  (func (param i32 i32 i32) (result i32)
    block (type $pair)
      i32.const 0
      local.get 1
      local.get 2
      call $target
    end
    drop))
```

Before the fix, `merge-blocks` rewrote the shared carrier into invalid stack traffic and a second relift failed with `InvalidBodyState(stack underflow)`.

## Fix

`merge_blocks_flatten_region_root_block(...)` now keeps a zero-parameter multivalue root block intact when that same block node is also consumed by a `drop` parent use.

This is intentionally narrower than a blanket shared-node or all-multivalue guard:

- it preserves the direct reduced repro and the DAE Func3737 nested-cleanup case;
- it keeps existing Binaryen-shaped single-parameter/multivalue block and loop lowering paths active;
- it does not reopen the earlier drop-operand prefix-lifting behavior that existing `merge-blocks` tests already cover.

## Test and validation evidence

### Red-first focused repro

- Added `merge-blocks re-lifts multivalue call blocks with trailing drop` in `src/passes/merge_blocks_test.mbt`
- Before the fix: direct `merge-blocks` relift failed with stack underflow
- After the fix: the focused `merge-blocks` repro is green

### DAE unblock

- `moon test src/passes/dae_optimizing_test.mbt --filter '*folded multivalue*'` — green after the merge-blocks fix
- `moon test src/passes/dae_optimizing_test.mbt` — green after refreshing high-defined-function expectations to assert durable post-cleanup semantics instead of pre-cleanup body shapes
- `moon test src/passes` — green

## Remaining scope

This closes the immediate blocker exposed by note `1562`, but it does **not** close the broader `dae-optimizing` audit.

Remaining major gaps still include:

- real public `precompute-propagate` parity / full default-function replay
- broader operand localization
- GC parameter refinement
- result refinement
- remaining selected/artifact-shaped rewrite families and genericization work
