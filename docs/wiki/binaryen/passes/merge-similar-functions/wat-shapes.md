---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md
  - ../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0174-2026-04-21-merge-similar-functions-binaryen-research.md
  - ../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeSimilarFunctions.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_types.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions-param-limit.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./equivalence-classes-param-derivation-and-thunk-rewrites.md
  - ./implementation-structure-and-tests.md
  - ./profitability-indirection-and-type-barriers.md
  - ./starshine-strategy.md
---

# WAT shape catalog for `merge-similar-functions`

This page catalogs the main shape families beginners should look for when reading Binaryen `merge-similar-functions` output.

## Positive family 1: large constant-only wrappers

Before:

```wat
(func $a (result i32)
  (nop) (nop) (nop) (nop)
  (i32.const 42))

(func $b (result i32)
  (nop) (nop) (nop) (nop)
  (i32.const 43))
```

After the Binaryen-style rewrite shape:

```wat
(func $a (result i32)
  (call $byn$mgfn-shared$a
    (i32.const 42)))

(func $b (result i32)
  (call $byn$mgfn-shared$a
    (i32.const 43)))

(func $byn$mgfn-shared$a (param $p0 i32) (result i32)
  (nop) (nop) (nop) (nop)
  (local.get $p0))
```

Meaning:

- the large repeated body moves into one helper
- the differing constant becomes a synthetic param
- the original function names survive as tiny thunks

## Positive family 2: repeated same diff-vector reuses one param

Before:

```wat
(func $a (result i32)
  (i32.add (i32.const 42) (i32.const 42)))

(func $b (result i32)
  (i32.add (i32.const 43) (i32.const 43)))
```

After the Binaryen-style rewrite shape:

```wat
(func $byn$mgfn-shared$a (param $p0 i32) (result i32)
  (i32.add (local.get $p0) (local.get $p0)))
```

Meaning:

- Binaryen does not invent one synthetic param per site
- one reused diff-vector becomes one reused param

## Positive family 3: original params survive, locals get reindexed

Before:

```wat
(func $a (param $x i32) (result i32)
  (local $tmp i32)
  (i32.add (i32.const 42) (local.get $tmp)))

(func $b (param $x i32) (result i32)
  (local $tmp i32)
  (i32.add (i32.const 43) (local.get $tmp)))
```

Typical shared-helper shape:

```wat
(func $byn$mgfn-shared$a (param $x i32) (param $p1 i32) (result i32)
  (local $tmp i32)
  (i32.add (local.get $p1) (local.get $tmp)))
```

Meaning:

- original params stay first
- synthetic params come after them
- old non-param locals are shifted upward so they still mean the same variable

## Positive family 4: different direct callees become `ref.func` payloads

Before:

```wat
(func $wrap-foo (result i32)
  (call $foo))

(func $wrap-bar (result i32)
  (call $bar))
```

If reference types + GC are enabled and `$foo` / `$bar` share the same function type, the shared-helper family can look like:

```wat
(func $wrap-foo (result i32)
  (call $byn$mgfn-shared$wrap-foo
    (ref.func $foo)))

(func $wrap-bar (result i32)
  (call $byn$mgfn-shared$wrap-foo
    (ref.func $bar)))

(func $byn$mgfn-shared$wrap-foo (param $callee (ref $t)) (result i32)
  (call_ref $t
    (local.get $callee)))
```

Meaning:

- the differing callee is turned into a function-ref param
- the shared helper no longer has a fixed direct call target
- this is one of the most important non-obvious rewrite families in the pass

## Positive family 5: tail-call preserving wrapper merge

Before:

```wat
(func $a (result i32)
  (return_call $foo))

(func $b (result i32)
  (return_call $bar))
```

Binaryen can preserve that style in the merged family when the feature surface allows it:

```wat
(func $a (result i32)
  (return_call $byn$mgfn-shared$a
    (ref.func $foo)))

(func $b (result i32)
  (return_call $byn$mgfn-shared$a
    (ref.func $bar)))

(func $byn$mgfn-shared$a (param $callee (ref $t)) (result i32)
  (return_call_ref $t
    (local.get $callee)))
```

Meaning:

- the pass is not restricted to plain call-only wrappers
- it preserves the return-call shape when appropriate

