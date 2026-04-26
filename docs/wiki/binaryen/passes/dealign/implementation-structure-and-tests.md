---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-dealign-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-dealign-primary-sources.md
  - ../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md
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
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
supersedes:
  - ../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md
---

# `dealign`: implementation structure and tests

This page maps the exact upstream owner files and proof surface for Binaryen `dealign`.

## File map

| File | Why it matters | Durable lesson |
| --- | --- | --- |
| `src/passes/DeAlign.cpp` | Main implementation | Owns the whole transform: a `WalkerPass<PostWalker<DeAlign>>`, function-parallel flag, three visitors, and direct `align = 1` assignments. |
| `src/passes/pass.cpp` | Public registration | Confirms `dealign` is a public pass name and records Binaryen's short help text. |
| `test/lit/passes/dealign.wast` | Dedicated behavioral oracle | Proves the visible scalar `i32.load` / `i32.store` alignment rewrite and idempotent `align=1` cases. |
| current `main` `DeAlign.cpp`, `pass.cpp`, and `dealign.wast` | Narrow freshness recheck | No teaching-relevant drift was found on the reviewed surfaces in the 2026-04-26 port-readiness refresh. |

## `DeAlign.cpp`

The reviewed file defines:

- `struct DeAlign : public WalkerPass<PostWalker<DeAlign>>`
- `isFunctionParallel()` returning `true`
- `visitLoad(Load* curr)`
- `visitStore(Store* curr)`
- `visitSIMDLoad(SIMDLoad* curr)`
- `createDeAlignPass()`

The three visitors each set the node's alignment field to `1`.

What this proves:

- the pass is a function walker, not a hand-written module loop
- there is no explicit no-memory bailout in this source file
- the direct source surface is `Load`, `Store`, and `SIMDLoad`
- there is no direct `SIMDStore` visitor in reviewed `version_129`
- the pass mutates only alignment metadata

## `pass.cpp`

`pass.cpp` proves the public identity:

- `dealign`

and carries the short user-facing description that the pass forces loads and stores to have `align=1`.

That registration text is a useful summary, but `DeAlign.cpp` is the authority for exact visitor coverage.

## `dealign.wast`

The dedicated lit file directly proves the scalar surface that users will most often notice.

### Scalar positives

The file includes `i32.load` and `i32.store` cases whose printed output uses `align=1` after the pass.

### Explicit stronger alignment

The file includes explicit `align=2` scalar cases that become `align=1`.

### Idempotent already-weak cases

The file includes explicit `align=1` cases that remain `align=1`.

### Offset and child preservation

The visible output changes alignment immediates without changing address children, offsets, or stored values.

## Proof-surface caveats

The earlier 2026-04-21 research note overstated the proof surface. The corrected split is:

- scalar `i32.load` / `i32.store`: directly lit-backed
- other scalar widths/types: plausible from shared `Load` / `Store` source visitors, but not individually isolated in the reviewed lit file
- `SIMDLoad`: source-confirmed from `DeAlign.cpp`, not visibly isolated by the reviewed lit file
- `SIMDStore`: not present in reviewed `DeAlign.cpp`

This distinction matters because the pass is tiny; over-broad test claims can mislead future ports.

## Best reading order for future work

1. `src/passes/DeAlign.cpp`
2. `test/lit/passes/dealign.wast`
3. `src/passes/pass.cpp`
4. `docs/wiki/binaryen/passes/dealign/starshine-strategy.md`
5. `docs/wiki/binaryen/passes/dealign/starshine-port-readiness-and-validation.md`

That path recovers both the upstream mechanics and the current in-repo status.

## Porting checklist

A future Starshine port should preserve:

- public spelling: `dealign`
- no registry exposure until the implementation actually exists
- function-body walk over the source-backed visitor surface
- direct alignment assignment to `1`
- preserved offsets, widths, signedness, child expressions, value flow, and control flow
- no chunk-splitting
- explicit sibling split from `alignment-lowering`
- tests that separately mark lit-backed behavior versus source-confirmed behavior

## Sources

- [`../../../raw/binaryen/2026-04-26-dealign-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-dealign-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-dealign-primary-sources.md`](../../../raw/binaryen/2026-04-24-dealign-primary-sources.md)
- [`../../../raw/research/0389-2026-04-26-dealign-port-readiness.md`](../../../raw/research/0389-2026-04-26-dealign-port-readiness.md)
- [`../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md`](../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeAlign.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dealign.wast>
