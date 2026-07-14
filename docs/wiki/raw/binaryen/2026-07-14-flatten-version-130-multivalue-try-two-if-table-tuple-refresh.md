---
kind: source
status: reviewed
last_reviewed: 2026-07-14
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-14-flatten-version-130-multivalue-try-two-if-table-refresh.md
  - ./2026-07-13-flatten-version-130-multivalue-try-if-table-tuple-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` tuple-made multivalue legacy-try plus two enclosing-if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's `Switch` owner stages one concrete tuple payload once before selector work and copies it into every unique target temp. Postorder legacy-`Try` and value-`If` handling route that concrete tuple through the try result and each directly enclosing selected if result. The source has no special target-count restriction for tuple switch payloads.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-two-if-table-tuple-payload.wat` probe places an `(i32, i64)` legacy try in the then arm of one matching value if, itself in the then arm of a second matching value if. Its terminal table targets the try, inner if, and outer if, with the try repeated as default. The matching `.out.wat` was produced with the explicit Binaryen `wasm-opt version 130` binary and `--all-features --flatten -S`.

The output confirms ordered first-lane then second-lane evaluation, one tuple staging point before selector work, distinct try/inner-if/outer-if channels, catch routing through the try channel, selected fallthrough copies through both ifs, independent else routing at both levels, payload removal, and final tuple flow.

## Local admission

A verifier-backed repeated-HOT-`TupleMake` fixture failed unchanged at `115/116` behind the one-if tuple policy. Starshine now admits exactly the no-block roster containing the try plus two directly enclosing matching value ifs. Every payload slot must reference the same exclusively owned tuple; ordered scalar components must exactly match defaultable target vectors and supported origins; the table must be terminal; and the target ancestry must be direct and complete.

The implementation scalarizes components once in source order, writes distinct staging and per-label vectors before selector work, routes catch and both selected outward copies, preserves both independent else vectors, clears table/control arity, and deletes the tuple shell only after full ownership and target preflight.

Mixed block-plus-two-if rosters, three-or-more if targets, reverse ancestry, loops, skipped ancestry, arbitrary whole-tuple producers, shared or mixed ownership, nonterminal tables, nondefaultable lanes, typed catch payloads, and exceptional-transfer repair remain gated.