## Positive family 6: same coarse hash, one real merged class

Conceptually, Binaryen can see a large bucket of functions that all hash alike because they differ only in const payloads or direct callees.
Then it still picks out one exact equivalence class inside that bucket and merges only that class.

Meaning:

- same hash is only a prefilter
- the real mergeable family is the stricter class found after structural comparison

## Bailout family 1: tiny wrappers stay separate

```wat
(func $a (result i32) (i32.const 44))
(func $b (result i32) (i32.const 45))
```

Why they may stay:

- the functions are legal to parameterize
- but the thunk-plus-helper overhead may outweigh the saved duplication
- profitability says “do nothing”

## Bailout family 2: incompatible original function signatures

```wat
(func $a (param i32) (result i32) ...)
(func $b (result i32) ...)
```

Why they stay:

- the pass requires the original wrappers themselves to have the same function type

## Bailout family 3: incompatible callee signatures

```wat
(func $wrap-a
  (call $callee-type-1))

(func $wrap-b
  (call $callee-type-2))
```

Why they stay:

- even if the wrappers otherwise look the same,
- there is no single safe function-ref parameter type for the shared helper

This is one of the main lessons of `merge-similar-functions_types.wast`.

## Bailout family 4: subtype-looking call families that still lack one safe helper type

```wat
(func $wrap-a
  (call $take-arrayref ...))

(func $wrap-b
  (call $take-eqref ...))
```

Why they may stay:

- the actual operand might look compatible with both calls in a specific example
- but the merged helper still needs one safe synthetic param type
- the reviewed Binaryen pass does not generalize this away

## Bailout family 5: too many synthetic params

Conceptual shape:

```wat
(func $a ... many differing constants ...)
(func $b ... many differing constants ...)
```

Why they stay:

- after original params plus synthetic params are counted,
- the helper would exceed the `255` param limit,
- so Binaryen rejects the class entirely

## Bailout family 6: imports never participate

```wat
(import "m" "a" (func $a ...))
```

Why it stays:

- imported functions are rejected immediately
- the pass only works on defined functions whose bodies it can clone and replace

## Bailout family 7: same hash but different real class

Conceptual shape:

```wat
(func $a
  (call $foo (i32.const 0)))

(func $b
  (call $bar (block (result i32)
               (drop (i32.const 0))
               (i32.const 0))))
```

Why they stay:

- the coarse hash can still ignore the direct callee names
- but the call operand structures are not flexibly equal
- so the functions split into different equivalence classes instead of merging

This is the most important “same hash is not enough” teaching shape.

## Bailout family 8: old-local-layout mismatches never enter the class stage

Conceptual shape:

```wat
(func $a (local i32 i32) ...)
(func $b (local i32) ...)
```

Why they stay:

- Binaryen rejects different total local counts up front
- the pass assumes the primary body's local layout can be reused after shifting old non-param locals upward

## What the pass is not trying to do

`merge-similar-functions` is not trying to:

- replace `duplicate-function-elimination`
- inline callee bodies into callers
- outline arbitrary common subregions
- prove semantic equality across very different CFGs
- parameterize arbitrary reference expressions beyond the reviewed `call` family

## Practical reading rule

When reading candidate output, ask these questions in order:

1. are the wrappers genuinely large enough that a helper might save size?
2. do they differ only in literals or eligible direct-call targets?
3. if calls differ, are reference types + GC enabled?
4. if calls differ, do the callees share the same function type?
5. after synthetic-param reuse, does the helper still stay at 255 params or fewer?
6. did Binaryen keep the original function names as thunks and move the big body into one generated helper?

If the answer to any of the first five becomes “no,” expect a bailout.

For current Starshine behavior, remember that these Binaryen output shapes are **future-port targets only**. Starshine currently tracks `merge-similar-functions` as a boundary-only known name and rejects direct requests before any helper/thunk rewrite runs; see [`./starshine-strategy.md`](./starshine-strategy.md).

## Sources

- [`../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md`](../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md)
- [`../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md`](../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0174-2026-04-21-merge-similar-functions-binaryen-research.md`](../../../raw/research/0174-2026-04-21-merge-similar-functions-binaryen-research.md)
- [`../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md`](../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeSimilarFunctions.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_types.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions-param-limit.wast>
