---
kind: source
status: reviewed
last_reviewed: 2026-07-14
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-14-flatten-version-130-multivalue-try-four-if-table-tuple-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` tuple-made multivalue legacy-try plus five enclosing-if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`
- Captured owner SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`

## Source-backed rule

Binaryen v130 `Switch` handling stages one concrete tuple payload before selector work and copies it to every unique break-target temp. Postorder legacy-`Try` and value-`If` handling then route the selected tuple through each directly enclosing value-control result. The owner has no tuple target-count restriction.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-five-if-table-tuple-payload.wat` probe places an `(i32, i64)` legacy try in the selected arm of five directly enclosing matching value ifs. Its terminal table targets the try and all five ifs, with the try repeated as default. The matching `.out.wat` was produced with the explicit `wasm-opt version 130` binary and `--all-features --flatten -S`.

The output confirms first-lane then second-lane evaluation, one tuple staging point before selector work, six distinct target channels, catch routing through the try channel, selected fallthrough copies through all five ifs, independent else routing at every level, payload removal, and final tuple flow.

## Local admission

A verifier-backed repeated-HOT-`TupleMake` fixture failed unchanged at `124/125` behind the four-if tuple gate. Starshine now admits exactly the no-block roster containing the try plus five directly enclosing matching value ifs. The table remains terminal; ancestry must be direct and complete; every payload slot must reference the same exclusively owned tuple; and ordered supported defaultable components must exactly match every target vector.

The implementation scalarizes components once in source order, writes distinct staging and per-label vectors before selector work, routes catch and all five selected outward copies, preserves all independent else vectors, clears table/control arity, and deletes the tuple shell only after complete ownership and target preflight.

Block-plus-five-if rosters, six-or-more if targets, reverse ancestry, loops, skipped ancestry, arbitrary whole-tuple producers, shared or mixed ownership, nonterminal tables, nondefaultable lanes, typed catch payloads, and exceptional-transfer repair remain gated.
