---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ../../../raw/research/1572-2026-07-18-pick-load-signs-version-131-behavior-audit.md
  - ../../../../../src/passes/pick_load_signs.mbt
  - ../../../../../src/passes/pick_load_signs_test.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/PickLoadSigns.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/properties.h
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
---

# `pick-load-signs` WAT shapes

## Upstream-common signed extension

```wat
(local.set $x (i32.load8_u (i32.const 0)))
(i32.extend8_s (local.get $x))
```

Binaryen and Starshine change the load to `i32.load8_s`. Direct PLS preserves the i32 extension shape.

## Upstream-common unsigned mask

```wat
(local.set $x (i32.load8_s (i32.const 0)))
(i32.and (local.get $x) (i32.const 255))
```

Binaryen and Starshine change the load to `i32.load8_u`. Binaryen v131 requires the value on the left and mask on the right.

## Upstream-common signed shift pair

```wat
(local.set $x (i32.load16_u (i32.const 0)))
(i32.shr_s
  (i32.shl (local.get $x) (i32.const 16))
  (i32.const 16))
```

Both implementations select `i32.load16_s`.

## Retained Starshine win: commuted i32 mask

```wat
(local.set $x (i32.load8_s (i32.const 0)))
(i32.and (i32.const 255) (local.get $x))
```

Binaryen PLS leaves this unchanged. Starshine selects `i32.load8_u` and removes the now-redundant mask, producing `48` versus `52` canonical bytes in the load8 probe.

## Retained Starshine win: unsigned shift pair

```wat
(local.set $x (i32.load16_s (i32.const 0)))
(i32.shr_u
  (i32.shl (local.get $x) (i32.const 16))
  (i32.const 16))
```

Starshine selects `i32.load16_u` and replaces the shift pair with `local.get`. The previous size loss is resolved: widths 8 and 16 now produce `48` versus Binaryen's `54` canonical bytes.

The same rule covers i64 load widths 8, 16, and 32.

## Retained Starshine win: i64 direct signed extension

```wat
(local.set $x (i64.load32_u (i32.const 0)))
(i64.extend32_s (local.get $x))
```

Starshine selects `i64.load32_s` and removes `i64.extend32_s`, producing `48` versus Binaryen's `49` canonical bytes. Widths 8 and 16 follow the same rule.

## Retained Starshine win: i64 mask

```wat
(local.set $x (i64.load16_s (i32.const 0)))
(i64.and (local.get $x) (i64.const 65535))
```

Starshine selects `i64.load16_u` and removes the mask. Widths 8/16/32 produce `48` bytes versus Binaryen's `52/53/55`.

## Retained Starshine win: i64 signed shift

```wat
(local.set $x (i64.load32_u (i32.const 0)))
(i64.shr_s
  (i64.shl (local.get $x) (i64.const 32))
  (i64.const 32))
```

Starshine selects `i64.load32_s` and removes the shift pair. Signed and unsigned i64 shift families at all three widths produce `48` versus Binaryen's `54` canonical bytes.

## Why evidence deletion is safe

Starshine removes a retained evidence expression only when:

- the local is not a parameter;
- every explicit write is a matching candidate load;
- every candidate has the same required width and final signedness;
- at least one load actually changes signedness.

Otherwise PLS preserves the expression. This includes parameter-entry values and arbitrary non-load writes.

## Bailout: unknown use

```wat
(local.set $x (i32.load8_u (i32.const 0)))
(i32.eq (local.get $x) (i32.const 1))
```

The equality use is not extension evidence, so the load remains unchanged.

## Bailout: mixed evidence widths

```wat
(local.set $x (i32.load8_u (i32.const 0)))
(i32.extend8_s (local.get $x))
(i32.extend16_s (local.get $x))
```

Conflicting widths invalidate the local.

## Bailout: load/use width mismatch

```wat
(local.set $x (i32.load16_u (i32.const 0)))
(i32.extend8_s (local.get $x))
```

The evidence width does not match the candidate load width.

## Bailout: `local.tee`, atomic, and no-use producers

PLS excludes `local.tee` producers and atomic loads. A candidate with no informative reads also stays unchanged.

## Runtime evidence

The final negative-boundary runtime matrix covers every retained width/family. Binaryen and Starshine results matched for signed minima and unsigned high-bit values, including `-128`, `-32768`, `-2147483648`, `128`, `32768`, and `2147483648`.
