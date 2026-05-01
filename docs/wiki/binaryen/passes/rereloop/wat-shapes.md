---
kind: concept
status: supported
last_reviewed: 2026-04-30
sources:
  - ../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md
  - ../../../raw/binaryen/2026-04-30-rereloop-current-main-refresh.md
  - ../../../raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0183-2026-04-21-rereloop-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_rereloop.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/opt_flatten.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReReloop.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./flat-cfg-builder-and-boundaries.md
  - ./starshine-strategy.md
---

# Beginner-friendly WAT shape catalog for `rereloop`

This page focuses on the kinds of flat control-flow shapes `rereloop` actually rewrites or rejects.

## Read this page with one rule in mind

These are **post-flatten** shapes.
If a shape still relies on nested control values or non-flat tree structure, `rereloop` is not the right pass to apply directly.

## Positive family: flat `if` followed by a direct tail value

### Before

```wat
(func (result f64)
  (if
    (i32.const 0)
    (then
      (loop $label$2
        (unreachable)))
  )
  (f64.const -nan:0xfffffd63e4e5a)
)
```

### After, conceptually

```wat
(func (result f64)
  (if
    (i32.const 0)
    (then (block (unreachable)))
    (else
      (block
        (block
          ...
          (return ...)))))
)
```

### Why it changes

The flat body becomes:

- a condition CFG block
- a true edge into the unreachable arm
- a false edge into the tail-value arm

The generic relooper then rebuilds that as a structured `if/else`.

## Positive family: nested labeled `br_table` ladders

### Before

```wat
(block $a
  (block $b
    (block $c
      (br_table $b $a $c (i32.const 0)))
    (unreachable))
  (unreachable))
(unreachable)
```

### After, conceptually

```wat
(block $block$...$break
  ...
  (block $switch$...$leave
    (block $switch$...$default
      (block $switch$...$case$...
        (br_table ...))))
  ...)
```

### Why it changes

The pass groups switch-table values by target label, creates CFG switch branches, and lets the generic relooper rebuild a structured switch-like nest.
Repeated targets are merged at the CFG level.

## Positive family: skip-empty ladders

### Before

```wat
(func
  (block $a1
    (block $a2
      (block $a3
        (block $a4
          (br $a4))
        (br $a3))
      (br $a2))
    (br $a1)))
```

### After, conceptually

```wat
(func
  (block $block$...$break
    (block)
    (block
      (br $block$...$break)))
  (block
    (return)))
```

### Why it changes

This is one of the clearest lit examples that `rereloop` is not preserving the original nesting literally.
It rebuilds a smaller structured region that preserves the same transfer behavior.

## Positive family: mergeable `if` exits

### Before

```wat
(func
  (if
    (i32.const 0)
    (then (return))))
```

### After, conceptually

```wat
(func
  (block
    (block)
    (return)))
```

### Why it changes

Both paths end the function, so the generic restructuring can merge control into one visible exit shape.
The source test calls this out as a merge opportunity.

## Positive family: one-arm or empty-arm skip opportunities

### Before

```wat
(func
  (if
    (i32.const 1)
    (then
      (global.set $global (i32.const 0)))))
```

### After, conceptually

```wat
(func
  (block $block$...$break
    (block)
    (if
      (i32.const 1)
      (then
        (block
          (global.set $global (i32.const 0))
          (block (br $block$...$break))))
      (else
        (br $block$...$break))))
  (block (return)))
```

### Why it changes

The pass builds CFG edges first and then reconstructs structure from them, so even apparently simple one-arm `if` cases can gain explicit join blocks and breakable structure.

## Positive family: result-typed skip-only-one-branch-out

### Before

```wat
(func (result i32)
  (block $label$1 (nop))
  (if
    (i32.const 1)
    (then (unreachable)))
  (i32.const 0))
```

### After, conceptually

```wat
(func (result i32)
  (if
    (i32.const 1)
    (then (block (unreachable)))
    (else
      (block
        ...
        (return (i32.const 0))))))
```

### Why it changes

The true arm blocks one path through the CFG, so the remaining live path becomes the concrete returned result path.
The generic relooper rebuilds that explicitly.

## Positive family: flat optimize example after `--flatten --rereloop`

### Before

```wat
(func $foo (result funcref)
  (drop (call $foo))
  (ref.func $foo))
```

### After, conceptually

```wat
(func $foo (result funcref)
  (block
    (local.set $0 (call $foo))
    (drop (local.get $0))
    (local.set $1 (ref.func $foo))
    (local.set $2 (local.get $1))
    (return (local.get $2))))
```

### Why it matters

This combined test proves the pass is operating in the flatten-era world where nested values have already been spilled, and `rereloop` then rebuilds structured control while respecting the flatness contract.

## Visible boilerplate family: helper blocks and helper names

You will often see names like:

- `block$2$break`
- `switch$6$default`
- `switch$6$leave`

These are not arbitrary pretty-print names.
They are visible artifacts of the generic relooper rendering protocol.
A future port should expect similar helper structure before later cleanup passes simplify it.

## Visible boilerplate family: helper label local

Many outputs gain an extra `i32` local even when the source did not obviously need one.
That local is the generic `RelooperBuilder` label variable for multiple-entry dispatch.
It is normal here.

## Preserved / no-op family: already-simple flat sequencing

If the flat CFG is already simple to structure, `rereloop` may mostly preserve it.
The pass is not trying to maximize novelty.
It is trying to produce valid structured wasm from the temporary CFG.

## Bailout family: non-flat value-carrying control flow

### Bad input idea

```wat
(i32.add
  (if (cond) (then ...) (else ...))
  (i32.const 1))
```

### Why it is out of scope

This is flatten's job first.
`flat.h` requires such control values to be spilled away before `rereloop` runs.

## Bailout family: EH instructions

### Bad input idea

```wat
(try
  (do ...)
  (catch_all ...))
```

### Why it is out of scope

`ReReloop.cpp` hard-fails on `Try`, `Throw`, and `Rethrow`.
This is not a no-op boundary; it is an explicit unsupported surface.

## Bailout family: relying on exact source-like reconstruction

Even valid flat input does not imply Binaryen will reconstruct the same block nesting or label spelling.
The pass preserves behavior, not source authorship aesthetics.

## Porting summary

A future Starshine port should preserve these WAT-level expectations:

- `rereloop` expects already-flat input
- it can introduce helper blocks and helper names
- it can introduce a helper `i32` label local
- it often rewrites flat branch ladders into visibly different but equivalent structured nests
- it does not support EH in the reviewed `version_129` contract

## Sources

- [`../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md`](../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md)
- [`../../../raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md`](../../../raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0183-2026-04-21-rereloop-binaryen-research.md`](../../../raw/research/0183-2026-04-21-rereloop-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_rereloop.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/opt_flatten.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReReloop.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
