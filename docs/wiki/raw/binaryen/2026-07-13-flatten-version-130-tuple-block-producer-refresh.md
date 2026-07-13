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

# Binaryen `version_130` `flatten` tuple-made block-tail refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen treats a concrete multivalue `tuple.make` as one value. When it is the tail of a value-carrying block, `flatten` first sequences the tuple components, stores the tuple in a typed temporary, routes the block result through another typed temporary, erases the block result, and returns the temporary value. Component evaluation remains left to right and exactly once.

The owner also retains an explicit non-nullability TODO for tuple types containing a nondefaultable reference. That boundary must remain fail-closed rather than being generalized from scalar defaultable cases.

## Direct v130 probe

The ignored probe `.tmp/flatten-probes/tuple-block.wat` contains a branch-free `(result i32 i64)` block whose only tail is `tuple.make` over effect-order-sensitive `i32.add` and `i64.add` components. Its output is `.tmp/flatten-probes/tuple-block.out.wat`.

`wasm-opt version 130 --all-features --flatten -S` emits:

- the i32 component work before the i64 component work;
- one tuple construction after both components;
- typed tuple-local traffic for the block result;
- a void block and an explicit final return.

## Local interpretation

HOT has ordered scalar children on `TupleMake`, while body locals are scalar `ValType` slots rather than Binaryen tuple locals. Starshine therefore admits only one exact representation bridge: a tuple-made tail with an exact result vector, one exclusive root use at that region tail, defaultable component types, and already-flattened scalar children. It replaces the single tuple root with ordered scalar local writes, deletes the detached tuple shell, erases block and label arity, and rewrites the exclusive outer consumer span to matching local reads.

Shared tuple roots, non-tail ownership, mismatched component vectors, non-simple children after operand rewriting, nondefaultable references, branch channels, and other producer kinds remain fail-closed.
