---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0161-2026-04-21-inlining-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./heuristics-splitting-and-plain-vs-optimizing.md
  - ../inlining-optimizing/index.md
---

# `inlining` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's plain `inlining` pass.

## Read this page with one mental model

Binaryen is not asking only:

- “is this callee small?”

It is asking a broader question:

- “is this function boundary small enough, root-free enough, and structurally simple enough that replacing this reachable direct call is worth the code growth and repair work?”

## Important note about the examples

The `after` snippets are **conceptual**.
Real Binaryen output may still contain:

- wrapper blocks,
- temp locals,
- `drop(...)` cleanup,
- or copied-label scaffolding.

That is especially important here because plain `inlining` does **not** do the nested useful-pass rerun that `inlining-optimizing` performs.

## Quick glossary

- **trivial shrinks**: a one-instruction wrapper that always shrinks when inlined
- **one-caller case**: a helper with exactly one counted use and no global/root reason to keep it alive as a boundary
- **split Pattern A**: `if (simple) return;` then heavy later work
- **split Pattern B**: a short ladder of top-level simple `if`s with strict final-item rules
- **root survivor**: a function that can inline into some callers but must still remain declared because exports/start/refs keep it alive

## Shape 1: tiny trivial wrapper that always shrinks

Before:

```wat
(func $add1 (param $x i32) (result i32)
  (i32.add
    (local.get $x)
    (i32.const 1)
  )
)

(func $caller (param $y i32) (result i32)
  (call $add1
    (local.get $y)
  )
)
```

After, conceptually:

```wat
(func $caller (param $y i32) (result i32)
  (block $__inlined_func$add1 (result i32)
    (local.set $tmp
      (local.get $y)
    )
    (i32.add
      (local.get $tmp)
      (i32.const 1)
    )
  )
)
```

Why it rewrites:

- the callee is tiny,
- it fits the trivial-wrapper heuristics,
- and the call boundary is not buying much.

## Shape 2: one-caller helper can inline and disappear

Before:

```wat
(func $helper (result i32)
  (i32.const 7)
)

(func $caller (result i32)
  (call $helper)
)
```

After, conceptually:

```wat
(func $caller (result i32)
  (block $__inlined_func$helper (result i32)
    (i32.const 7)
  )
)
```

And then the helper declaration can disappear if no other counted or global uses remain.

## Shape 3: exported or tabled helper may inline but survive

Before:

```wat
(table 1 1 funcref)
(elem (i32.const 0) $helper)
(export "api" (func $helper))

(func $helper (result i32)
  (i32.const 1)
)

(func $caller (result i32)
  (call $helper)
)
```

After, conceptually:

```wat
(func $caller (result i32)
  (block $__inlined_func$helper (result i32)
    (i32.const 1)
  )
)

;; but $helper itself still remains declared
```

Why it matters:

- inlining a direct callsite is not the same as deleting the function boundary.

## Shape 4: unreachable callee trap must still propagate

Before:

```wat
(func $trap (result i32)
  (unreachable)
)

(func $caller (result i32)
  (call $trap)
)
```

After, conceptually:

```wat
(func $caller (result i32)
  (block $__inlined_func$trap (result i32)
    (unreachable)
  )
)
```

The important rule is not the exact printed block shape.
It is that the caller still sees unreachable/trapping behavior rather than silently becoming reachable through a typed wrapper.

## Shape 5: copied vars may need zero initialization

Before:

```wat
(func $callee
  (local $tmp i32)
  ;; body that may rely on callee-local zero-init semantics
)

(func $caller
  (loop $L
    (call $callee)
    (br $L)
  )
)
```

After, conceptually:

```wat
(func $caller
  (local $new_tmp i32)
  (loop $L
    (block $__inlined_func$callee
      (local.set $new_tmp (i32.const 0))
      ;; copied body using $new_tmp
    )
    (br $L)
  )
)
```

Why it matters:

- inlining into loops can otherwise observe stale local state that the original separate callee frame would not have preserved.

## Shape 6: nondefaultable local does **not** get fake zeroing

Before:

```wat
(func $callee
  (local $tmp (ref func))
)

(func $caller
  (call $callee)
)
```

After, conceptually:

```wat
(func $caller
  (local $new_tmp (ref func))
  (block $__inlined_func$callee
    ;; no impossible fake zero init inserted here
  )
)
```

Why it matters:

- Binaryen adds the local,
- but later post-inline repair handles nondefaultable-local validity instead of pretending a zero/default exists.

## Shape 7: return becomes break out of the inlined body

Before:

