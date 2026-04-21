---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0172-2026-04-21-avoid-reinterprets-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AvoidReinterprets.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets64.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./single-load-chains-and-bailouts.md
---

# WAT shape catalog for `avoid-reinterprets`

## Reading this page correctly

This pass is shape-driven, but the shapes are narrower than the name suggests.
It rewrites only reinterpret users that still provably come from one full-width load.

Read every example below as:

- what Binaryen directly rewrites,
- what Binaryen directly preserves,
- and what a faithful port must not overgeneralize.

## Shape 1: direct full-width load flip

**Pattern:**

```wat
(f32.reinterpret_i32 (i32.load (i32.const 1024)))
```

**What Binaryen does:**

```wat
(f32.load (i32.const 1024))
```

The same family also exists for:

- `i32.reinterpret_f32 (f32.load ...)`
- `f64.reinterpret_i64 (i64.load ...)`
- `i64.reinterpret_f64 (f64.load ...)`

## Shape 2: one indirect reinterpret user through a local

**Pattern:**

```wat
(local.set $x (i32.load (i32.const 1024)))
(drop (f32.reinterpret_i32 (local.get $x)))
```

**Rewritten idea:**

```wat
(local.set $x
  (block (result i32)
    (local.set $ptr (i32.const 1024))
    (local.set $alt (f32.load (local.get $ptr)))
    (i32.load (local.get $ptr))))
(drop (local.get $alt))
```

The exact helper-local names vary, but the structure does not:

- save pointer once
- compute alternate typed load once
- still produce original load result
- replace the reinterpreting user with the helper local

## Shape 3: multiple reinterpret users share the helper local

**Pattern:**

```wat
(local.set $x (i32.load (i32.const 1024)))
(drop (f32.reinterpret_i32 (local.get $x)))
(drop (f32.reinterpret_i32 (local.get $x)))
```

**What Binaryen does:**

- one duplicated `f32.load` is created at the source load site
- both reinterpret users become `local.get $alt`

This is a real sharing rule.

## Shape 4: mixed original and reinterpret users keep both views alive

**Pattern:**

```wat
(local.set $x (i32.load (i32.const 1024)))
(drop (local.get $x))
(drop (f32.reinterpret_i32 (local.get $x)))
```

**What Binaryen does:**

- ordinary `local.get $x` still reads the original `i32.load`
- reinterpreting users switch to the alternate typed helper local

So the pass duplicates the load instead of retargeting the original local graph.

## Shape 5: copy chains can still succeed

**Pattern:**

```wat
(local.set $x (i32.load (i32.const 1024)))
(local.set $y (local.get $x))
(drop (f32.reinterpret_i32 (local.get $y)))
```

**What Binaryen does:**

- still rewrites successfully

because the pass can follow:

- `y -> x -> load`

through a unique single-set chain.

## Shape 6: direct partial-load reinterpret is a no-op

**Pattern:**

```wat
(f32.reinterpret_i32 (i32.load16_u (i32.const 3)))
```

**What Binaryen does:**

- leaves it unchanged

Likewise for:

```wat
(f32.reinterpret_i32 (i32.load8_u (i32.const 3)))
```

Why:

- partial loads are not full-width, so the eligibility test fails.

## Shape 7: params or merged values are bailout shapes

**Pattern idea:**

```wat
(drop (f32.reinterpret_i32 (local.get $p)))
```

or a `local.get` whose value can come from multiple `local.set`s.

**What Binaryen does:**

- leaves the reinterpret in place

because the pass cannot prove one unique source load.

## Shape 8: wrapper transparency is narrow, not magical

**Positive idea:**

A transparent fallthrough wrapper around the source local chain may still optimize.

**Negative idea:**

A non-fallthrough wrapper does not.

The explicit lit example is the named block barrier:

```wat
(drop
  (f32.reinterpret_i32
    (block $a-name-avoids-fallthrough (result i32)
      (nop)
      (local.get $x))))
```

**What Binaryen does:**

- leaves the reinterpret form unchanged

This is one of the easiest shapes to get wrong in a port.

## Shape 9: memory64 uses `i64` pointer temps

**Pattern:**

```wat
(memory i64 1)
(local.set $x (i32.load (i64.const 1024)))
(drop (f32.reinterpret_i32 (local.get $x)))
```

**What Binaryen does:**

- same logical rewrite as memory32
- but the helper pointer local is `i64`, not `i32`

The dedicated `avoid-reinterprets64.wast` file exists to lock that down.

## Shape 10: unreachable or unsupported load families stay put

**Patterns:**

- unreachable full-width load
- non-load origin behind a local
- cyclic unreachable-code copy chain

**What Binaryen does:**

- bails out and keeps the original shape

## Positive / negative / bailout summary table

| Family | Result |
| --- | --- |
| direct full-width reinterpret(load) | direct load-type flip |
| one indirect reinterpret user | helper-local duplication rewrite |
| many indirect reinterpret users | shared helper-local rewrite |
| mixed original + reinterpret users | preserve both views |
| copy chain with unique source load | optimize |
| partial loads | no-op |
| params / entry values | no-op |
| merged local origins | no-op |
| non-fallthrough wrappers | no-op |
| memory64 pointer temp | same logic, `i64` temp |
| unreachable/cyclic unsupported origins | no-op |

## What a future Starshine port must preserve

- direct-load flip versus indirect-user helper-local split
- one-helper-local sharing for many reinterpret users
- mixed-use preservation
- partial-load non-rewrites
- wrapper and merge bailouts
- memory32/memory64 pointer-temp typing

## Sources

- [`../../../raw/research/0172-2026-04-21-avoid-reinterprets-binaryen-research.md`](../../../raw/research/0172-2026-04-21-avoid-reinterprets-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AvoidReinterprets.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets64.wast>
