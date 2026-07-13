---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/ir/branch-utils.h
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` mixed loop/block table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`
- Unique-target helper: `src/ir/branch-utils.h`

## Source-backed composition

Binaryen's concrete-type rules compose without a special case for whether a loop's repeated result producer is an `if` or a `block`:

- a concrete `Switch` payload is staged once and copied to every unique target's `breakTemps` channel;
- a concrete `Block` result is written into its own target/result temp before the block becomes valueless;
- a concrete `Loop` result is written into a separate result temp before the loop becomes valueless.

For one table targeting the loop, the repeated inner block, and an enclosing result block, staged payload, loop-entry, inner-block, outer-block, and loop-result traffic are distinct semantic channels even when every channel has the same ordered element types.

## Direct v130 probe

The ignored probe `.tmp/flatten-probes/multivalue-loop-block-exit-table.wat` contains independently effect-shaped `(i32, i64)` loop entries and table payload components. One `br_table` targets the inputful loop, the repeated inner result block, and the enclosing result block.

`wasm-opt version 130 --all-features --flatten` preserves:

- loop entries before the loop;
- payload components once in source order before selector work;
- one copy into each of the three unique target channels;
- a separate inner-block result route into the loop result route;
- cleared branch and control arity.

The ignored output is `.tmp/flatten-probes/multivalue-loop-block-exit-table.out.wat`.

## Local interpretation

The admitted HOT family is exact:

- one inputful multivalue-result loop with independently scalar defaultable entries;
- one repeated exclusive multivalue block tail that owns the loop's ordered result span;
- one table targeting exactly the loop, that inner block, and an enclosing block;
- independently scalar exact table payloads;
- one exclusive outer loop and enclosing-block consumer chain;
- distinct staged-payload, loop-entry, inner-block, enclosing-block, and loop-result vectors.

Nested/nonexclusive ownership, nondefaultable or mismatched vectors, single multivalue payload producers, and non-block/non-if loop-tail producers remain open. Public `flatten` wiring remains removed.
