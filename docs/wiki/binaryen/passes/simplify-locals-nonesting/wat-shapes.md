---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md
  - ../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./flatness-variant-boundaries.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../flatten/index.md
  - ../dataflow-optimization/index.md
---

# `simplify-locals-nonesting` WAT shape catalog

## How to read this page

This pass is easiest to understand by contrast.
When looking at a shape, ask two questions:

1. Is the pass only cleaning up copy traffic while staying flat?
2. Or would the rewrite require pushing a real expression into a new nested consumer?

If the second answer is yes, the nonesting variant normally refuses it.

## Positive family 1: flat copy-chain retargeting

Before:

```wat
(local.set $b
  (local.get $a))
(local.set $c
  (local.get $b))
```

Typical outcome:

```wat
(nop)
(local.set $c
  (local.get $a))
```

Why this is allowed:

- the stored value is only another `local.get`
- the rewrite stays in flat local-copy territory
- no new nested real expression is created

## Positive family 2: direct sink into another `local.set`

Before:

```wat
(local.set $tmp
  (local.get $src))
(local.set $dst
  (local.get $tmp))
```

Possible outcome:

```wat
(nop)
(local.set $dst
  (local.get $src))
```

Why this is allowed:

- the parent is a `local.set`
- the source explicitly treats that as a flat-safe sink position

## Positive family 3: equivalent-local canonicalization

Before:

```wat
(local.set $x
  (local.get $a))
(local.set $y
  (local.get $a))
(drop
  (local.get $y))
```

Possible late outcome:

```wat
(local.set $x
  (local.get $a))
(nop)
(drop
  (local.get $x))
```

Why this is allowed:

- the late `EquivalentOptimizer` tracks locals that carry the same value
- canonicalizing to one representative does not require adding nesting

## Positive family 4: dead-set cleanup after flat rewrites

Before:

```wat
(local.set $tmp
  (local.get $a))
(nop)
```

After late cleanup:

```wat
(nop)
(nop)
```

Why this matters:

- the pass still ends with `UnneededSetRemover`
- so “nonesting” does not mean “leave the dead temp behind forever"

## Positive family 5: flatten-neighbor cleanup

Official combo test context:

```wat
flatten -> simplify-locals-nonesting -> dfo
```

Typical visible result:

- many flatten-created carrier locals disappear or retarget
- the output still looks flat enough for later flatness-sensitive passes

This is a pipeline shape rather than one tiny rewrite, but it is an important real use case.

## Preserved family 1: multi-use value that would need a tee

Before:

```wat
(local.set $x
  (i32.const 1))
(if
  (local.get $x)
  (then (nop)))
(if
  (local.get $x)
  (then (nop)))
```

Preserved idea:

- no new `local.tee` is created
- multi-use sink-through-first-use does not happen

Why:

- `allowTee = false`
- this variant cannot use the classic first-use tee rewrite

## Preserved family 2: sink into `drop`

Before:

```wat
(local.set $tmp
  (i32.add
    (local.get $x)
    (i32.const 1)))
(drop
  (local.get $tmp))
```

Not rewritten into:

```wat
(drop
  (i32.add
    (local.get $x)
    (i32.const 1)))
```

Why:

- that would create new nesting under `drop`
- the nonesting variant forbids it

## Preserved family 3: no block/if/loop result synthesis

Before:

```wat
(if (i32.const 1)
  (then
    (local.set $a
      (i32.const 7)))
  (else
    (local.set $a
      (i32.const 8))))
(drop
  (local.get $a))
```

Not rewritten into a structured result carrier like:

```wat
(drop
  (if (result i32)
    (i32.const 1)
    (then (i32.const 7))
    (else (i32.const 8))))
```

Why:

- `allowStructure = false`
- the control-result helpers are disabled in this variant

## Preserved family 4: ordinary consumer nesting

Before:

```wat
(call $f
  (local.get $tmp))
```

If `$tmp` was defined by a non-copy expression, the pass will generally keep the flat local traffic rather than rewrite to:

```wat
(call $f
  (complex-value))
```

Why:

- call operands are ordinary nested consumer positions
- nonesting forbids introducing such new nesting

## Bailout family 1: effect or trap barriers still matter

Even though this pass is conservative in shape, it is still effect-aware.
So shapes like these remain blocked:

```wat
(local.set $tmp
  (load ...))
(store ...)
(use (local.get $tmp))
```

Why:

- the shared `EffectAnalyzer` barriers still apply
- nonesting is an extra restriction, not a replacement for effect safety

## Bailout family 2: dangling EH pops

The shared `canSink(...)` logic still rejects values with dangling EH pops.
So exception-handling shape safety remains part of the pass contract.

## Bailout family 3: not in the default no-DWARF path

A practical pipeline bailout is worth naming too.
If someone expects this pass to show up in the repo's canonical no-DWARF optimize path, that expectation is wrong.
This pass lives in separate aggressive / explicit pipelines, not the current default path.

## Contrast summary

### `simplify-locals-notee-nostructure`

- still allows direct nested sinks
- therefore can simplify more aggressively than `-nonesting`

### `simplify-locals-nonesting`

- keeps the flatter local shell
- focuses on copy cleanup and flat-safe rewrites

### `flatten`

- makes things flat
- often introduces many locals

### `simplify-locals-nonesting`

- trims some of those locals back down
- without reintroducing the nesting that `flatten` just removed

## Memory hook

If you want one short memory hook, use this:

- `simplify-locals-nonesting` = “clean up local traffic, but do not push real values down into new nested use sites.”

## Validation bridge

Use these shapes with the local first-slice plan in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md); do not use full `simplify-locals` as this sibling's oracle.

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md)
- [`../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md`](../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md`](../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast>
