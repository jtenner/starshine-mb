---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/test/lit/passes/flatten-eh-legacy.wast
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` tuple-made legacy-try tail refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`
- Legacy-EH proof: `test/lit/passes/flatten-eh-legacy.wast`

## Source-backed rule

Binaryen's legacy `Try` path removes a concrete result by allocating one result temp, writing every concrete do/catch body into that temp, erasing the try result, and leaving a read outside. Generic postorder flattening preserves tuple component order before tuple construction. The function-final `EHUtils::handleBlockNestedPops(...)` repair remains mandatory for real typed catch payloads, but branch-free synthetic do/catch regions without represented `Pop`, `Catch`/`CatchAll`, `rethrow`, or `delegate` do not need that missing repair surface.

## Direct v130 probes

The ignored probes `.tmp/flatten-probes/tuple-try-results.wat` and `.tmp/flatten-probes/tuple-try-tail.wat` use a branch-free legacy try with `(i32, i64)` results and two result-producing arms. Their outputs are the matching `.out.wat` files produced by:

```text
wasm-opt version 130 --all-features --flatten -S
```

The probes confirm:

- do-arm result work stays before the do-arm result write;
- catch-arm result work stays inside the catch arm before its result write;
- both arms feed one shared tuple-typed Binaryen result temp;
- the try becomes void and the outer return reads the shared result channel;
- catch payload repair is a separate concern from branch-free result routing.

## Local interpretation

HOT represents a tuple-producing `TupleMake` as one node even where result consumers repeat a multivalue control id across scalar slots, while body locals remain scalar `ValType` slots. Starshine therefore admits the exact scalar-local correspondence only when both legacy-try arms end in separately owned `TupleMake` nodes whose ordered defaultable scalar components exactly match the try result vector, each tuple is the sole tail root use of its region, the outer try result span is exclusive, and the existing EH prerequisite classifier is clear.

The tuple shells are replaced by ordered writes into one shared typed scalar-local vector, the try result and label arity are cleared, outer repeated uses become matching reads, and each component is evaluated once. Mixed tuple/scalar arms, rich tuple components, shared/non-tail tuples, nondefaultable lanes, represented typed catch payloads, and exceptional transfers remain fail-closed in this slice.
