---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` tuple-made loop result refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's `Loop` path removes a concrete loop result by storing the body value in a fresh temp, erasing the loop result type, and leaving a read outside the loop. For a multivalue tuple, generic postorder flattening preserves component order before tuple construction; typed loop parameters and backedge traffic remain a separate channel from the loop result temp. The owner's non-nullability TODO keeps nondefaultable tuple result lanes out of local materialization.

## Direct v130 probe

The ignored probe `.tmp/flatten-probes/tuple-loop-result.wat` uses a typed loop with parameters `(i32, i64)`, results `(f32, f64)`, an independently scalar conditional backedge, and one tuple-made result tail over ordered `f32.add` and `f64.add` components. Its output is `.tmp/flatten-probes/tuple-loop-result.out.wat`.

`wasm-opt version 130 --all-features --flatten -S` confirms:

- parameter/backedge tuple traffic is routed before result computation;
- result component work remains ordered `f32` then `f64`;
- the result tuple is captured after its components and before leaving the loop;
- the final return reads result traffic distinct from loop parameter traffic.

## Local interpretation

HOT scalar result consumers repeat a multivalue control id, while an internal `TupleMake` tail remains one region root. Starshine now admits one exact exclusively owned tuple-made inputful-loop result tail when the tuple's defaultable component vector exactly matches loop results, each component has a supported scalar origin, the tuple is the sole tail root use, loop entry/backedge preflight is already safe, and the loop's outer result consumer span is exclusive.

Before final result routing, ordinary operand flattening spills rich tuple components in source order. The tuple shell is then replaced by ordered writes into a fresh result-local vector, distinct from existing loop entry locals; loop result and label arity are cleared, outer repeated control uses become matching result-local reads, and each component remains evaluated once. Shared/non-tail tuples, mismatched or nondefaultable results, unsupported component origins, nested ownership, and richer producer forms remain fail-closed.
