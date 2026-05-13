---
kind: concept
status: supported
last_reviewed: 2026-05-12
sources:
  - ../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md
  - ../../../raw/research/0557-2026-05-12-inlining-wiki-overhaul.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./planning-partial-inlining-and-reruns.md
  - ./starshine-strategy.md
  - ../inlining/wat-shapes.md
---

# `inlining-optimizing` WAT Shapes

These snippets are conceptual. The optimizing variant may simplify the raw inlined shape immediately, so exact printed output can differ from plain `inlining`.

## Shape 1: tiny helper plus cleanup payoff

Before:

```wat
(func $id_plus_zero (param i32) (result i32)
  local.get 0
  i32.const 0
  i32.add)
(func (export "run") (result i32)
  i32.const 7
  call $id_plus_zero)
```

After raw inlining:

```wat
i32.const 7
i32.const 0
i32.add
```

After optimizing suffix, conceptually:

```wat
i32.const 7
```

This cleanup payoff is exactly what plain `inlining` does not promise.

## Shape 2: one-use private helper removed

Before:

```wat
(func $helper (result i32) i32.const 1)
(func (export "run") (result i32) call $helper)
```

After:

```wat
(func (export "run") (result i32) i32.const 1)
;; helper can disappear
```

Current Starshine covers this family.

## Shape 3: root survivor

Before:

```wat
(func $helper (export "helper") (result i32) i32.const 1)
(func (export "run") (result i32) call $helper)
```

After: the direct call can inline, but `$helper` remains exported.

Current Starshine covers exported tiny helpers.

## Shape 4: `ref.func` survivor

```wat
(table 1 funcref)
(elem (i32.const 0) $helper)
(func $helper (result i32) i32.const 1)
(func (export "run") (result i32) call $helper)
```

The direct call may inline, but function identity survives through the table/ref use. Future Starshine work should keep this distinct from no-inline policy.

## Shape 5: `call_ref` expectation mismatch

```wat
(func (export "run") (param funcref i32) (result i32)
  local.get 1
  local.get 0
  call_ref (result i32))
```

Do not use this as a first-slice expected inline. Reviewed `version_129` chosen actions are direct-call based; ref-call logic is mainly repair/survival-adjacent in the living contract.

## Shape 6: tail-call repair gap

```wat
(func $callee (result i32)
  return_call $target)
(func (export "run") (result i32)
  call $callee)
```

Binaryen must repair the nested return-call semantics if it inlines. Current Starshine avoids most return-call-containing callees and only covers a narrow outer direct `return_call` shape.

## Shape 7: partial inlining payoff

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

Binaryen can split the cheap guard from heavy work, inline the cheap helper, then the optimizing suffix may simplify the exposed guard. Current Starshine has no splitter.

## Shape 8: dead exact-unreachable helper frontier

A simplified mismatch-family mental shape:

```wat
(func $run (export "run")
  block unreachable end
  call $a)
(func $a
  block unreachable end
  call $b)
(func $b
  unreachable)
```

Binaryen and Starshine can agree semantically but differ on which private exact-unreachable helper representatives remain after inlining and cleanup. The seed-`0x5eed` artifact is green for the earlier representative frontier, and the broadened seed-`0x1eed` four-function survivor/order frontier is now green too. These were never validation failures, and the latest seed `0x1eed` lane has no Starshine command failures.

## Shape 9: optimizing trace evidence

Focused Starshine tests expect a trace line like:

```text
pass[inlining-optimizing]:nested-cleanup prefix=precompute-propagate touched=N
```

This proves the local pass records the optimizing lane, not that it has exact Binaryen nested scheduler parity.

## Shape 10: untouched function must not be rewritten by the suffix

Before:

```wat
(func $touched (result i32) call $tiny)
(func $untouched (result i32)
  ;; cleanup-looking debris)
```

Binaryen's filtered runner should clean only changed functions. Current Starshine's approximation restores untouched bodies after broad cleanup, but exact touched-function scheduler tests still need to land under `[INL]002`.
