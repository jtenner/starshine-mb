---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md
  - ../../../raw/research/0182-2026-04-21-const-hoisting-binaryen-research.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstHoisting.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/const-hoisting.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./size-model-and-boundaries.md
---

# `const-hoisting` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen `const-hoisting`.

## Reading rule

When the examples say a constant is “hoisted,” Binaryen means:

- a fresh local is added
- a function-entry prelude `local.set` is created
- every recorded use site becomes `local.get temp`
- the function body is wrapped in an extra prelude block and original-body block

## Positive family 1: repeated 3-byte signed-LEB integer

```wat
(func
  (drop (i32.const 8192))
  (drop (i32.const 8192))
  (drop (i32.const 8192))
  (drop (i32.const 8192))
  (drop (i32.const 8192))
  (drop (i32.const 8192))
)
```

Typical outcome:

```wat
(func
  (local i32)
  (block
    (local.set 0
      (i32.const 8192)
    )
  )
  (block
    (drop (local.get 0))
    (drop (local.get 0))
    ...
  )
)
```

Why:

- `8192` is a 3-byte signed-LEB literal
- 3-byte literals need 6 uses to win

## Positive family 2: repeated 4-byte signed-LEB integer

```wat
(func
  (drop (i32.const 1048576))
  (drop (i32.const 1048576))
  (drop (i32.const 1048576))
  (drop (i32.const 1048576))
)
```

Typical outcome:

- hoisted through one temp local

Why:

- 4-byte literals need only 4 uses to win

## Positive family 3: repeated `f32.const`

```wat
(func
  (drop (f32.const 0))
  (drop (f32.const 0))
  (drop (f32.const 0))
  (drop (f32.const 0))
)
```

Typical outcome:

- hoisted into one `f32` temp local

Why:

- `f32` payloads are fixed-width 4 bytes
- 4 appearances are enough

## Positive family 4: repeated `f64.const`

```wat
(func
  (drop (f64.const 0))
  (drop (f64.const 0))
)
```

Typical outcome:

- hoisted into one `f64` temp local

Why:

- `f64` payloads are fixed-width 8 bytes
- 2 appearances are already enough

## Preserved family 1: small signed-LEB integer stays inline

```wat
(func
  (drop (i32.const 64))
  (drop (i32.const 64))
  (drop (i32.const 64))
  (drop (i32.const 64))
)
```

Typical outcome:

- no change

Why:

- `64` is only a 2-byte signed-LEB literal
- 2-byte constants are never worth hoisting under the current formula

## Preserved family 2: too few appearances

```wat
(func
  (drop (i32.const 8192))
  (drop (i32.const 8192))
  (drop (i32.const 8192))
  (drop (i32.const 8192))
  (drop (i32.const 8192))
)
```

Typical outcome:

- no change

Why:

- 3-byte literals need 6 appearances, not 5

## Preserved family 3: too few float appearances

```wat
(func
  (drop (f32.const 0))
  (drop (f32.const 0))
  (drop (f32.const 0))
)
```

Typical outcome:

- no change

Why:

- `f32` needs 4 appearances under the current size model

## Preserved family 4: one-use or two-use tiny groups

```wat
(func
  (drop (i32.const 0))
  (drop (i32.const 0))
)
```

Typical outcome:

- no change

Why:

- the pass has `MIN_USES = 2`, but tiny literals still fail the actual byte test

## Bailout family 1: `+0.0` and `-0.0` are different float buckets

```wat
(func
  (drop (f32.const 0.0))
  (drop (f32.const 0.0))
  (drop (f32.const -0.0))
  (drop (f32.const -0.0))
)
```

Typical outcome:

- no four-use hoist from combining all four drops together

Why:

- float grouping is by exact typed bit identity
- `+0.0` and `-0.0` are separate `Literal` buckets
- each two-use bucket is still below the `f32` threshold

## Bailout family 2: distinct NaN payloads are different buckets

```wat
(func
  (drop (f32.const nan:0x1))
  (drop (f32.const nan:0x1))
  (drop (f32.const nan:0x2))
  (drop (f32.const nan:0x2))
)
```

Typical outcome:

- no shared four-use hoist across the two NaN forms

Why:

- `Literal` equality compares float bits
- different NaN payloads are separate groups

## Bailout family 3: `v128.const`

```wat
(func
  (drop (v128.const i32x4 0 0 0 0))
  (drop (v128.const i32x4 0 0 0 0))
)
```

Typical outcome:

- no change

Why:

- `v128` is explicitly unsupported in `version_129`

## Bailout family 4: nonliteral repeated computation

```wat
(func
  (drop (i32.add (local.get 0) (i32.const 1)))
  (drop (i32.add (local.get 0) (i32.const 1)))
)
```

Typical outcome:

- no change from `const-hoisting` alone

Why:

- the pass only groups `Const` nodes
- it does not value-number nonliteral expressions

## Bailout family 4: cross-function repeats

```wat
(func $a
  (drop (f64.const 0))
  (drop (f64.const 0))
)
(func $b
  (drop (f64.const 0))
  (drop (f64.const 0))
)
```

Typical outcome:

- each function is considered independently
- no shared global or module-wide pool is created

Why:

- the pass is function-local in the reviewed implementation

## Structural side effect family: extra prelude block

Even when the hoist is profitable, the immediate output often looks a bit larger structurally:

- new local declarations
- a `block` containing `local.set`s
- the original body wrapped after that

That is expected.
Binaryen's own source comment points future cleanup at `merge-blocks`.

## Best short prediction rule

A literal is a good `const-hoisting` candidate only if all of these feel true:

- it is already a `Const` node
- it repeats within the same function
- its encoded payload is at least 3 bytes, or it is a fixed-width float with enough uses
- the use count crosses the profitability threshold
- it is not `v128`

If any of those fail, Binaryen usually preserves the inline constant.

## Sources

- [`../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md`](../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md)
- [`../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md)
- [`../../../raw/research/0182-2026-04-21-const-hoisting-binaryen-research.md`](../../../raw/research/0182-2026-04-21-const-hoisting-binaryen-research.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstHoisting.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/literal.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/const-hoisting.wast>
