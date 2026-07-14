---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-tuple-try-tail-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` rich tuple-made legacy-try tail refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen walks expression children postorder before applying the legacy `Try` result rewrite. Rich tuple components therefore become ordered preludes first, tuple construction remains after those component computations, and each concrete do/catch result is then written into the shared try-result temp. This order preserves effects and traps inside the selected region and does not move catch-only work into the do path.

The owner's non-nullability TODO still excludes tuple lanes that cannot be represented safely in locals. Function-final nested-pop repair remains a separate requirement whenever real typed catch payloads are present.

## Direct v130 evidence

The ignored `.tmp/flatten-probes/tuple-try-tail.wat` probe uses separate scalar calls for the `(i32, i64)` do and catch result components. Its `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` confirms that:

- do components execute in source order inside the do region;
- catch components execute in source order inside the catch region;
- each tuple is built only after its components;
- both arm results feed one shared result channel;
- the try becomes void before the final return reads that channel.

## Local interpretation

Starshine may scalarize the tuple-local representation at the HOT boundary when both arms have exact separately owned tuple tails and every ordered component has one scalar defaultable result with a supported non-control origin. The whole-function preflight establishes ownership and types before mutation. During ordinary postorder operand rewriting, each rich component is spilled once in source order inside its own region. The tuple shells then contain simple reads and are replaced by writes into the shared typed result-local vector.

Mixed tuple/scalar arms were subsequently admitted under the same per-region ownership/type contract in [`2026-07-13-flatten-version-130-mixed-try-tail-refresh.md`](./2026-07-13-flatten-version-130-mixed-try-tail-refresh.md). Shared/non-tail tuples, unsupported control origins, nondefaultable lanes, represented catch payloads, and exceptional transfers remain fail-closed.
