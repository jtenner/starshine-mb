---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-scalar-try-block-table-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` scalar legacy-try plus two-block table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's scalar `Switch` owner stages one concrete payload before selector work and copies it through `getTempForBreakTarget(...)` to every unique label. Postorder control handling then erases the legacy `Try`, inner `Block`, and outer `Block` independently, using each label's distinct temp and copying only the selected fallthrough channel outward.

## Direct v130 probe

The ignored `.tmp/flatten-probes/scalar-try-two-block-table-targets.wat` probe places a scalar legacy try inside two nested scalar blocks. Its terminal table targets the try, inner block, and outer block, with the try repeated as default. The `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` confirms payload-before-selector order, one staged payload, three distinct target assignments, a payload-free table, catch-to-try routing, try-fallthrough-to-inner copying, and inner-fallthrough-to-outer copying.

## Local interpretation

Starshine now admits one exact terminal scalar roster containing the legacy-try label and up to two matching defaultable block labels that form a strict direct-enclosure chain. The target preflight starts at the try owner and must consume each non-try target as the block that directly contains the previous owner; unrelated, skipped, duplicate-owner, if, loop, or additional try targets fail closed. The existing target-type, supported-origin, terminal-arm, label-use, and EH-repair gates remain required.

The payload stages once before selector work, copies into distinct try/inner/outer locals, and is removed from the table. Catch writes the try local, try fallthrough copies to the inner local, inner fallthrough copies to the outer local, and all three controls become void without changing source order or evaluation count.

This does not admit more than three unique targets, non-block secondary targets, skipped/non-direct block ancestry, nonterminal tables, nondefaultable results, typed catch payloads, or exceptional-transfer repair.
