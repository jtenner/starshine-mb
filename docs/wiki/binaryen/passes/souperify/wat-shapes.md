---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-souperify-primary-sources.md
  - ../../../raw/research/0338-2026-04-25-souperify-source-bridge.md
  - ../../../raw/research/0219-2026-04-21-souperify-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flat-dataflow-traces-and-single-use-boundaries.md
  - ./starshine-strategy.md
---

# `souperify` input / output shape catalog

This page is deliberately phrased as an **input / output** catalog, not a normal rewrite catalog.
`Souperify` prints traces; it does not optimize the function body. The current Starshine status page [`./starshine-strategy.md`](./starshine-strategy.md) explains why that output contract is a separate local design problem rather than a normal HOT rewrite.

## Shape 1: straight-line integer slice

### Input shape

```wat
(local.set $i
  (i64.eq
    (local.get $a)
    (local.get $x)))
(local.set $j
  (i64.ne
    (local.get $a)
    (local.get $y)))
(local.set $r
  (i32.and
    (local.get $i)
    (local.get $j)))
(return (local.get $r))
```

### What `souperify` does

- builds DataFlow `Expr` nodes for the comparisons and `and`
- follows copy-free local traffic through the sets/gets
- chooses the final arithmetic / logical node as a trace root
- prints a Souper-style LHS slice

### Why it matters

This is the easiest positive family and the one closest to the paper-style examples in the official test file.

## Shape 2: `if`-guarded computation with a path condition

### Input shape

```wat
(if
  (i64.lt_s
    (local.get $x)
    (local.get $y))
  (then
    ...compute and return something...)
  (else
    unreachable))
```

### What `souperify` does

- extracts the guarded computation like ordinary work
- also records the `if` condition as an extra condition source
- prints `pc` and possibly `blockpc` lines for that path

### Why it matters

This is the clearest beginner example of how branch information enters the emitted trace.

## Shape 3: merged local values become `phi`

### Input shape

```wat
(block $out
  (if (local.get $c)
    (then
      (local.set $x (i32.const 1)))
    (else
      (local.set $x (i32.const 2))))
  (return
    (i32.add
      (local.get $x)
      (i32.const 3))))
```

### What `souperify` does

- sees different incoming values for the same logical local after control-flow merge
- creates a DataFlow `Block`
- creates a `Phi` fed by the incoming branch values
- prints `block` plus `phi` before the final arithmetic node

### Why it matters

This is the main family that proves `souperify` is not just printing straight-line AST fragments.

## Shape 4: reusable child in plain `souperify`

### Input shape

```wat
(local.set $t
  (i32.add (local.get $x) (i32.const 1)))
(drop (local.get $t))
(return
  (i32.mul
    (local.get $t)
    (i32.const 4)))
```

### What plain `souperify` does

- can still expand the `add` subtree inside a larger root trace
- may annotate the reused internal node with `(hasExternalUses)`

### Why it matters

This is the plain-pass side of the sibling split.

## Shape 5: the same reusable child in `souperify-single-use`

### Input shape

Same as above.

### What `souperify-single-use` does

- notices that the child value has more than one use
- forbids that node as an expanded child dependency
- replaces it with a fresh `var` when building the larger trace

### Why it matters

This is the simplest way to explain that single-use mode is child truncation, not root filtering.

## Shape 6: deep dependency chain

### Input shape

```wat
(local.set $x (i32.xor (local.get $x) (i32.const 1234)))
(local.set $x (i32.add (local.get $x) (i32.const 7)))
(local.set $x (i32.mul (local.get $x) (i32.const 9)))
...many more layers...
(return (local.get $x))
```

### What `souperify` does

- follows the chain only until the depth or total-node budget is exhausted
- then replaces the remaining hidden prefix with a fresh `var`

### Why it matters

This is the main bound-preservation family.
The pass prefers a useful partial trace over a giant exact one.

## Shape 7: loop-carried local

### Input shape

```wat
(loop $L
  (local.set $x
    (i32.add
      (local.get $x)
      (i32.const 1)))
  ...
  (br_if $L ...))
(return (local.get $x))
```

### What `souperify` does

- does not build a real loop phi for the carried value
- summarizes the loop-carried input with `var` boundaries when needed

### Why it matters

This is the main family where readers may otherwise expect more precision than the source actually provides.

## Shape 8: unsupported op inside the slice

### Input shape

```wat
(local.set $x
  (i32.load (local.get $p)))
(return
  (i32.add
    (local.get $x)
    (i32.const 1)))
```

### What `souperify` does

- the unsupported part of the slice does not become a printed arithmetic node
- extraction may stop there, fall back to `var`, or fail to produce that trace

### Why it matters

The printer's opcode surface is narrow.
This pass is not a generic wasm-op exporter.

## Shape 9: trivial root

### Input shape

```wat
(return (local.get $x))
```

or a slice that reduces to only one unknown input.

### What `souperify` does

- drops the trace as uninteresting

### Why it matters

This is why the pass output is more selective than “every value becomes a trace.”

## Shape 10: bad or mixed merge value

### Input shape

A branch merge where the carried values cannot be represented cleanly by the trace builder or collapse into unsupported types.

### What `souperify` does

- can mark the relevant node path as `Bad`
- or avoid emitting the trace altogether

### Why it matters

This is the general bailout family behind the official `bad-phi-*` examples.

## Shape 11: Starshine unknown-pass behavior

### Input shape

Any module plus a local command request equivalent to `--souperify` or `--souperify-single-use`.

### What current Starshine does

- does not find either name in the pass registry
- reports an unknown pass instead of running a no-op or boundary-only placeholder
- emits no Souper text because no extractor/output lane exists

### Why it matters

This is not an upstream WAT transform shape, but it is the most important local shape for users: current Starshine does not implement the pass family at all. Future support must add both extraction semantics and an output contract.

## Quick checklist

When predicting output, ask:

- is the function already flat?
- is the root a supported integer unary/binary/`select` form?
- are dependencies small enough to expand?
- do branches create `phi` / `pc` / `blockpc` metadata?
- does single-use mode force some children back to `var`?
- do loops or unsupported ops cut the slice off?

That checklist matches the real `version_129` pass much better than assuming `souperify` is a general optimizer.
