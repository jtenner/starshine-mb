---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md
  - ../../../raw/research/0287-2026-04-24-instrument-locals-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0227-2026-04-21-instrument-locals-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/InstrumentLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals_all-features_disable-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals_effects.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals-eh-legacy.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./unsupported-types-effects-and-import-roster.md
  - ./starshine-strategy.md
---

# `instrument-locals` WAT shapes

This page is a beginner-friendly catalog of the main IR shapes Binaryen rewrites.
The examples are schematic: they show the contract, not verbatim full lit output.
The primary-source manifest for this shape catalog is [`../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md`](../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md).

## 1. `local.get i32` -> wrapped `get_i32` call

Before:

```wat
(local.get $x)
```

After conceptually:

```wat
(call $get_i32
  (i32.const 0) ;; call id
  (i32.const 0) ;; local id
  (local.get $x))
```

The helper returns `i32`, so the rewritten node can stay in value position.

## 2. `local.set i32` -> wrap the assigned value, keep the set

Before:

```wat
(local.set $x
  (i32.const 10))
```

After conceptually:

```wat
(local.set $x
  (call $set_i32
    (i32.const 0) ;; call id
    (i32.const 0) ;; local id
    (i32.const 10)))
```

The outer `local.set` stays.
Only the value child is replaced.

## 3. `local.tee` follows the same value-wrapping shape

Conceptually, because the pass rewrites `LocalSet` values, tee-like local writes keep their outer write node and wrap the assigned value the same way.

Before conceptually:

```wat
(local.tee $x
  (f32.const 1.5))
```

After conceptually:

```wat
(local.tee $x
  (call $set_f32
    (i32.const 1)
    (i32.const 0)
    (f32.const 1.5)))
```

## 4. Nullable `funcref` / `externref` positives

With reference types enabled, Binaryen can wrap supported nullable refs.

Conceptually:

```wat
(drop
  (call $get_funcref
    (i32.const 3)
    (i32.const 4)
    (local.get $F)))
```

and:

```wat
(local.set $X
  (call $set_externref
    (i32.const 4)
    (i32.const 5)
    (ref.null extern)))
```

The important boundary is that this is **not** general reference-type support.
It is only the reviewed nullable `funcref` / `externref` subset.

## 5. SIMD `v128` positives

With SIMD enabled, the pass can wrap `v128` locals too.

Conceptually:

```wat
(drop
  (call $get_v128
    (i32.const 7)
    (i32.const 6)
    (local.get $S)))
```

and:

```wat
(local.set $S
  (call $set_v128
    (i32.const 8)
    (i32.const 6)
    (v128.const i32x4 1 2 3 4)))
```

## 6. Ordinary `i64` locals stay untouched today

This is the most surprising shape in the dossier.

Even though helper imports for `get_i64` / `set_i64` are injected, ordinary `i64` local traffic is still a no-op in the visitors.

Conceptually before and after:

```wat
(drop
  (local.get $y))
```

and:

```wat
(local.set $y
  (i64.const 1))
```

remain unchanged by the reviewed implementation.

## 7. Legacy-EH `pop` payloads stay untouched

Before:

```wat
(try
  (do)
  (catch $e
    (local.set $x
      (pop i32))))
```

After conceptually:

```wat
(try
  (do)
  (catch $e
    (local.set $x
      (pop i32))))
```

The pass deliberately skips `Pop`-carrying sets.

## 8. Helper-import injection at module scope

The transformed module grows imports such as:

```wat
(import "env" "get_i32" (func $get_i32 (param i32 i32 i32) (result i32)))
(import "env" "set_i32" (func $set_i32 (param i32 i32 i32) (result i32)))
(import "env" "get_f64" (func $get_f64 (param i32 i32 f64) (result f64)))
(import "env" "set_f64" (func $set_f64 (param i32 i32 f64) (result f64)))
```

plus feature-gated `funcref` / `externref` / `v128` helpers.

This module-level helper roster is part of the real pass output, not just an implicit runtime requirement.

## 9. Effect interaction shape

A local-only helper function that would have become vacuous after effect analysis can stop collapsing once instrumentation adds import calls.

Conceptually:

Before instrumentation, later cleanup may shrink:

```wat
(func $use-local
  (local $x i32)
  (local.set $x (i32.const 10)))
```

much more aggressively.

After instrumentation, the same function becomes:

```wat
(func $use-local
  (local $x i32)
  (local.set $x
    (call $set_i32
      (i32.const 0)
      (i32.const 0)
      (i32.const 10))))
```

and the inserted import call is now observable and effectful.

## Beginner rule of thumb

If the Binaryen shape is:

- supported `local.get` -> expect `call $get_* (... local.get ...)`
- supported `local.set` / `local.tee` -> expect wrapped assigned value via `call $set_*`
- ordinary `i64` local traffic -> expect no rewrite today
- legacy-EH `pop` payload -> expect no rewrite
- module after the pass -> expect a larger helper-import surface and more conservative later effect-based cleanup

Current Starshine does not emit these shapes because `instrument-locals` is not implemented or reserved locally; see [`./starshine-strategy.md`](./starshine-strategy.md).
