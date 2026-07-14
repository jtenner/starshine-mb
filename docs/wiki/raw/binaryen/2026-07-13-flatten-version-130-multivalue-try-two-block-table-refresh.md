---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-scalar-try-two-block-table-refresh.md
  - ./2026-07-13-flatten-version-130-multivalue-try-block-table-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` multivalue legacy-try plus two-block table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's `Switch` owner stages one concrete tuple payload before selector work and copies it to every unique label temp. The legacy `Try`, inner `Block`, and outer `Block` are then erased in postorder through separate tuple locals, with catch feeding the try channel and each ordinary fallthrough copying the selected tuple outward once.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-two-block-table-targets.wat` probe places an `(i32, i64)` legacy try inside two nested `(i32, i64)` blocks. Its terminal table targets the try, inner block, and outer block, with the try repeated as default. The `.out.wat` output from the explicit Binaryen v130 `wasm-opt --all-features --flatten -S` binary confirms ordered component evaluation, one tuple staging point before selector work, three distinct tuple target assignments, payload removal, catch-to-try routing, and two outward fallthrough copies.

## Local audit and admission

The scalar target-chain widening initially made the generic multivalue route admit this roster without a dedicated vector policy. A fail-closed audit test exposed that inherited admission. Starshine then added a multivalue-specific table helper, first capped it at two targets, and converted the source-backed positive to red before explicitly admitting the three-target independently scalar vector.

The admitted route requires one terminal table, one legacy-try target, and exactly two matching defaultable block targets that form the same strict direct-enclosure chain proven by the scalar helper. Each payload component must be an independent exact scalar lane with a supported origin; repeated `TupleMake` payloads remain rejected for this three-target roster. Components stage once in source order, then copy into distinct try, inner-block, and outer-block vectors before selector work. Catch writes the try vector, try fallthrough copies to the inner vector, inner fallthrough copies to the outer vector, and all table/control arity is cleared.

This does not admit tuple-made three-target payloads, more than three unique targets, skipped/non-direct ancestry, if/loop/additional-try targets, nonterminal tables, arbitrary whole-tuple producers, nondefaultable lanes, typed catch payloads, or exceptional-transfer repair.
