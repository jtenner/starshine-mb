---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-scalar-try-block-if-table-refresh.md
  - ./2026-07-13-flatten-version-130-multivalue-try-if-table-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` multivalue legacy-try plus block plus enclosing-if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's concrete tuple `Switch` owner stages the payload once before selector work and copies it into every unique target temp. Postorder legacy-`Try`, `Block`, and `If` handling then erase each concrete multivalue control through distinct tuple locals. Catch writes the try tuple, selected try fallthrough copies into the block tuple, selected block fallthrough copies into the if tuple, and the other if arm writes the if tuple independently.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-block-if-table-targets.wat` probe places an `(i32, i64)` legacy try directly inside a matching multivalue block, itself directly inside the then arm of a matching multivalue if. The terminal table targets the try, block, and if, with the try repeated as default. The `.out.wat` output from the explicit Binaryen v130 `wasm-opt --all-features --flatten -S` binary confirms ordered component evaluation, one tuple staging point before selector work, distinct try/block/if assignments, payload removal, catch routing, two outward selected fallthrough copies, independent else-arm routing, and final tuple flow.

## Local admission

The scalar chain widening initially admitted independently scalar multivalue lanes through the generic table route. A fail-closed audit fixture exposed that inherited surface, after which an explicit temporary gate made the positive source-backed fixture fail unchanged before deliberate re-admission. Starshine now admits exact defaultable independently scalar lanes for the same try-plus-one-block-plus-one-outer-if roster. Lanes stage once in source order into distinct try/block/if vectors before selector work; catch writes the try vector, selected fallthrough copies outward once per control, the other if arm writes independently, and all table/control arity is cleared.

A separate fail-closed fixture proves that an exclusively owned repeated HOT `TupleMake` remains rejected for this block-plus-if chain. The tuple-specific policy still permits an unbounded strict block chain or the exact two-target try-plus-direct-if roster, but not their composition.

This does not admit repeated-`TupleMake` block-plus-if payloads, multiple blocks with an if, multiple if targets, reverse if-inside-block order, skipped or unrelated ancestry, loops, multiple try labels, arbitrary whole-tuple producers, nonterminal tables, nondefaultable lanes, typed catch payloads, or exceptional-transfer repair.
