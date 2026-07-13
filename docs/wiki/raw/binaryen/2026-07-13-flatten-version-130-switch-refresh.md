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

# Binaryen `version_130` `flatten` switch refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`
- Unique-target helper: `src/ir/branch-utils.h`
- Broad fixture: `test/lit/passes/flatten_all-features.wast`

## Source-backed behavior

For a concrete value-carrying `Switch`, the v130 owner:

1. allocates a staging local typed as the complete carried `Type`;
2. evaluates and stores the carried value once;
3. enumerates unique branch targets with `BranchUtils::getUniqueTargets(...)`;
4. copies one read of the staging local into each target's `breakTemps` entry;
5. clears the switch value and finalizes the switch.

The owner is expressed in terms of a concrete Binaryen `Type`, so a multivalue tuple follows the same one-value algorithm as a scalar. Repeated labels are deduplicated before target copies. The generic postorder/prelude algorithm still preserves payload work before selector work.

## Direct v130 probe

A local `wasm-opt version 130` probe used one `(i32, i64)` carried value, three repeated references to the same block target, effect-shaped direct calls for both payload components, and a direct-call selector. The flattened output:

- evaluated the two payload calls in source order;
- assembled and staged one tuple value;
- evaluated the selector afterwards;
- emitted only one target-channel copy despite repeated labels;
- cleared the `br_table` payload while preserving the selector.

The ignored probe artifacts are under `.tmp/flatten-probes/multivalue-br-table-repeated-target*`.

## Local interpretation

Starshine HOT represents a multivalue table payload as ordered scalar children rather than one tuple-valued child. The conservative correspondence implemented on 2026-07-13 therefore:

- admits defaultable block/if targets only when every payload component is an independently supported scalar origin and the ordered vector exactly matches the target vector;
- stages each payload component once in source order before selector preludes;
- deduplicates repeated target labels;
- copies the staged vector into the target's shared typed local vector;
- clears payload children while preserving the selector;
- keeps multiple unique nested block/if targets, mixed target kinds, mismatched vectors, ambiguous ownership, and branch-targeted loop-result interactions as separate proof obligations.

This is a representation correspondence, not a claim of tuple-level output parity. Public `flatten` wiring remains removed.
