---
kind: source
status: reviewed
last_reviewed: 2026-07-14
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-14-flatten-version-130-multivalue-try-two-if-table-tuple-refresh.md
  - ./2026-07-14-flatten-version-130-multivalue-try-two-block-if-table-tuple-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` tuple-made multivalue legacy-try plus block and two enclosing-if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen stages one concrete tuple `Switch` payload before selector work and copies it into every unique break target. Postorder `Try`, `Block`, and `If` handling then route the selected tuple through each directly enclosing value-control result. The owner has no block-count versus if-count distinction.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-block-two-if-table-tuple-payload.wat` probe places an `(i32, i64)` legacy try directly inside a matching value block, itself in the then arm of a matching inner value if inside a matching outer value if. Its terminal table targets the try, block, inner if, and outer if, with the try repeated as default. The matching `.out.wat` was produced by the explicit `wasm-opt version 130` binary with `--all-features --flatten -S`.

The output confirms ordered component evaluation, one tuple staging point before selector work, distinct try/block/inner-if/outer-if channels, catch routing, all three selected outward fallthrough copies, independent else routing at both if levels, payload removal, and final tuple flow.

## Local admission

A verifier-backed repeated-HOT-`TupleMake` fixture failed unchanged at `116/117` behind the exact no-block two-if policy. Starshine now admits exactly the two-if roster containing zero or one directly enclosing matching block before the if chain. The table remains terminal, ancestry remains direct and complete, every payload slot references the same exclusively owned tuple, and ordered supported defaultable components exactly match every target vector.

The implementation scalarizes each component once in source order, writes distinct staging and per-label vectors before selector work, routes catch and every selected outward copy, preserves both independent else vectors, clears table/control arity, and deletes the tuple shell only after full ownership and target preflight.

Two-or-more-block plus two-if rosters, three-or-more if targets, reverse ancestry, loops, skipped ancestry, arbitrary whole-tuple producers, shared or mixed ownership, nonterminal tables, nondefaultable lanes, typed catch payloads, and exceptional-transfer repair remain gated.
