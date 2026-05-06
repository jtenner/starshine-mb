---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-04-27-type-generalizing-primary-source-correction.md
  - ../../../raw/research/0421-2026-04-27-type-generalizing-source-correction-and-port-readiness.md
  - ../../../raw/binaryen/2026-05-05-type-generalizing-current-main-recheck.md
  - ../../../raw/research/0479-2026-05-05-type-generalizing-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-06-type-generalizing-current-main-recheck.md
  - ../../../raw/research/0497-2026-05-06-type-generalizing-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-type-generalizing-primary-sources.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./type-requirements-cfg-and-unsupported-families.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
supersedes:
  - ../../../raw/research/0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md
---

# `type-generalizing` WAT and IR shape catalog

## How to read this page

These shapes are sketches of the source-confirmed Binaryen `experimental-type-generalizing` contract. They do not try to reproduce exact printer output. A 2026-05-06 current-main recheck left the shape families unchanged on the reviewed surfaces. The durable idea is:

- uses impose type requirements;
- the solver propagates requirements backward through a CFG;
- safe locals can get more-general reference types;
- `local.get` and `local.tee` expression result types are repaired after local declaration changes;
- unsupported families are real hazards because upstream marks the pass not yet sound.

## Family 1: unconstrained reference local generalizes toward top

### Before

```wat
(func (local $x (ref null $Child))
  ;; $x is only used where a broader heap type is acceptable
  ...)
```

### After

```wat
(func (local $x anyref)
  ;; uses still type-check with the generalized declaration
  ...)
```

### Why it changes

No use required `$Child` specifically. The backward requirement solver can choose a broader reference type for the non-param local.

## Family 2: function result constrains the local

### Before

```wat
(func (result (ref null $Child))
  (local $x (ref null $Child))
  (local.get $x))
```

### After

```wat
(func (result (ref null $Child))
  (local $x (ref null $Child))
  (local.get $x))
```

### Why it stays

The function exit requires the declared result type. The local feeding that result cannot be generalized past what the return requires.

## Family 3: params stay anchored

### Before

```wat
(func (param $p (ref null $Child))
  (drop (local.get $p)))
```

### After

```wat
(func (param $p (ref null $Child))
  (drop (local.get $p)))
```

### Why it stays

Function parameters are ABI-visible declaration inputs. The pass anchors them to their original types at entry.

## Family 4: `local.set` / `local.get` requirement propagation

### Before

```wat
(func (local $x (ref null $Child))
  (local.set $x (ref.null $Child))
  (drop (local.get $x)))
```

### After

```wat
(func (local $x anyref)
  (local.set $x (ref.null $Child))
  (drop (local.get $x)))
```

### Why it may change

The get is dropped, so it may impose only a broad requirement. The set value must still type-check against the generalized local declaration.

## Family 5: `local.tee` result repair

### Before

```wat
(func (local $x (ref null $Child))
  (drop (local.tee $x (ref.null $Child))))
```

### After

```wat
(func (local $x anyref)
  (drop (local.tee $x (ref.null $Child))))
```

### Why it changes

`local.tee` both writes a local and produces a value. When the local declaration changes, Binaryen updates the tee's expression result type and refinalizes if needed.

## Family 6: direct call constrains argument types

### Before

```wat
(type $takes-child (func (param (ref null $Child))))
(func $callee (type $takes-child) ...)
(func (local $x (ref null $Child))
  (call $callee (local.get $x)))
```

### After

```wat
(type $takes-child (func (param (ref null $Child))))
(func $callee (type $takes-child) ...)
(func (local $x (ref null $Child))
  (call $callee (local.get $x)))
```

### Why it stays

The call parameter requires `(ref null $Child)`, so the local feeding it cannot be generalized beyond that requirement.

## Family 7: `call_ref` is a real constraint surface

### Before

```wat
(call_ref (type $sig)
  (local.get $arg)
  (local.get $target))
```

### After

```wat
(call_ref (type $sig)
  (local.get $arg)
  (local.get $target))
```

### Why it matters

The pass walks function-reference signature requirements for `call_ref`. This is a constraint family, not a direct visible rewrite. The 2026-04-24 claim that `call_ref` was absent is superseded.

## Family 8: global and table requirements

### Before

```wat
(global.set $g (local.get $x))
(table.set $t (i32.const 0) (local.get $f))
```

### After

```wat
(global.set $g (local.get $x))
(table.set $t (i32.const 0) (local.get $f))
```

### Why it may stay or constrain

The global and table declarations impose requirements on values written to them. Those requirements flow back to locals.

## Family 9: struct field read/write constraints

### Before

```wat
(struct.get $S 0 (local.get $obj))
(struct.set $S 0 (local.get $obj) (local.get $value))
```

### After

```wat
(struct.get $S 0 (local.get $obj))
(struct.set $S 0 (local.get $obj) (local.get $value))
```

### Why it matters

Struct operations usually remain printed the same, but they constrain object and field value requirements. They are part of the source-confirmed pass surface.

## Family 10: array constraints

### Before

```wat
(array.get $A (local.get $arr) (i32.const 0))
(array.set $A (local.get $arr) (i32.const 0) (local.get $value))
```

### After

```wat
(array.get $A (local.get $arr) (i32.const 0))
(array.set $A (local.get $arr) (i32.const 0) (local.get $value))
```

### Why it matters

Array element and aggregate requirements flow backward through locals and stack values. Some array atomic/load/store and constructor families are still unsupported hazards.

## Family 11: ref cast/test constraints

### Before

```wat
(ref.test (ref $Child) (local.get $x))
(ref.cast (ref $Child) (local.get $y))
```

### After

```wat
(ref.test (ref $Child) (local.get $x))
(ref.cast (ref $Child) (local.get $y))
```

### Why it matters

These operations constrain operand types. The pass is not primarily a cast insertion/removal pass, but ref operations are part of the requirement model.

## Family 12: unsupported feature bailout

### Before

```wat
;; EH, tuple, string, continuation, atomic GC, or other source-TODO family
...
```

### After

```wat
;; must be skipped, rejected, or left unchanged by a faithful subset
...
```

### Why it stays

Upstream explicitly labels the pass not yet sound and has unsupported-family markers. Starshine should not invent optimistic rewrites for those families or assume a nearby GC/control-flow opcode is covered just because a sibling shape is.

## Positive versus negative cheat sheet

| Shape | Corrected result |
| --- | --- |
| Non-param ref local used only broadly | may generalize local declaration |
| Param local | preserved at original declaration type |
| Local feeding declared function result | constrained by result type |
| Local feeding direct call | constrained by callee parameter type |
| Local feeding `call_ref` | constrained by compatible signature requirements |
| Local feeding global/table/struct/array/ref op | constrained by declaration or operation semantics |
| `local.get` / `local.tee` after local declaration change | retag result type; refinalize if changed |
| EH/tuple/string/continuation/atomic TODO families | unsupported hazard; do not treat as positive |

## What beginners should remember most

1. The pass generalizes local declarations, not heap type declarations.
2. Uses constrain definitions through a backward CFG analysis.
3. `ContentOracle`, `call_ref`, struct, and array surfaces are real.
4. Upstream says the pass is not yet sound, so future ports need narrow guarded slices.
