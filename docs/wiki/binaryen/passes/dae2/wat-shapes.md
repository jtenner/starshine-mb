---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-dae2-port-readiness-primary-sources.md
  - ../../../raw/research/0410-2026-04-26-dae2-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-dae2-primary-sources.md
  - ../../../raw/research/0337-2026-04-25-dae2-source-bridge.md
  - ../../../raw/research/0218-2026-04-21-dae2-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./fixed-point-forwarding-type-trees-and-expression-removal.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../dead-argument-elimination/index.md
---

# `dae2` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's experimental `dae2` pass.

## Read this page with one mental model

Binaryen is not asking only:

- “is this parameter read?”

It is asking a more graph-shaped question:

- “is this parameter truly used anywhere, or is it only forwarded into other params that also turn out to be dead?”

That is why some recursive and indirect-call families optimize away more aggressively than plain intuition expects.

## Important note about the examples

The `after` snippets are **conceptual**.
Real Binaryen output may include:

- different type names,
- fresh rec groups,
- replacement types,
- repaired wrappers that preserve effects or control shape.

So use these as rewrite-family illustrations, not literal goldens. The Starshine first-slice validation bridge in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) names which of these shapes should be used for analyzer-only, private direct-call, fixed-point, and referenced type-tree validation.

## Quick glossary

- **forwarded parameter**: an incoming param value that only flows onward into another call, possibly through pure wrapper expressions
- **referenced function**: a function whose identity can be observed, for example through `ref.func`, imports, exports, or related roots
- **root function-type tree**: the declared-supertype root used to group indirect/reference-call optimization facts
- **replacement type**: a temporary alternate function type used so global type rewriting does not optimize the wrong unreferenced sibling

## Shape 1: trivially unused direct-call parameter disappears

Before:

```wat
(func $f (param $unused i32)
  (nop))
```

After, conceptually:

```wat
(func $f
  (local $unused i32)
  (nop))
```

Why it rewrites:

- the incoming boundary value is never semantically used,
- there is no forwarding reason to keep it,
- so `dae2` drops the param and turns the old slot into an ordinary local if needed.

## Shape 2: recursive forwarding cycle can still disappear

Before:

```wat
(func $f (param $x i32)
  (call $f
    (local.get $x)))
```

After, conceptually:

```wat
(func $f
  (local $x i32)
  (call $f))
```

Why it rewrites:

- the param is only forwarded around a cycle,
- nothing outside the cycle gives it a real use,
- so the backward fixed point leaves it unused.

## Shape 3: mutual recursion can optimize the same way

Before, conceptually:

```wat
(func $a (param $x i32)
  (call $b (local.get $x)))
(func $b (param $y i32)
  (call $a (local.get $y)))
```

After, conceptually:

```wat
(func $a
  (local $x i32)
  (call $b))
(func $b
  (local $y i32)
  (call $a))
```

Why it rewrites:

- the whole cycle is only forwarding,
- so all the relevant params stay dead together.

## Shape 4: if any value in the cycle is used elsewhere, the chain stays live

Before, conceptually:

```wat
(func $a (param $x i32)
  (call $b (local.get $x)))
(func $b (param $y i32)
  (call $a (local.get $y))
  (global.set $g (local.get $y)))
```

After:

```wat
;; preserved in the relevant parameter positions
```

Why it stays:

- the global write is a real use seed,
- so the fixed point propagates “used” backward through the whole forwarding cycle.

## Shape 5: caller may still need its own param even when callee loses the forwarded copy

Before, conceptually:

```wat
(func $caller (param $used i32)
  (global.set $g (local.get $used))
  (call $callee (local.get $used)))

(func $callee (param $unused i32)
  (nop))
```

After, conceptually:

```wat
(func $caller (param $used i32)
  (global.set $g (local.get $used))
  (call $callee))

(func $callee
  (local $unused i32)
  (nop))
```

Why it rewrites this way:

- the caller still uses its boundary value,
- but the callee's copy is only a dead forwarded argument.

## Shape 6: `call_ref` can lose dead operands in referenced-function mode

Before, conceptually:

```wat
(type $f (func (param i32 i32)))
(func $target (type $f) (param $used i32) (param $unused i32)
  (global.set $g (local.get $used)))
(func $caller (param $x i32)
  (call_ref $f
    (local.get $x)
    (i32.const 0)
    (ref.func $target)))
```

After, conceptually:

```wat
(type $f' (func (param i32)))
(func $target (type $f') (param $used i32)
  (global.set $g (local.get $used)))
(func $caller (param $x i32)
  (call_ref $f'
    (local.get $x)
    (ref.func $target)))
```

Why it rewrites:

- the dead second param is proven unused across the relevant referenced type tree,
- Binaryen is allowed to optimize referenced functions,
- so both the signature surface and the call_ref operand list can shrink.

## Shape 7: public or otherwise unrewritable type trees block those wins

Before, conceptually:

```wat
(type $public (func (param i32)))
(elem declare func $referenced)
(func $referenced (type $public) (param $unused i32)
  ...)
```

After:

```wat
;; preserved for the type-tree rewrite surface
```

Why it stays:

- public and related unrewritable roots are conservative boundaries,
- so `dae2` does not globally rewrite that function-type tree here.

## Shape 8: `ref.func` makes a function referenced

Before:

