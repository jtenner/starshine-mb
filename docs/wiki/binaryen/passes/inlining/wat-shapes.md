---
kind: concept
status: supported
last_reviewed: 2026-05-12
sources:
  - ../../../raw/binaryen/2026-04-26-inlining-current-main-port-readiness.md
  - ../../../raw/binaryen/2026-04-23-inlining-primary-sources.md
  - ../../../raw/research/0557-2026-05-12-inlining-wiki-overhaul.md
  - ../../../raw/research/0161-2026-04-21-inlining-binaryen-research.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./heuristics-splitting-and-plain-vs-optimizing.md
  - ./starshine-strategy.md
  - ../inlining-optimizing/wat-shapes.md
---

# `inlining` WAT Shapes

The examples below are conceptual. Binaryen may print wrapper blocks, fresh locals, drops, label scaffolding, or post-repair type forms. Plain `inlining` deliberately leaves more debris than `inlining-optimizing`.

## Shape 1: tiny no-param helper disappears

Before:

```wat
(func $tiny (result i32)
  i32.const 7)
(func (export "run") (result i32)
  call $tiny)
```

After plain inlining, conceptually:

```wat
(func (export "run") (result i32)
  (block (result i32)
    i32.const 7))
;; $tiny can be removed if no roots/refs remain
```

Current Starshine covers this family and removes the private helper.

## Shape 2: parameters are stored into fresh locals

Before:

```wat
(func $add1 (param i32) (result i32)
  local.get 0
  i32.const 1
  i32.add)
(func (export "run") (param i32) (result i32)
  local.get 0
  call $add1)
```

Conceptual replacement:

```wat
(func (export "run") (param i32) (result i32)
  (local $inl_x i32)
  local.get 0
  local.set $inl_x
  (block (result i32)
    local.get $inl_x
    i32.const 1
    i32.add))
```

The invariant is operand order and a distinct callee-frame local, not exact printed names.

## Shape 3: exported helper can inline but survive

Before:

```wat
(func $tiny (export "tiny") (result i32)
  i32.const 11)
(func (export "run") (result i32)
  call $tiny)
```

After:

```wat
(func $tiny (export "tiny") (result i32)
  i32.const 11)
(func (export "run") (result i32)
  i32.const 11) ;; conceptually, wrapper debris may remain
```

Current Starshine covers this root-survivor family.

## Shape 4: `ref.func` / table use keeps the boundary alive

Before:

```wat
(table 1 funcref)
(elem (i32.const 0) $helper)
(func $helper (result i32) i32.const 1)
(func (export "run") (result i32) call $helper)
```

After the direct call may inline, but `$helper` remains because function-reference use still observes its identity.

## Shape 5: self-recursive call is skipped

```wat
(func $loop (export "run") (result i32)
  call $loop)
```

Inlining this into itself grows without progress. Binaryen and current Starshine skip it.

## Shape 6: simple `return` in copied callee becomes branch out of the wrapper

Before:

```wat
(func $callee (param $x i32) (result i32)
  local.get $x
  if
    i32.const 1
    return
  end
  i32.const 2)
(func (export "run") (param i32) (result i32)
  local.get 0
  call $callee)
```

Conceptual after:

```wat
(block (result i32)
  ;; copied condition
  if
    i32.const 1
    br 0
  end
  i32.const 2)
```

Current Starshine has a simple return-to-wrapper-branch path, but complex label-depth, nested returns, and multi-result typing remain gaps.

## Shape 7: outer `return_call` can inline in the current subset

Before:

```wat
(func $tiny (result i32) i32.const 7)
(func (export "run") (result i32)
  return_call $tiny)
```

Conceptual after:

```wat
(func (export "run") (result i32)
  i32.const 7
  return)
```

Current Starshine covers a narrow direct `return_call` positive. It does **not** yet cover full Binaryen nested `return_call*` repair.

## Shape 8: nested `return_call*` repair is a gap

Before:

```wat
(func $callee (result i32)
  return_call $target)
(func (export "run") (result i32)
  call $callee)
```

Binaryen must not let the copied `return_call` return from `$run` unless the outer callsite was already a return-style call. It can downgrade/repair and wrap control. Current Starshine mostly avoids return-call-containing callees, so this remains a parity gap.

## Shape 9: unreachable/trap reachability is preserved

Before:

```wat
(func $trap (result i32)
  unreachable)
(func (export "run") (result i32)
  call $trap)
```

After must still trap/unreach. Typed wrapper blocks must not accidentally create reachable values. Current Starshine has additional exact-`unreachable` survivor prediction work because Binaryen and Starshine differ in which private helper representatives survive after cleanup.

## Shape 10: Pattern A partial inlining

Before:

```wat
(func $maybe (param $x i32)
  (if (local.get $x)
    (then (return)))
  call $heavy)
(func (export "run") (param i32)
  local.get 0
  call $maybe)
```

Binaryen can outline the heavy suffix and inline only the guard wrapper. Current Starshine does not implement partial splitting.

## Shape 11: Pattern B local-dependency bailout

Before:

```wat
(func $bad (param $x i32) (result i32)
  (local $tmp i32)
  (if (local.get $x)
    (then
      i32.const 1
      local.set $tmp))
  local.get $tmp)
```

Pattern B must not split this because the final item reads a local written by a guarded body.

## Shape 12: complex guard blocks partial inlining

```wat
(func $bad (param $x i32)
  (if (call $expensive-condition (local.get $x))
    (then (return)))
  call $heavy)
```

A call condition is not simple under the reviewed splitter rules.

## Shape 13: nondefaultable local repair

Before:

```wat
(func $callee
  (local $r (ref $T))
  ;; copied body may mention $r)
```

Binaryen cannot invent a fake default for nondefaultable locals. It adds locals and then runs nondefaultable-local repair. Current Starshine does not yet model the full repair surface.

## Shape 14: plain pass leaves debris

Before:

```wat
(func $id_plus_zero (param i32) (result i32)
  local.get 0
  i32.const 0
  i32.add)
```

After plain `inlining`, `i32.add 0`, local traffic, and wrapper blocks may remain. If those disappear, check whether you accidentally ran `inlining-optimizing` or a later cleanup pass.

## Shape 15: current mismatch family is helper retention, not validation failure

The older direct optimizing mismatch frontier here is retired. The exact-`unreachable` private-helper representative/retention families that once dominated `[INL]001` are now green on the current direct optimizing seed lanes. Treat any new failures in this area as fresh regressions or as work for the deferred direct-inliner breadth slices, not as parser or validator failures.
