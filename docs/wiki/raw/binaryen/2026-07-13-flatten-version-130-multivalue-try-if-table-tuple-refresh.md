---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-multivalue-try-if-table-refresh.md
  - ./2026-07-13-flatten-version-130-multivalue-try-three-block-table-tuple-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` tuple-made multivalue legacy-try plus enclosing-if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's `Switch` owner stages one concrete tuple payload once before selector work and copies it into every unique target temp. Postorder legacy-`Try` handling routes do/catch tuples through the try temp, while postorder `If` handling routes both arm tuples through the if-result temp. The switch, try, and if owners do not distinguish whether the concrete tuple was assembled from independently represented scalar lanes in Starshine HOT.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-if-table-tuple-payload.wat` probe places an `(i32, i64)` legacy try directly in the then arm of a matching value if. Its terminal table targets the try and if, with the try repeated as default. The `.out.wat` output from the explicit Binaryen v130 `wasm-opt --all-features --flatten -S` binary confirms ordered component evaluation, one tuple staging point before selector work, distinct try and if target assignments, payload removal, catch-to-try routing, selected-arm try-to-if fallthrough copying, independent else-arm routing, and final tuple flow.

## Local admission

Starshine now admits one exclusively owned repeated HOT `TupleMake` for exactly the existing try-plus-one-directly-enclosing-if roster. Every payload slot must reference the same tuple, its ordered scalar components must exactly match the defaultable target vector and have supported origins, the table must be terminal, and the unique targets must be exactly the try and its directly enclosing matching value if. Components scalarize once in source order into staging, try, and if vectors before selector work. Catch writes the try vector, selected-arm fallthrough copies try to if, the other arm writes the if vector independently, and the tuple shell is deleted only after complete ownership and target preflight.

This does not admit block-plus-if chains, multiple if targets, skipped or unrelated ancestry, loops, multiple try labels, shared or mixed tuple ownership, arbitrary whole-tuple producers, nonterminal tables, nondefaultable lanes, typed catch payloads, or exceptional-transfer repair.
