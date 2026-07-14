---
kind: source
status: reviewed
last_reviewed: 2026-07-14
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-14-flatten-version-130-multivalue-try-two-block-ten-if-table-tuple-refresh.md
  - ./2026-07-14-flatten-version-130-multivalue-try-block-ten-if-table-tuple-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` tuple-made multivalue legacy-try unbounded enclosing-if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`
- Captured owner SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`

## Source-backed rule

Binaryen's `Switch` owner stages one concrete tuple payload before selector work and writes it to every unique break target. Postorder `Try`, `Block`, and `If` handling route the selected tuple through every directly enclosing value-control result. Neither path contains a target-count, block-count, or if-count policy. Count-specific Starshine admission therefore has no Binaryen semantic basis once strict ancestry, target completeness, tuple ownership, type, terminal-placement, one-evaluation, and deletion proofs are already count-independent.

## Direct v130 probes

The ignored `.tmp/flatten-probes/multivalue-try-eleven-if-table-tuple-payload.wat` probe places an `(i32, i64)` legacy try inside eleven matching value ifs. The ignored `.tmp/flatten-probes/multivalue-try-three-block-thirty-two-if-table-tuple-payload.wat` stress probe places the try inside three matching value blocks followed by thirty-two matching value ifs. Each terminal table targets the complete strict direct-enclosure chain and repeats the try as default. Matching `.out.wat` files were produced by the explicit `wasm-opt version 130` binary with `--all-features --flatten -S`.

Both outputs confirm ordered component evaluation, one tuple staging point before selector work, one distinct channel per unique target, catch routing, every selected outward block/if copy, independent else routing at every if level, payload removal, and final tuple flow. The thirty-two-if result demonstrates that the upstream rule is structural rather than tied to a small representative count.

## Local red-first generalization

The existing eleven-if fail-closed boundary was converted into a positive and a new three-block-plus-thirty-two-if stress positive was added. Both failed unchanged at `142/144` behind the temporary `if_count <= 10` admission cap. Removing the `if_count` counter and cap made both pass through the existing structural policy without adding per-count transformation logic.

The admitted repeated-HOT-`TupleMake` family is now one terminal legacy-try table targeting either an arbitrary strict directly enclosing matching block-only chain, or zero or more matching blocks followed by one or more directly enclosing matching value ifs with all ifs outermost. Exact target completeness, direct ancestry, terminal placement, exclusive tuple ownership, component provenance and types, defaultability, one evaluation, distinct per-label channels, safe tuple-shell deletion, Flat IR classification, and verification remain mandatory.

Reverse if-inside-block ancestry, loops or other target kinds, skipped ancestry, extra try labels, arbitrary whole-tuple producers, shared or mixed ownership, nonterminal tables, nondefaultable lanes, typed catch payloads, and exceptional-transfer repair remain gated. The current direct-ancestry helper repeatedly scans remaining target controls and is approximately quadratic in target count; this is a performance-signoff concern, not a reason to restore a semantic count cap or add count-specific source branches.
