---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` tuple-made conditional refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's `Break` path evaluates a concrete `br_if` payload before its condition, writes the target break temporary, clears the branch payload, and preserves the same value on the not-taken path. For a multivalue `tuple.make`, generic postorder flattening preserves component order before tuple construction and the target/flow channel uses the concrete tuple type.

The owner still carries a non-nullability TODO for tuple types containing nondefaultable references. That boundary remains fail-closed.

## Direct v130 probe

The ignored probe `.tmp/flatten-probes/tuple-br-if.wat` contains a defaultable `(result i32 i64)` block whose final `br_if` carries one `tuple.make` over ordered `i32.add` and `i64.add` components. Its output is `.tmp/flatten-probes/tuple-br-if.out.wat`.

`wasm-opt version 130 --all-features --flatten -S` emits:

- i32 component work before i64 component work;
- one tuple construction before condition evaluation;
- one write to the target/flow temporary;
- a payloadless conditional branch;
- explicit not-taken flow through the same temporary before the target block becomes void.

## Local interpretation

HOT represents the one tuple payload as the same node id repeated across both scalar branch payload slots and the exact contiguous false-path result span. Starshine now admits only that ownership shape for defaultable block/if targets: every branch and false-path slot is owned by the same `TupleMake`; the ordered result and child vectors match the target; and the tuple has no other uses. The rewrite evaluates each component once in order into the shared scalar target vector, rewrites the false-path span to matching reads, preserves condition order, clears branch/control arity, and deletes the tuple shell.

Loop-targeting conditional flow, mixed tuple/scalar payloads, shared or noncontiguous tuple flow, vector mismatches, nondefaultable references, and richer false-path ownership remain fail-closed.
