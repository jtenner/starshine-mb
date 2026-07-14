---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-multivalue-try-break-refresh.md
  - ./2026-07-13-flatten-version-130-multivalue-try-conditional-break-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` multivalue legacy-try table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's `Switch` path evaluates a concrete payload before the selector, stages it once, copies it to every unique named-target break temp, removes the payload from `br_table`, and preserves the terminal table effect. Legacy `Try` routing independently writes reachable do/catch fallthrough results and makes the try void. Repeated labels are deduplicated before target-temp assignment.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-table-target.wat` probe carries `(i32, i64)` through a `br_table` whose cases and default all target the same legacy try label; the catch independently produces the result vector. Its `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` confirms component work before selector work, one staged tuple payload, deduplicated target assignment, payload removal, a payload-free terminal table, void try output, and a shared final result channel.

## Local interpretation

Starshine admits one exact multivalue table family only when every table entry and the default repeat one legacy-try label, the try has one exclusive outer result span, every lane is defaultable and exact, and the payload is either an independently scalar vector or one exclusively owned repeated `TupleMake` with supported scalar component origins. Components spill once in source order, an ordered staging-local vector is populated before selector work, that vector is copied once into the try-result locals, the tuple shell is deleted, and the payload-free table remains terminal. The other try arm may use an independently scalar or separately owned tuple-made fallthrough tail.

This does not admit scalar try tables, multiple unique try targets, mixed try/block/if/loop table fanout, nonterminal tables, mismatched or nondefaultable vectors, arbitrary whole-tuple producers, represented typed catch payloads, or exceptional transfer repair.
