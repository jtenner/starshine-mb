---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0177-2026-04-21-inline-main-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inline-main.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./special-case-contract-and-boundaries.md
---

# `inline-main` WAT shapes

This page is a beginner-friendly catalog of the WAT/module shapes that matter for Binaryen `inline-main`.

## Mental model

The pass is looking for one exact story:

- `main` is just a wrapper,
- `__original_main` contains the real work,
- and the wrapper reaches it through exactly one direct call.

If that story is present, Binaryen inlines.
If not, Binaryen preserves the module.

---

## Positive shape 1: one direct wrapper call

### Before

```wat
(module
  (export "main" (func $main))

  (func $__original_main (result i32)
    (i32.const 0)
  )

  (func $main (param i32 i32) (result i32)
    (call $__original_main)
  )
)
```

### After

Binaryen inlines the body of `__original_main` into `main`.
In the official test, the immediate result is still wrapped in a named inlined block:

```wat
(func $main (param i32 i32) (result i32)
  (block $__inlined_func$__original_main (result i32)
    (i32.const 0)
  )
)
```

### Why this matters

This proves two things at once:

- the pass succeeds on the exact wrapper shape
- successful output can still show shared inlining scaffolding instead of collapsing all the way to a bare constant immediately

---

## Positive shape 2: wrapper already simplified away

### Before

```wat
(module
  (export "main" (func $main))

  (func $__original_main (result i32)
    (i32.const 0)
  )

  (func $main (param i32 i32) (result i32)
    (i32.const 0)
  )
)
```

### After

Unchanged.

### Why this matters

The pass does not try to prove semantic equivalence and then delete `__original_main`.
It only reacts to the direct wrapper-call pattern.

---

## Bailout shape 1: two direct calls from `main`

### Before

```wat
(module
  (export "main" (func $main))

  (func $__original_main (result i32)
    (i32.const 0)
  )

  (func $main (param i32 i32) (result i32)
    (drop (call $__original_main))
    (call $__original_main)
  )
)
```

### After

Unchanged.

### Why this matters

This is the most important negative family in the dedicated lit file.
Binaryen does **not** inline one and leave the other.
It bails out entirely once the exact-one-call rule fails.

---

## Bailout shape 2: missing `__original_main`

### Before

```wat
(module
  (export "main" (func $main))

  (func $main (param i32 i32) (result i32)
    (i32.const 0)
  )
)
```

### After

Unchanged.

### Why this matters

The pass is name-based and relation-based.
Without the named partner function, there is nothing to do.

---

## Bailout shape 3: missing `main`

### Before

```wat
(module
  (func $__original_main (result i32)
    (i32.const 0)
  )
)
```

### After

Unchanged.

### Why this matters

The pass is not "inline any wrapper-like function pair." It is specifically about `main` and `__original_main`.

---

## Bailout shape 4: imported `main`

### Before

```wat
(module
  (import "env" "main" (func $main (param i32 i32) (result i32)))
  (export "main" (func $main))

  (func $__original_main (result i32)
    (i32.const 0)
  )
)
```

### After

Unchanged.

### Why this matters

Imported functions have no local body to scan or rewrite.
The pass is defined-body cleanup, not import-boundary editing.

---

## Bailout shape 5: imported `__original_main`

### Before

```wat
(module
  (import "env" "original_main" (func $__original_main (result i32)))
  (export "main" (func $main))

  (func $main (param i32 i32) (result i32)
    (call $__original_main)
  )
)
```

### After

Unchanged.

### Why this matters

The pass requires an inlinable body for `__original_main`.
An imported callee cannot provide that.

---

## Inferred but important shared-helper shape: visible block wrappers

Even though the dedicated test uses very small bodies, the printed result already shows the shared helper's wrapper-block style.
That implies a broader rule:

- successful `inline-main` output may still look structured
- because the pass inherits ordinary inline-body rewriting machinery

A future port should therefore be ready for successful outputs that still contain:

- a named wrapper block
- copied locals
- return-to-break lowering artifacts

That statement is an inference from the dedicated test plus the reviewed shared helper code in `Inlining.cpp`.

---

## Non-goals this page makes explicit

`inline-main` is **not** trying to do any of these things:

- heuristic general inlining
- table or indirect-call cleanup
- repeated-call wrapper simplification
- dead-helper deletion by itself
- final canonical block cleanup by itself

Those belong to neighboring passes or later cleanup, not to `inline-main`'s own contract.

## Quick checklist for future reductions

When reducing a future `inline-main` behavior question, first classify the module into one of these buckets:

- exactly one direct wrapper call -> should inline
- no wrapper relation -> should preserve
- imported endpoint -> should preserve
- multiple direct wrapper calls -> should preserve

That classification matches the actual dedicated upstream test surface.

## Sources

- [`../../../raw/research/0177-2026-04-21-inline-main-binaryen-research.md`](../../../raw/research/0177-2026-04-21-inline-main-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inline-main.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
