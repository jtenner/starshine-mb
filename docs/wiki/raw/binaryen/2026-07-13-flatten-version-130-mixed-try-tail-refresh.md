---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-tuple-try-tail-refresh.md
  - ./2026-07-13-flatten-version-130-tuple-try-rich-tail-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` mixed legacy-try tail refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen handles the legacy `Try` body and every catch body independently. Each concrete region result is wrapped in a write to one shared result temp; the owner does not require all arms to have the same internal producer shape, only a concrete result compatible with the try type. Postorder child preludes remain owned by the region that produced them.

The same source still requires function-final `EHUtils::handleBlockNestedPops(...)` when represented catch payload pops exist and still carries the non-nullability limitation for values that cannot safely enter locals.

## Direct v130 probe

The ignored `.tmp/flatten-probes/tuple-try-mixed-tail.wat` probe combines separately produced scalar do-arm components with one multivalue call in the catch arm. Its `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` confirms that distinct arm producer shapes are independently flattened and then copied into one shared tuple-typed result channel before the try becomes void.

## Local interpretation

At HOT's scalar-local boundary, Starshine may mix one exact separately owned `TupleMake` tail with one exact independently scalar region tail when both represent the same ordered defaultable result vector, every tuple component has a supported scalar origin, the try's repeated outer result span is exclusive, and the EH prerequisite classifier is clear. Each region follows its own route into the same typed scalar-local vector: rich tuple components spill once before tuple-shell deletion, while independently scalar tails are replaced directly by ordered local writes.

This does not admit arbitrary multivalue single producers such as a call returning the whole tuple, shared/non-tail tuple ownership, branch-targeted try labels, nondefaultable lanes, represented typed catch payloads, or exceptional transfers.
