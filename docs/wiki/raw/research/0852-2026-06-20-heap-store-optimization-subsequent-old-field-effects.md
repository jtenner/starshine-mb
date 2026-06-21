---
kind: research
status: supported
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/heap-store-optimization.wast
---

# `heap-store-optimization` subsequent old-field effects

Question: does Starshine explicitly cover Binaryen's `version_130` `$side-effect-subsequent-ok` family where a later `struct.set(local.get)` replaces a constructor field while an earlier, unreplaced constructor field still has side effects?

## Answer

Yes after this coverage slice.

Binaryen's dedicated `version_130` lit has `$side-effect-subsequent-ok`: a `local.set(struct.new ...)` constructor initializes field `0` with a side-effecting call and field `1` with a plain constant, then a later `struct.set` replaces field `1` with another side-effecting call. Binaryen folds the later store into the constructor, preserving both calls in constructor operand order and removing the redundant `struct.set`.

Starshine already matched this behavior, but the local old-field side-effect coverage was mostly tee-shaped. This slice added the focused subsequent-chain test:

- `heap-store-optimization folds subsequent call store when only earlier field has effects`

The test proves the local-set/later-struct-set path folds the later call into `struct.new`, preserves the earlier call, and removes `struct.set`.

## Classification

- Slice type: coverage-only HSO-D progress.
- Binaryen behavior family: source/lit-backed subsequent-chain old-field side-effect preservation.
- Starshine result: already matched Binaryen.
- Implementation change: none.
- Direct compare: not run because no pass behavior changed; the focused HSO test was enough for this coverage-only slice.

## Command

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 204, passed: 204, failed: 0.
```

## Remaining HSO-D work

This only closes the subsequent-chain old-field side-effect variant for plain `struct.new`. HSO-D remains open for arbitrary descriptor expressions, remaining later-field directional barriers, broader default/descriptor old-field combinations, and broader old-field side-effect negatives.
