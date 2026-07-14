---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-multivalue-try-three-block-table-refresh.md
  - ./2026-07-13-flatten-version-130-multivalue-try-two-block-table-tuple-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` tuple-made multivalue legacy-try plus three-block table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's `Switch` owner stages one concrete tuple payload before selector work, iterates every unique target without a count limit, and copies the staged tuple into each target temp. Postorder control handling then erases the legacy `Try` and every directly enclosing matching `Block` through distinct tuple locals. Catch writes the try channel, and each ordinary fallthrough copies the selected tuple to the next outward channel exactly once.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-three-block-table-tuple-payload.wat` probe places an `(i32, i64)` legacy try inside three nested matching blocks. Its terminal table targets the try, inner block, middle block, and outer block, with the try repeated as default. The `.out.wat` output from the explicit Binaryen v130 `wasm-opt --all-features --flatten -S` binary confirms ordered component evaluation, one tuple staging point before selector work, four distinct target assignments, payload removal, catch-to-try routing, and three outward fallthrough copies.

## Local admission

Starshine now removes the arbitrary unique-target cap for one exclusively owned repeated HOT `TupleMake` when the table passes the existing complete strict direct-enclosure-chain preflight. Every payload slot must reference that tuple, its ordered scalar components must exactly match the defaultable target vector and have supported origins, and every non-try target must be a directly enclosing matching block. Components scalarize once in source order, then copy from staging locals into distinct try and per-block vectors before selector work. The tuple shell is deleted only after complete ownership and target preflight.

This does not admit skipped or non-direct ancestry, non-block secondary targets, multiple try labels, shared or mixed tuple ownership, arbitrary whole-tuple producers, nonterminal tables, nondefaultable lanes, typed catch payloads, or exceptional-transfer repair.
