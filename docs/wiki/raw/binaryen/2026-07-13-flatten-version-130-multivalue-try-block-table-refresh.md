---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-multivalue-try-table-refresh.md
  - ./2026-07-13-flatten-version-130-scalar-try-block-table-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` multivalue legacy-try plus block table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen treats a concrete multivalue payload as one tuple value in the `Switch` owner, stages it before selector work, and copies it to every unique break target temp. The enclosing legacy `Try` and `Block` then erase their result types through separate tuple channels. HOT expands that tuple correspondence into ordered scalar slots, so local admission must preserve exact vector types, one-evaluation order, and exclusive repeated-control ownership.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-block-table-targets.wat` probe places an `(i32, i64)` legacy try inside an `(i32, i64)` block. Its terminal table targets the try and directly enclosing block, with the try repeated as default. Its `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` confirms component-before-selector order, one staged tuple, distinct try and block target assignments, payload removal, void try/block outputs, catch-to-try routing, and try-fallthrough-to-block copying.

## Local interpretation

Starshine admits the corresponding independently scalar HOT vector when the try has one exclusive repeated consumer span either in an ordinary parent or as the direct enclosing block tail, the table is terminal in a try arm, the only unique targets are that try and block, every lane is exact and defaultable, each payload component has a supported scalar origin, and both target preflights succeed. Components stage once in source order, then copy into distinct try-result and block-result vectors before selector work. The try tail is routed into the block vector only on fallthrough.

This does not admit tuple-made mixed-target table payloads, additional block/if/loop/try targets, nonterminal tables, mismatched or nondefaultable vectors, arbitrary whole-tuple producers, represented typed catch payloads, or exceptional-transfer repair.
