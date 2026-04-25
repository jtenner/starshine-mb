---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md
  - ../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md
  - ../../../raw/research/0355-2026-04-25-remove-relaxed-simd-current-main-source-correction.md
  - ../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ../precompute/wat-shapes.md
supersedes:
  - ../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md
---

# `remove-relaxed-simd` WAT and IR shape catalog

This page describes the important shapes transformed by Binaryen's `remove-relaxed-simd` pass.
The examples are schematic WAT: exact block names and formatting may differ, but the semantic shape is source-backed.

## Shape family 1: unary relaxed truncation becomes a trap

Before:

```wat
(func (param $v v128)
  (drop
    (i32x4.relaxed_trunc_f32x4_s
      (local.get $v))))
```

After:

```wat
(func (param $v v128)
  (drop
    (block
      (unreachable))))
```

Also in this family:

- `i32x4.relaxed_trunc_f32x4_u`
- `i32x4.relaxed_trunc_f64x2_s_zero`
- `i32x4.relaxed_trunc_f64x2_u_zero`

Caveat: if the child has effects, the child-effect preservation shape from [Shape family 4](#shape-family-4-side-effecting-children-stay-before-the-trap) applies.

## Shape family 2: binary relaxed operation becomes a trap

Before:

```wat
(func (param $a v128) (param $b v128)
  (drop
    (f32x4.relaxed_min
      (local.get $a)
      (local.get $b))))
```

After:

```wat
(func (param $a v128) (param $b v128)
  (drop
    (block
      (unreachable))))
```

Also in this family:

- `i8x16.relaxed_swizzle`
- `f32x4.relaxed_max`
- `f64x2.relaxed_min`
- `f64x2.relaxed_max`
- `i16x8.relaxed_q15mulr_s`
- `i16x8.dot_i8x16_i7x16_s` in Binaryen source/lit spelling
- `i16x8.relaxed_dot_i8x16_i7x16_s` in current Starshine WAT keyword spelling

## Shape family 3: ternary relaxed operation becomes a trap

Before:

```wat
(func (param $a v128) (param $b v128) (param $c v128)
  (drop
    (f32x4.relaxed_madd
      (local.get $a)
      (local.get $b)
      (local.get $c))))
```

After:

```wat
(func (param $a v128) (param $b v128) (param $c v128)
  (drop
    (block
      (unreachable))))
```

Also in this family:

- `f32x4.relaxed_nmadd`
- `f64x2.relaxed_madd`
- `f64x2.relaxed_nmadd`
- `i8x16.relaxed_laneselect`
- `i16x8.relaxed_laneselect`
- `i32x4.relaxed_laneselect`
- `i64x2.relaxed_laneselect`
- `i32x4.dot_i8x16_i7x16_add_s` in Binaryen source/lit spelling
- `i32x4.relaxed_dot_i8x16_i7x16_add_s` in current Starshine WAT keyword spelling

## Shape family 4: side-effecting children stay before the trap

Before:

```wat
(import "env" "make" (func $make (result v128)))
(func (param $b v128)
  (drop
    (f32x4.relaxed_max
      (call $make)
      (local.get $b))))
```

After, schematically:

```wat
(import "env" "make" (func $make (result v128)))
(func (param $b v128)
  (drop
    (block
      (drop (call $make))
      (unreachable))))
```

Why this matters:

- `call $make` may have side effects;
- the relaxed operation traps only after its operands would have been evaluated;
- Binaryen uses `ChildLocalizer` to keep this order.

The exact localized expression can vary depending on child type, result use, and nested shape.
The invariant is effect preservation before the replacement `unreachable`.

## Shape family 5: typed result contexts remain valid through `unreachable`

Before:

```wat
(func (param $a v128) (param $b v128) (result v128)
  (i8x16.relaxed_swizzle
    (local.get $a)
    (local.get $b)))
```

After, schematically:

```wat
(func (param $a v128) (param $b v128) (result v128)
  (block (result v128)
    (unreachable)))
```

The key is not the exact printed type annotation.
The key is that Binaryen refinalizes after the postwalk so the replacement remains valid in a `v128` context.

## Shape family 6: ordinary SIMD is preserved

Before:

```wat
(func (param $a v128) (param $b v128)
  (drop
    (i8x16.swizzle
      (local.get $a)
      (local.get $b)))
  (drop
    (v128.bitselect
      (local.get $a)
      (local.get $b)
      (local.get $a))))
```

After:

```wat
(func (param $a v128) (param $b v128)
  (drop
    (i8x16.swizzle
      (local.get $a)
      (local.get $b)))
  (drop
    (v128.bitselect
      (local.get $a)
      (local.get $b)
      (local.get $a))))
```

This pass is about relaxed SIMD only.
It is not a generic SIMD cleanup pass.

## Shape family 7: deterministic-SIMD-only functions are semantic no-ops

Before:

```wat
(func (param $a v128) (param $b v128)
  (drop
    (f32x4.min
      (local.get $a)
      (local.get $b))))
```

After:

```wat
(func (param $a v128) (param $b v128)
  (drop
    (f32x4.min
      (local.get $a)
      (local.get $b))))
```

The 2026-04-25 correction matters here: do not describe this as a source-confirmed relaxed-feature gate.
The reviewed Binaryen owner file walks and refinalizes functions; the body is unchanged because no visitor arm matches ordinary SIMD.

## Shape family 8: `precompute` contrast

`precompute` also treats relaxed SIMD specially, but for a different reason.
It avoids folding relaxed SIMD because folding would erase implementation-defined behavior.
`remove-relaxed-simd` goes further and intentionally replaces the relaxed operation with a trap.

So these two are not contradictory:

- `precompute`: preserve relaxed SIMD rather than evaluate it at compile time;
- `remove-relaxed-simd`: remove relaxed SIMD by trapping at each relaxed operation.

## Validation checklist

A complete Starshine port should prove:

- every local relaxed SIMD `Instruction` variant is matched;
- unary, binary, and ternary arities all rewrite;
- side-effecting children are preserved;
- typed `v128` result contexts remain valid;
- ordinary SIMD remains unchanged;
- deterministic-SIMD-only bodies are semantically unchanged;
- binary encode/decode and WAT parsing still agree after rewriting;
- Binaryen dot-product spellings and current Starshine `relaxed_dot` spellings are intentionally aligned or intentionally rejected.

## Sources

- [`../../../raw/binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md`](../../../raw/binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md)
- [`../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md)
- [`../../../raw/research/0355-2026-04-25-remove-relaxed-simd-current-main-source-correction.md`](../../../raw/research/0355-2026-04-25-remove-relaxed-simd-current-main-source-correction.md)
- [`../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md`](../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md)
- Binaryen `RemoveRelaxedSIMD.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveRelaxedSIMD.cpp>
- Binaryen `remove-relaxed-simd.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-relaxed-simd.wast>
