---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-scalar-try-if-table-refresh.md
  - ./2026-07-13-flatten-version-130-multivalue-try-three-block-table-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` multivalue legacy-try plus enclosing-if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen represents a concrete multivalue table payload as one tuple value, stages it once before selector work, and copies it to every unique target temp. Postorder legacy-`Try` handling routes do/catch tuples through the try temp, while postorder `If` handling routes both arm tuples through one if-result temp. The branch target channel and ordinary selected-arm fallthrough remain distinct assignments even when they ultimately feed the same enclosing if result.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-if-table-targets.wat` probe places an `(i32, i64)` result legacy try directly in the then arm of a matching named multivalue if. Its terminal table targets the try and if, with the try repeated as default; the else arm independently produces `(i32, i64)`. The `.out.wat` output from the explicit Binaryen v130 `wasm-opt --all-features --flatten -S` binary confirms ordered component evaluation, one tuple staging point before selector work, distinct try and if target assignments, payload removal, catch-to-try routing, selected-arm try-to-if fallthrough copying, independent else-arm routing, and final tuple result flow.

## Local admission

Starshine now extends the exact try-plus-directly-enclosing-if roster to independently scalar defaultable multivalue lanes. Every payload lane must have the exact target type and supported scalar origin; the try and if must expose matching result vectors with exclusive repeated HOT result ownership; and the table must remain terminal with exactly those two unique labels. Lanes stage once in source order, copy into distinct try and if vectors before selector work, route catch through the try vector, copy selected-arm try fallthrough into the if vector, and route the other arm independently.

This does not admit one repeated HOT `TupleMake` for the if-target roster, arbitrary whole-tuple producers, block-plus-if chains, multiple if targets, unrelated or skipped ancestry, loops, multiple try labels, nonterminal tables, nondefaultable lanes, typed catch payloads, or exceptional-transfer repair.
