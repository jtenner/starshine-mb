---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/test/lit/passes/flatten_all-features.wast
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` loop/table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`
- Broad fixture: `test/lit/passes/flatten_all-features.wast`

## Source-backed composition

The v130 owner applies one uniform concrete-`Type` policy across the relevant pieces:

- a value-carrying `Loop` moves its body result into a local and becomes valueless;
- a concrete value-carrying `Switch` stages its value once and copies it to every unique target temp;
- each named target reuses one `breakTemps` channel;
- generic preludes preserve loop-entry, branch-payload, selector, and fallthrough evaluation order.

For a multivalue loop, Binaryen's AST carries one tuple `Type`. HOT instead exposes ordered entry, payload, and result children, so local correspondence needs separate proof for all three vectors.

## Direct v130 probe

A local `wasm-opt version 130` probe combined:

- a two-parameter `(i32, i64)` loop;
- a two-result `(i32, i64)` loop and enclosing block;
- effect-shaped calls for both entries, both table payload components, the guarding condition, and the selector;
- one `br_table` targeting both the loop backedge and the enclosing block;
- independently scalar loop fallthrough results.

The flattened v130 output preserved these semantic facts despite tuple-heavy representation expansion:

- entries were evaluated before entering the loop;
- payload components were evaluated once and before the selector;
- the staged tuple was copied into both loop and block target channels;
- the loop backedge and enclosing block used distinct target traffic;
- fallthrough results were routed separately from loop-entry traffic;
- the loop and enclosing block stopped carrying results directly.

The ignored probe artifacts are under `.tmp/flatten-probes/multivalue-loop-block-table-fallthrough*`.

## Local interpretation

The conservative HOT correspondence implemented on 2026-07-13 admits only an inputful multivalue loop that:

- has independently scalar defaultable entries and exact supported backedge payloads;
- contains a multivalue `br_table` backedge;
- has independently scalar exact fallthrough results;
- has one exclusive ordered outer consumer span;
- participates in exact table fanout whose non-loop targets can be repaired together.

Entry locals remain the loop-target branch channel. Result locals are allocated separately, even when entry and result vectors have identical types. Plain multivalue `br`/`br_if` loop families without an admitted table, single multivalue producers, mismatched vectors, nonexclusive consumers, and broader loop/control interactions remain open. Public `flatten` wiring remains removed.
