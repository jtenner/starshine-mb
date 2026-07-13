---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/ir/branch-utils.h
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/test/lit/passes/flatten_all-features.wast
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` mixed loop/if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`
- Unique-target helper: `src/ir/branch-utils.h`
- Broad fixture: `test/lit/passes/flatten_all-features.wast`

## Source-backed composition

Binaryen's v130 owner composes three general rules without a target-kind exception:

- concrete `Switch` values are staged once and copied to every unique named target's `breakTemps` channel;
- concrete `If` results are written into an if-result temp before the if becomes valueless;
- concrete `Loop` results are written into a separate loop-result temp before the loop becomes valueless.

When one table can either continue an inputful loop or exit a value-carrying if, the target channels are semantically distinct even when all vectors have the same element types. If the if itself is the loop fallthrough producer, its routed local reads must feed a separate loop-result vector rather than alias either the if target or loop-entry vector.

## Direct v130 probe

The mixed function in `.tmp/flatten-probes/multivalue-loop-plain-breaks.wat` combines:

- independently effect-shaped `(i32, i64)` loop entries;
- a two-result if as the loop's fallthrough producer;
- independently effect-shaped table payload components and selector;
- one `br_table` whose unique targets are the loop and the if;
- independently scalar else-arm results.

`wasm-opt version 130 --all-features --flatten` preserves the required ordering and channel separation:

- loop entries execute before the loop;
- table payload components execute once before the selector;
- the staged payload reaches both unique target channels;
- the else arm writes the same if-result channel used by the if target;
- the routed if result then feeds distinct loop-result traffic;
- the if, loop, table payload, and target arities become valueless.

The ignored output is `.tmp/flatten-probes/multivalue-loop-plain-breaks.out.wat`.

## Local interpretation

The admitted HOT family is deliberately exact:

- one inputful multivalue-result loop with independently scalar defaultable entries;
- one repeated multivalue if tail that exclusively owns the loop's ordered result span;
- one multivalue table targeting exactly that loop and if;
- independently scalar exact table payloads and else-arm values;
- one exclusive outer loop consumer span;
- four distinct semantic channels: staged payloads, loop entries, if results, and loop results.

Additional unique targets, nested/nonexclusive if ownership, single multivalue producers outside this exact repeated tail, mismatched vectors, and broader mixed-control fanout remain open. Public `flatten` wiring remains removed.
