---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-multivalue-try-two-block-table-refresh.md
  - ./2026-07-13-flatten-version-130-multivalue-try-block-table-tuple-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` tuple-made multivalue legacy-try plus two-block table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's `Switch` owner stages one concrete tuple payload before selector work and copies it to every unique label temp without a target-count special case. Postorder handling then erases the legacy `Try`, inner `Block`, and outer `Block` through distinct tuple locals. Catch feeds the try channel, and each ordinary fallthrough copies the selected tuple outward exactly once.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-two-block-table-tuple-payload.wat` probe places an `(i32, i64)` legacy try inside two nested matching blocks. Its terminal table targets the try, inner block, and outer block, with the try repeated as default. The `.out.wat` output from the explicit Binaryen v130 `wasm-opt --all-features --flatten -S` binary confirms ordered component evaluation, one tuple staging point before selector work, three distinct target assignments, payload removal, catch-to-try routing, and two outward fallthrough copies.

## Local admission

Starshine now admits the same strict three-target direct-enclosure roster for one exclusively owned repeated HOT `TupleMake`. Every payload slot must reference that tuple, its ordered scalar components must exactly match the defaultable target vector and have supported origins, and the table must pass the existing terminal legacy-try plus direct block-chain preflight. Components scalarize once in source order, then copy from separate staging locals into distinct try, inner-block, and outer-block vectors before selector work. The tuple shell is deleted only after complete ownership and target preflight.

This does not admit more than three unique targets, skipped or non-direct ancestry, non-block secondary targets, shared or mixed tuple ownership, arbitrary whole-tuple producers, nondefaultable lanes, typed catch payloads, or exceptional-transfer repair.
