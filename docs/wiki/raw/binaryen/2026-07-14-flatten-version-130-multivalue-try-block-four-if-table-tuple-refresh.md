---
kind: source
status: reviewed
last_reviewed: 2026-07-14
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-14-flatten-version-130-multivalue-try-four-if-table-tuple-refresh.md
  - ./2026-07-14-flatten-version-130-multivalue-try-block-three-if-table-tuple-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` tuple-made multivalue legacy-try plus block and four enclosing-if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`
- Captured owner SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`

## Source-backed rule

Binaryen stages one concrete tuple `Switch` payload before selector work and copies it into every unique break-target temp. Postorder `Try`, `Block`, and `If` handling route the selected tuple through each directly enclosing value-control result. The v130 owner does not distinguish this block-plus-four-if composition from shorter direct ancestry chains.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-block-four-if-table-tuple-payload.wat` probe places an `(i32, i64)` legacy try directly inside a matching value block, followed by four directly enclosing matching value ifs. Its terminal table targets the try, block, inner if, middle if, outer if, and outermost if, with the try repeated as default. The matching `.out.wat` was produced with the explicit `wasm-opt version 130` binary and `--all-features --flatten -S`.

The output confirms ordered component evaluation, one tuple staging point before selector work, six distinct target channels, catch routing, all five selected outward fallthrough copies, independent else routing at every if level, payload removal, and final tuple flow.

## Local admission

The prior four-if cap accidentally admitted arbitrary leading block chains before their own red-first audit. A clearly named two-block fail-closed boundary first failed at `122/123`, proving that over-admission. Tightening the four-if roster to no blocks made that boundary green. The new one-block positive then failed unchanged at `123/124`, after which Starshine admitted exactly zero or one directly enclosing matching block before the four-if chain.

Terminal placement, strict complete ancestry, exclusive repeated tuple ownership, exact component provenance and types, defaultability, one evaluation, and tuple deletion after complete preflight remain mandatory. The positive fixture proves ordered scalarization, distinct staging and per-label vectors, selector-after-payload order, catch routing, the block copy and all four selected if copies, independent else routing at every level, cleared table/control arity, Flat IR classification, and verification.

Two-or-more-block plus four-if rosters, five-or-more if targets, reverse ancestry, loops, skipped ancestry, arbitrary whole-tuple producers, shared or mixed ownership, nonterminal tables, nondefaultable lanes, typed catch payloads, and exceptional-transfer repair remain gated.
