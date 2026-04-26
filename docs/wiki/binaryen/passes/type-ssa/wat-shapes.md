---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-type-ssa-port-readiness-primary-sources.md
  - ../../../raw/research/0409-2026-04-26-type-ssa-port-readiness.md
  - ../../../raw/binaryen/2026-04-26-type-ssa-source-correction-and-current-main.md
  - ../../../raw/research/0386-2026-04-26-type-ssa-source-correction.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./created-exact-types-control-values-and-signature-rewrites.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `type-ssa` WAT and IR shape catalog

## How to read this page

These sketches are conceptual. Binaryen's exact printer output may differ, but the important visible changes are:

- new private subtypes appear in the type section,
- selected allocation instructions are retagged to exact non-null refs to those fresh subtypes,
- parent expression types are refinalized.

This page intentionally replaces the older stale local-flow examples. For the future Starshine test order that turns these families into analyzer and Binaryen-oracle lanes, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Family 1: interesting `struct.new` gets a fresh subtype

### Before

```wat
(type $A (struct (field i32)))
(func $make (result (ref $A))
  (struct.new $A
    (i32.const 1)))
```

### After, conceptually

```wat
(type $A (struct (field i32)))
(type $A.0 (sub $A (struct (field i32))))
(func $make (result (ref $A))
  (struct.new $A.0
    (i32.const 1))) ;; result type is exact non-null $A.0, then accepted as $A
```

### Why it changes

The allocation is reachable, the original type can be safely split, and the constant field makes the fresh type useful to later passes.

## Family 2: default constructor is interesting

### Before

```wat
(type $A (struct (field (mut i32))))
(func $make (result (ref $A))
  (struct.new_default $A))
```

### After, conceptually

```wat
(type $A.0 (sub $A (struct (field (mut i32)))))
(func $make (result (ref $A))
  (struct.new_default $A.0))
```

### Why it changes

Binaryen treats default construction as an interesting allocation family for this pass.

## Family 3: refined operand type can make an allocation interesting

### Before

```wat
(type $Parent (struct))
(type $Child (sub $Parent (struct)))
(type $Box (struct (field (ref null $Parent))))
(func $box (param $x (ref $Child)) (result (ref $Box))
  (struct.new $Box
    (local.get $x)))
```

### After, conceptually

```wat
(type $Box.0 (sub $Box (struct (field (ref null $Parent)))))
(func $box (param $x (ref $Child)) (result (ref $Box))
  (struct.new $Box.0
    (local.get $x)))
```

### Why it changes

The field's declared type is broad, but the actual operand is more refined. A fresh subtype can preserve that allocation-site fact for later type-aware passes.

## Family 4: `array.new_data` and `array.new_elem` are positive allocation families

### Before

```wat
(type $Bytes (array (mut i8)))
(func $make (result (ref $Bytes))
  (array.new_data $Bytes $data
    (i32.const 0)
    (i32.const 8)))
```

### After, conceptually

```wat
(type $Bytes.0 (sub $Bytes (array (mut i8))))
(func $make (result (ref $Bytes))
  (array.new_data $Bytes.0 $data
    (i32.const 0)
    (i32.const 8)))
```

### Why it changes

Data/element-backed array allocation carries useful allocation-site content information.

## Family 5: all-interesting `array.new_fixed`

### Before

```wat
(type $Arr (array (mut i32)))
(func $make (result (ref $Arr))
  (array.new_fixed $Arr 2
    (i32.const 1)
    (i32.const 2)))
```

### After, conceptually

```wat
(type $Arr.0 (sub $Arr (array (mut i32))))
(func $make (result (ref $Arr))
  (array.new_fixed $Arr.0 2
    (i32.const 1)
    (i32.const 2)))
```

### Why it changes

For fixed arrays, the source-backed rule is stricter: all elements must be interesting.

## Family 6: exact-observed type bails out

### Before

```wat
(type $A (struct))
(func $make (result (ref $A))
  (struct.new $A))
(func $check (param $x anyref) (result i32)
  (ref.test (ref exact $A)
    (local.get $x)))
```

### After

```wat
;; preserved: no fresh subtype for $A allocation
```

### Why it stays

Exact tests and exact casts can observe exact heap identity. Binaryen records such types as disallowed for splitting.

## Family 7: final or non-open type bails out

### Before

```wat
(type $A (sub final (struct)))
(func $make (result (ref $A))
  (struct.new $A))
```

### After

```wat
;; preserved: final type cannot receive a subtype
```

### Why it stays

A fresh subtype would violate the final/non-open type contract.

## Family 8: descriptor/describee families bail out

### Before

```wat
;; conceptual GC descriptor/describee allocation family
(struct.new $DescriptorOrDescribed ...)
```

### After

```wat
;; preserved
```

### Why it stays

The owner file explicitly avoids descriptor/describee heap-type families. Descriptor support is called out as future work rather than current behavior.

## Family 9: uninteresting allocation stays broad

### Before

```wat
(type $Box (struct (field (ref null $Parent))))
(func $box (param $x (ref null $Parent)) (result (ref $Box))
  (struct.new $Box
    (local.get $x)))
```

### After

```wat
;; preserved broad allocation type
```

### Why it stays

If the operand is no more precise than the declared field type and no other interestingness rule applies, a fresh subtype is not useful.

## Family 10: stale local-flow examples are non-goals

These older examples should no longer be used as `type-ssa` predictions:

```wat
(local.set $x (struct.new $A ...))
(drop (local.get $x)) ;; not the main visible rewrite surface
```

```wat
(call $use (local.get $x)) ;; not direct call-operand retagging from a map
```

The corrected pass may still affect parent types indirectly after allocation retagging and refinalization, but the source-backed transformation begins at allocation instructions and fresh heap types.
