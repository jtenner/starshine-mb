---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-scalar-try-three-block-table-refresh.md
  - ./2026-07-13-flatten-version-130-multivalue-try-two-block-table-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` multivalue legacy-try plus three-block table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's `Switch` owner stages one concrete tuple payload before selector work and copies it to every unique target without a target-count special case. Distinct break temps preserve each label channel, and postorder handling erases the legacy `Try` and every enclosing `Block` independently.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-three-block-table-targets.wat` probe places an `(i32, i64)` legacy try inside three nested matching blocks. Its terminal table targets the try and all three blocks, with the try repeated as default. The `.out.wat` output from the explicit Binaryen v130 `wasm-opt --all-features --flatten -S` binary confirms ordered component evaluation, one tuple staging point before selector work, four distinct target assignments, payload removal, catch-to-try routing, and three outward fallthrough copies.

## Local admission

Starshine now admits independently scalar defaultable lanes through the same ancestry-driven strict direct-enclosure chain as the scalar helper, without a hardcoded target-count cap. Every payload component must remain an independent exact scalar producer with a supported origin. Components stage once in source order, copy into distinct try and per-block target vectors before selector work, and preserve separate catch and outward fallthrough channels before all table/control arity is erased.

The multivalue helper still detects and rejects an exclusively repeated HOT `TupleMake` when the roster exceeds three unique targets. That leaves the source-backed independently scalar widening separate from the tuple ownership policy proved only through the try plus two directly enclosing blocks.

This does not admit more-than-three-target tuple payloads, shared or mixed tuples, arbitrary whole-tuple producers, skipped or non-direct ancestry, non-block secondary targets, multiple try labels, nonterminal tables, nondefaultable lanes, typed catch payloads, or exceptional-transfer repair.
