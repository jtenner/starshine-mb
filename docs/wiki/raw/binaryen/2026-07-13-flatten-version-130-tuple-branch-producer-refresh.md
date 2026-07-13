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

# Binaryen `version_130` `flatten` tuple-made plain-branch refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen treats a concrete multivalue `tuple.make` branch payload as one value. `visitBreak` evaluates that value once into the target's typed break temporary, clears the branch payload, and lets the target control consume the same temporary when its result is erased. Generic postorder flattening sequences tuple component work before tuple construction, so component order and traps/effects remain unchanged.

The owner still carries a non-nullability TODO for tuple types containing nondefaultable references. That boundary must remain fail-closed.

## Direct v130 probe

The ignored probe `.tmp/flatten-probes/tuple-br.wat` contains a defaultable `(result i32 i64)` block exited by a plain `br` carrying `tuple.make` over ordered `i32.add` and `i64.add` components. Its output is `.tmp/flatten-probes/tuple-br.out.wat`.

`wasm-opt version 130 --all-features --flatten -S` emits:

- i32 component work before i64 component work;
- one tuple construction and one target-local write;
- a payloadless `br`;
- a void target block and explicit final return through the routed value.

## Local interpretation

HOT represents this single tuple payload as one repeated node id across the target's scalar branch slots. Starshine admits only that exact bridge: every payload slot is the same `TupleMake`, its ordered result vector and children exactly match the defaultable target vector, and all tuple uses are exclusively those branch slots. After ordinary child preludes have made the components flat, the branch writes each component once into the shared scalar target-local vector, clears branch and target arity, deletes the detached tuple shell, and rewrites the exclusive target consumer span to matching reads.

Shared, mixed, conditional, table, loop-target, mismatched, nondefaultable-reference, and non-`TupleMake` single-producer branch payloads remain fail-closed.
