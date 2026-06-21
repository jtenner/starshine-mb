---
kind: research
status: supported
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0790-2026-06-20-heap-store-optimization-explicit-non-goals.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/HeapStoreOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/heap-store-optimization.wast
---

# HSO unreachable no-fold boundary coverage

Question: does Starshine lock Binaryen `version_130`'s explicit `heap-store-optimization` boundary for unreachable constructor or set-value pairs?

## Answer

Yes, as focused coverage. Binaryen `HeapStoreOptimization.cpp` rejects pairs when either the fresh `struct.new*` or the `struct.set` is typed unreachable, leaving the cleanup to later DCE rather than updating types inside HSO. The dedicated lit file has an `$unreachable` case for both sides of that boundary.

This slice added Starshine focused tests that keep the same boundary visible:

- `heap-store-optimization leaves unreachable constructors to later DCE`
  - uses a `struct.new` operand rooted in `unreachable`;
  - expects the later `struct.set` and stored constant to remain.
- `heap-store-optimization leaves unreachable set values to later DCE`
  - uses a block-valued set operand whose body is `unreachable`;
  - expects the `struct.set`, constructor value, and `unreachable` to remain.

The set-value fixture intentionally uses a block wrapper instead of a direct root `unreachable` operand. A direct root `unreachable` set-value shape currently exposes local HOT lowering/decode surface roughness during final validation after a mutation elsewhere in the function, so the focused HSO boundary test uses a valid local representation that still exercises the pass's no-fold behavior. This is not accepted as a semantic HSO non-goal; it is a local fixture-surface limitation to revisit if exact Binaryen lit-shape replay becomes necessary.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `72/72` passed.

No implementation behavior changed in this coverage-only slice; the ordinary memory/table blocker behavior change remains covered by `0791`.

## Remaining risk

Follow-up `0868` finalized the unreachable-boundary wording with a direct-root Binaryen `version_130` probe. The semantic HSO boundary is covered: unreachable constructor/set-value pairs stay no-fold and are left to later DCE. The direct-root set-value fixture limitation remains a local HOT/test-surface caveat, not an accepted HSO semantic non-goal. HSO-H still remains open for exact-cast local surface limits and descriptor `br_on_non_null` HOT CFG/verifier surface limits, plus the direct-root fixture caveat if exact lit-shape replay becomes necessary.
