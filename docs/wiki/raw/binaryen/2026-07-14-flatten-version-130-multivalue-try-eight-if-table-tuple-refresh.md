---
kind: source
status: reviewed
last_reviewed: 2026-07-14
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-14-flatten-version-130-multivalue-try-two-block-seven-if-table-tuple-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` tuple-made multivalue legacy-try plus eight enclosing-if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`
- Captured owner SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`

## Source-backed rule

Binaryen's `Switch` owner stages one concrete tuple payload before selector work and writes it to every unique break target. Postorder `Try` and `If` handling route the selected tuple through every directly enclosing value-control result. The owner has no target-count cap.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-eight-if-table-tuple-payload.wat` probe places an `(i32, i64)` legacy try inside the selected arms of eight matching value ifs. Its terminal table targets the try and all eight ifs, with the try repeated as default. The matching `.out.wat` was produced by the explicit `wasm-opt version 130` binary with `--all-features --flatten -S`.

The output confirms ordered component evaluation, one tuple staging point before selector work, nine distinct target channels, catch routing, all eight selected outward fallthrough copies, independent else routing at every if level, payload removal, and final tuple flow.

## Local admission

The converted eight-if fixture failed unchanged at `135/136` behind the seven-if tuple gate, while explicit one-block-plus-eight-if and nine-if audit boundaries remained fail-closed. The bounded admission now accepts exactly eight directly enclosing matching value ifs only when there are no intervening block targets.

The positive proves ordered scalarization, distinct staging and per-label vectors, selector-after-payload order, catch routing, all eight selected if copies, independent else routing at every level, cleared table/control arity, tuple-shell deletion after complete preflight, Flat IR classification, and verification.

Block-plus-eight-if and nine-or-more-if tuple rosters, reverse ancestry, loops, skipped ancestry, arbitrary whole-tuple producers, shared or mixed ownership, nonterminal tables, nondefaultable lanes, typed catch payloads, and exceptional-transfer repair remain gated.
