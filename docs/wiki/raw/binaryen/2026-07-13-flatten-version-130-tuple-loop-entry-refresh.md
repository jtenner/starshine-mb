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

# Binaryen `version_130` `flatten` tuple-made loop-entry refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen treats a concrete multivalue `tuple.make` feeding a typed loop as one ordered value. Generic flattening evaluates the tuple components and stores the tuple before loop entry; loop value removal then keeps entry flow and result flow separate. Component order, traps, and effects are preserved exactly once.

The owner retains a non-nullability TODO for tuple types with nondefaultable references, so that boundary remains fail-closed.

## Direct v130 probe

The ignored probe `.tmp/flatten-probes/tuple-loop-entry.wat` feeds an `(i32, i64)` `tuple.make` into a typed loop whose body consumes the parameters in stack order and returns `i32`. Its output is `.tmp/flatten-probes/tuple-loop-entry.out.wat`.

`wasm-opt version 130 --all-features --flatten -S` emits:

- i32 component work before i64 component work;
- one tuple construction before loop entry;
- typed extraction/temporary traffic inside the loop in reverse stack-consumption order;
- a distinct scalar result channel and explicit final return.

## Local interpretation

HOT body locals are scalar, while the tuple entry appears as one repeated `TupleMake` across the loop's parameter prefix. Starshine admits one exact bridge: the tuple vector and children exactly match defaultable loop parameters, the tuple exclusively owns those entry slots plus an immediate reversed prefix of direct body drops, and the loop otherwise satisfies the existing supported inputful scalar-result contract.

The rewrite evaluates ordered tuple children once into scalar entry locals, replaces the immediate drop consumers with reversed matching reads, clears the loop parameter prefix, deletes the detached tuple shell, and leaves result routing on its existing distinct local.

Tuple-made backedges, conditional/table loop traffic, non-immediate or non-drop entry consumers, shared/mixed ownership, nondefaultable references, and arbitrary multivalue producers remain fail-closed.