```wat
(func $f (param $unused i32)
  (nop))
(func $g
  (drop (ref.func $f)))
```

After, conceptually:

```wat
;; treated as a referenced-function case, not an ordinary private direct-call case
```

Why this matters:

- the function's identity escapes,
- so `dae2` cannot reason about it like a purely private direct-call target anymore.

## Shape 9: `if` condition input is always a real use

Before:

```wat
(func $test (param $used i32)
  (if
    (local.get $used)
    (then (nop))
    (else (nop))))
```

After:

```wat
;; preserved
```

Why it stays:

- even if the arms look simple,
- changing the condition could change which arm executes,
- so the condition value is never treated as mere forwarding.

## Shape 10: pure wrapper forwarding may disappear with the dead param

Before, conceptually:

```wat
(call $callee
  (i32.add
    (local.get $unused)
    (i32.const 1)))
```

After, conceptually:

```wat
(call $callee)
```

Why it can rewrite:

- the wrapper is only helping forward the dead value,
- and it is pure enough that removing it does not change visible effects.

## Shape 11: effectful wrappers must be preserved carefully

Before, conceptually:

```wat
(drop
  (block (result i32)
    (call_indirect (type $f)
      (local.get $unused)
      (call $effect))
    (local.get $unused)))
```

After, conceptually:

```wat
(drop
  (block (result i32)
    (block
      (call_indirect (type $f)
        (call $effect)))
    ...))
```

Why this matters:

- the dead parameter traffic can disappear,
- but the effectful subexpressions must not be duplicated or dropped.

The shipped regressions make this family very explicit.

## Shape 12: loops may stay even when the forwarded value is dead

Before, conceptually:

```wat
(drop
  (loop $l (result i32)
    (drop (call $effect))
    (drop (local.get $unused))
    ...))
```

After, conceptually:

```wat
(drop
  (loop $l (result i32)
    (drop (call $effect))
    ...))
```

Why it rewrites this way:

- the dead param use disappears,
- but the loop itself still controls effect repetition and must stay.

## Shape 13: tuple extraction is conservatively treated as a real use today

Before:

```wat
(global.set $g
  (tuple.extract 2 1
    (tuple.make 2
      (local.get $x)
      (i32.const 1))))
```

After:

```wat
;; preserved as a use today
```

Why it stays:

- `dae2` is not yet precise about which tuple elements are truly consumed,
- so the safe answer is to keep the parameter live.

## Shape 14: imported / intrinsic / JS-called surfaces stay conservative

Before, conceptually:

```wat
(import "binaryen-intrinsics" "call.without.effects"
  (func $call.without.effects ...))
```

After:

```wat
;; referenced/intrinsic-related params preserved
```

Why it stays:

- the source explicitly says `call.without.effects` is not fully handled yet,
- and JS-called surfaces are also marked live conservatively.

## Shape 15: replacement types let unreferenced siblings optimize independently

Before, conceptually:

```wat
(type $shared (func (param i32 i64)))
(func $referenced (type $shared) (param $used i32) (param $unused i64) ...)
(func $unreferenced (type $shared) (param $used i32) (param $unused i64) ...)
```

After, conceptually:

```wat
(type $shared' (func (param i32 i64))) ;; referenced side still tied to public/rewritable story
(type $replacement (func (param i32))) ;; unreferenced side placeholder or reused equivalent
(func $unreferenced (type $replacement) (param $used i32) ...)
```

Why this matters:

- otherwise the later global type rewrite could optimize the wrong function to the wrong signature.

## Shape 16: `dae2` does not yet remove dead results like plain `dae` can

Before, conceptually:

```wat
(func $f (result i32)
  (i32.const 0))
(func $g
  (drop (call $f)))
```

After:

```wat
;; result traffic remains outside current `dae2` scope
```

Why it stays:

- the file header explicitly says result optimization is future work.

## Fast checklist for reading a candidate shape

When you see a possible `dae2` opportunity, ask:

1. Is the param truly used, or only forwarded?
2. If forwarded, is the path direct or indirect/reference-based?
3. Does the reverse graph get seeded by a real downstream use?
4. Is the function or type tree referenced/public/unrewritable?
5. Would removing the value cross an `if` condition or effectful parent?
6. Is this actually a result/constant/type-propagation idea that `dae2` does not do yet?
7. If referenced functions are involved, is a replacement type needed for any unreferenced sibling?

## Bottom line

The most important beginner correction is:

> `dae2` is not a plain delete-unused-params pass. It is a backward forwarding-graph optimizer with optional referenced function-type-tree rewriting, and its visible rewrites are shaped just as much by blocker boundaries and effect-preserving expression removal as by the final dead-param result.

## Sources

- Raw source manifest: [`../../../raw/binaryen/2026-04-25-dae2-primary-sources.md`](../../../raw/binaryen/2026-04-25-dae2-primary-sources.md)
- Source bridge: [`../../../raw/research/0337-2026-04-25-dae2-source-bridge.md`](../../../raw/research/0337-2026-04-25-dae2-source-bridge.md)
- Original research note: [`../../../raw/research/0218-2026-04-21-dae2-binaryen-research.md`](../../../raw/research/0218-2026-04-21-dae2-binaryen-research.md)
- Binaryen `dae2.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae2.wast>
- Starshine status bridge: [`./starshine-strategy.md`](./starshine-strategy.md)
