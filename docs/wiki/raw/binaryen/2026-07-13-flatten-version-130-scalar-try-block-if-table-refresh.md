---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-scalar-try-if-table-refresh.md
  - ./2026-07-13-flatten-version-130-scalar-try-block-table-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` scalar legacy-try plus block plus enclosing-if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's scalar `Switch` owner stages a concrete payload once before selector work and copies it to every unique break target. Postorder legacy-`Try`, `Block`, and `If` handling then erase each value-carrying control through its own target/result temp. A selected try fallthrough feeds the block channel, and selected block fallthrough feeds the if channel, while catch and the other if arm retain their own path-local writes.

## Direct v130 probe

The ignored `.tmp/flatten-probes/scalar-try-block-if-table-targets.wat` probe places a scalar legacy try directly inside a matching value block, itself directly inside the then arm of a matching value if. The terminal table targets the try, block, and if, with the try repeated as default. The `.out.wat` output from the explicit Binaryen v130 `wasm-opt --all-features --flatten -S` binary confirms payload-before-selector order, three distinct target assignments, payload removal, catch-to-try routing, try-to-block and block-to-if selected fallthrough copies, independent else-arm routing, and final scalar flow.

## Local admission

Starshine now admits exactly the existing direct try-plus-if roster or one try-plus-one-block-plus-one-outer-if roster. Complete target preflight requires one try label, at most one if label, terminal placement in a try arm, exact defaultable scalar types and supported payload origin, and a strict direct-enclosure chain. When a block is present, the if must be the outermost selected control; the reverse if-inside-block ordering remains rejected. The payload stages once, copies into distinct try/block/if locals before selector work, catch writes the try local, selected fallthrough copies outward once per control, and the other if arm writes independently.

This does not admit multiple blocks with an if, multiple if targets, reverse if-inside-block order, skipped or unrelated ancestry, loops, multiple try labels, multivalue widening, nonterminal tables, nondefaultable payloads, typed catch payloads, or exceptional-transfer repair.
