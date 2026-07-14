---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-multivalue-try-block-table-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` tuple-made multivalue legacy-try plus block table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's `Switch` owner treats the concrete multivalue payload as one tuple value. It stores that value once before selector work, copies local reads to every unique target temp, removes the switch payload, and then lets the legacy `Try` and directly enclosing `Block` erase their results through distinct tuple locals. `Break` target temps are allocated per label, so the try and block channels cannot alias merely because their tuple types match.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-block-table-tuple-payload.wat` probe and its `.out.wat` output were produced with `wasm-opt version 130 --all-features --flatten -S`. The output contains one tuple construction from the ordered `i32` and `i64` calls before selector evaluation, one staging tuple local, distinct try and block target assignments, a payload-free table, catch-to-try routing, and try-fallthrough-to-block copying.

## Local audit and admission

A fail-closed audit test first showed that the generic Starshine table path already admitted a repeated HOT `TupleMake` across the mixed try/block payload slots. The route was deliberately gated, which made the boundary test green, and then the source-backed positive failed unchanged before explicit re-admission.

Starshine now admits only the exact tuple-made mixed roster already supported for independently scalar lanes: one terminal table, one legacy-try target, and one directly enclosing matching defaultable block target. The tuple must be exclusively repeated across every payload slot; its scalar components must exactly match the ordered target vector, be defaultable, and have supported non-control origins. Components scalarize once in source order, populate separate staging, try, and block vectors before selector work, and the tuple shell is deleted only after complete target and ownership preflight.

This does not admit three or more unique targets, non-block secondary targets, nonterminal tables, shared or mixed tuple ownership, arbitrary whole-tuple producers, nondefaultable lanes, typed catch payloads, or exceptional-transfer repair.
