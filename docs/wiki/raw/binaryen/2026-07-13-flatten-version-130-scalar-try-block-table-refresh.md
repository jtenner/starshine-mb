---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-scalar-try-table-refresh.md
  - ./2026-07-13-flatten-version-130-switch-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` scalar legacy-try plus block table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's concrete `Switch` path stages one payload before selector work, enumerates unique targets, and copies the staged value into each target's independent break temp. The legacy `Try` and enclosing `Block` owners later erase their result types through those separate channels. A table that can exit either control therefore must not alias the try-result temp with the enclosing-block temp.

## Direct v130 probe

The ignored `.tmp/flatten-probes/scalar-try-block-table-targets.wat` probe places a result-bearing legacy try inside a result-bearing block. Its terminal table has the try label and enclosing block as unique targets, with the try label repeated as default. Its `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` confirms payload-before-selector order, one staging local, distinct try and block target assignments, payload removal, a payload-free terminal table, void try/block outputs, catch-to-try routing, and try-fallthrough-to-block copying.

## Local interpretation

Starshine admits this exact scalar mixed-target family when the table is terminal in a try arm, every unique target is a defaultable scalar block/if or the owning scalar legacy try, all target result types exactly match the payload, the payload has one supported origin, complete target preflight succeeds, and the other try arm has an exact matching fallthrough. The payload is evaluated once, copied into distinct per-label locals before selector work, and removed from the table.

Multivalue mixed-target try tables remain deliberately gated at this slice so they can receive their own red-first ownership and vector-channel proof. Multiple unique try labels, loop targets, nonterminal tables, nondefaultable or mismatched payloads, represented typed catch payloads, and exceptional-transfer repair remain open.
