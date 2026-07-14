---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-try-break-refresh.md
  - ./2026-07-13-flatten-version-130-multivalue-try-table-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` scalar legacy-try table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's `Switch` path evaluates a concrete payload before the selector, stages it once, copies it to every unique named-target break temp, removes the payload from `br_table`, and preserves the terminal table effect. Legacy `Try` routing independently writes reachable do/catch fallthrough results and makes the try void. Repeated labels are deduplicated before target-temp assignment; the same owner logic applies to scalar and multivalue concrete `Type` payloads.

## Direct v130 probe

The ignored `.tmp/flatten-probes/scalar-try-table-target.wat` probe carries one rich `i32` payload through a `br_table` whose cases and default all target the same legacy try label; the selector is independently rich and the catch produces a matching result. Its `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` confirms payload-before-selector order, one staged scalar payload, one deduplicated target assignment, payload removal, a payload-free terminal table, void try output, and a shared final result channel.

## Local interpretation

Starshine admits one exact scalar table family only when every table entry and the default repeat one legacy-try label, the result type is exact and defaultable, the payload has one supported scalar origin, the table is terminal in a try arm, every use of the try label passes complete preflight, and the other arm has an independently scalar matching fallthrough. The payload is staged once before selector work, copied once into the shared try-result local, and removed from the terminal table; the catch and outer consumer use the same typed channel.

This does not admit multiple unique try targets, mixed try/block/if/loop table fanout, nonterminal tables, mismatched or nondefaultable payloads, represented typed catch payloads, or exceptional-transfer repair.
