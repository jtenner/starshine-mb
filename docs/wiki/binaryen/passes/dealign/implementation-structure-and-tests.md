---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeAlign.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dealign.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./align-one-rewrite-surface-and-alignment-lowering-split.md
  - ./wat-shapes.md
---

# `dealign`: implementation structure and tests

This page is the compact source-confirmed map of which Binaryen files own `dealign` and which shipped tests prove its behavior.

## File map

| File | Why it matters | Durable lesson |
| --- | --- | --- |
| `src/passes/DeAlign.cpp` | Main implementation | Nearly the entire contract lives here: a tiny helper walker plus a tiny module-pass wrapper. |
| `src/passes/pass.cpp` | Public registration | Confirms that `dealign` is a real public pass name and not a private helper. |
| `test/lit/passes/dealign.wast` | Dedicated behavioral oracle | Proves the visible scalar `align -> 1` rewrite surface, the already-`align=1` no-op rule, and offset preservation. |
| current `main` `src/passes/DeAlign.cpp` and `test/lit/passes/dealign.wast` | Narrow freshness spot check | The reviewed current-`main` surfaces still matched the tagged `version_129` lines inspected for this dossier. |

## `DeAlign.cpp`

This file contains almost everything important.

What it defines:

- helper walker `DeAlignFunction : PostWalker<DeAlignFunction>`
- four visitors: `visitLoad`, `visitStore`, `visitSIMDLoad`, `visitSIMDStore`
- helper `dealign(Address& align)`
- module pass `DeAlign`
- `createDeAlignPass()`

What it proves:

- the pass mutates only alignment metadata
- only the four listed access families are in direct scope
- the rewrite rule is literally `if (align > 1) align = 1`
- the pass bails out if the module has no memory
- the pass iterates defined functions rather than trying to mutate module-level memory structures

## `pass.cpp`

This file proves two things.

### 1. Public identity

`dealign` is a real public pass name.
It is not just an implementation helper tucked behind another pass.

### 2. Public summary text

The registration description says:

- `force all loads and stores to have align=1`

That summary is helpful, but slightly broader-sounding than the exact visitor surface.
The main implementation file is still needed to learn that the real direct scope is:

- scalar loads/stores
- SIMD loads/stores

and not every memory instruction family.

## `dealign.wast`

This is the main proof surface.

What it directly proves:

### Scalar positives

The file contains larger-alignment ordinary loads and stores that print back out as `align=1`.
That includes common scalar widths and types such as:

- `i32`
- `i64`
- `f32`
- `f64`

### Already-weak no-op cases

The same file includes accesses already using `align=1`.
Those remain unchanged.

### Offset preservation

The printed output changes alignment immediates without changing the visible offsets.
So the pass is not re-associating address arithmetic.

## Test-surface caveat: SIMD

The reviewed implementation clearly includes `visitSIMDLoad` and `visitSIMDStore`.
However, the dedicated `dealign.wast` file is much more obviously scalar-focused than SIMD-focused.

So the honest proof split is:

- scalar surface: directly lit-backed
- SIMD surface: source-confirmed from `DeAlign.cpp`, but not as strongly isolated by a visible dedicated lit example in the reviewed file

That distinction is worth preserving in the docs because the pass is so small that it would be easy to overstate test coverage.

## Best reading order for future work

If someone needs to port or verify `dealign`, the fastest reliable reading order is:

1. `src/passes/DeAlign.cpp`
2. `test/lit/passes/dealign.wast`
3. `src/passes/pass.cpp`

That is enough to recover almost the whole contract.

## Porting checklist

A future port should preserve these source-backed obligations:

- public name: `dealign`
- module-memory existence bailout
- defined-functions-only walk
- visitor surface limited to `Load`, `Store`, `SIMDLoad`, `SIMDStore`
- exact `align > 1` rewrite rule
- already-`align=1` no-op behavior
- preserved offsets, types, widths, and child expressions
- explicit distinction from `alignment-lowering`

## Sources

- [`../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md`](../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeAlign.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dealign.wast>