```wat
(func $callee (param $x i32) (result i32)
  (if (local.get $x)
    (then (return (i32.const 1)))
  )
  (i32.const 2)
)

(func $caller (param $y i32) (result i32)
  (call $callee (local.get $y))
)
```

After, conceptually:

```wat
(func $caller (param $y i32) (result i32)
  (local $tmp i32)
  (block $__inlined_func$callee (result i32)
    (local.set $tmp (local.get $y))
    (if (local.get $tmp)
      (then
        (br $__inlined_func$callee
          (i32.const 1)
        )
      )
    )
    (i32.const 2)
  )
)
```

Why it rewrites this way:

- copied returns must exit only the copied callee body, not the whole caller function.

## Shape 8: nested `return_call*` may be downgraded and repaired

Before:

```wat
(func $callee (result i32)
  (return_call $target)
)

(func $caller (result i32)
  (call $callee)
)
```

After, conceptually:

```wat
(func $caller (result i32)
  (block $__inlined_func$callee (result i32)
    ;; repaired ordinary call plus branch structure
    ;; that exits the inlined body correctly
  )
)
```

Why the page keeps this conceptual:

- the exact rewritten scaffolding is more complex than the simple summary,
- but the real rule is that a nested return-style call must stop returning from the whole caller unless the outer callsite was already a return call.

## Shape 9: Pattern A partial inlining

Before:

```wat
(func $maybe-work-hard (param $x i32)
  (if (local.get $x)
    (then (return))
  )
  ;; heavy later work
  (call $heavy)
)

(func $caller (param $v i32)
  (call $maybe-work-hard (local.get $v))
)
```

After, conceptually:

```wat
(func $caller (param $v i32)
  (if (local.get $v)
    (then)
    (else
      (call $byn-split-outlined-A$maybe-work-hard
        (local.get $v)
      )
    )
  )
)
```

The actual split helper names differ, but the important point is:

- Binaryen can inline the guard while outlining the heavy remainder.

## Shape 10: Pattern B short `if` ladder split

Before:

```wat
(func $guard-ladder (param $x i32) (result i32)
  (if (local.get $x)
    (then (return (call $heavy1)))
  )
  (if (global.get $g)
    (then (return (call $heavy2)))
  )
  (i32.const 0)
)
```

After, conceptually:

```wat
(func $caller (param $y i32) (result i32)
  ;; copied top-level guards
  ;; each guard calls an outlined helper only when needed
)
```

Why it rewrites:

- the top-level `if` run is short and simple enough,
- and the final item does not depend on locals written inside the `if` bodies.

## Shape 11: dangerous final-item local dependency blocks Pattern B

Before:

```wat
(func $bad (param $x i32) (result i32)
  (if (local.get $x)
    (then
      (local.set $tmp (i32.const 1))
    )
  )
  (local.get $tmp)
)
```

After:

```wat
;; left unchanged by split inlining
```

Why it bails out:

- the final item reads a local written inside the guarded body,
- so splitting the function would change the relation between the guarded write and the final read.

## Shape 12: complex guard blocks split inlining

Before:

```wat
(func $bad (param $x i32)
  (if
    (call $expensive-condition (local.get $x))
    (then (return))
  )
  (call $heavy)
)
```

After:

```wat
;; left unchanged by split inlining
```

Why it bails out:

- split inlining only accepts very simple guard expressions.

## Shape 13: `try_delegate` blocks full inlining

Before:

```wat
(func $delegatey
  (try
    (do
      ...
    )
    (delegate $outer)
  )
)
```

After:

```wat
;; left unchanged by full inlining heuristics in version_129
```

Why it matters:

- this is a real source-backed bailout family.

## Shape 14: callee with loops may stay out by default

Before:

```wat
(func $looping (param $x i32) (result i32)
  (loop $L
    ...
  )
)
```

After:

```wat
;; often left unchanged by default flexible heuristics
```

Why it matters:

- loops do not make inlining impossible forever,
- but Binaryen's default policy treats them conservatively.

## Shape 15: plain `inlining` leaves cleanup debris that optimizing variant may erase later

Before:

```wat
(func $helper (param $x i32) (result i32)
  (i32.add (local.get $x) (i32.const 0))
)
```

After plain `inlining`, conceptually:

```wat
(func $caller ...
  (block $__inlined_func$helper (result i32)
    (local.set $tmp ...)
    (i32.add (local.get $tmp) (i32.const 0))
  )
)
```

After `inlining-optimizing`, later neighboring passes may also erase:

- the useless add-zero,
- extra temps,
- or wrapper structure.

That is why plain vs optimizing should never be taught as identical outputs with different branding.
