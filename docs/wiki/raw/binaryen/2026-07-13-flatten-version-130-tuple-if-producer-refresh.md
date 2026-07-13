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

# Binaryen `version_130` `flatten` tuple-made if-arm refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen computes an `if` result type from the two arm types, allocates one result temporary, and stores each concrete arm result into that same temporary. A concrete multivalue `tuple.make` arm is therefore evaluated only in its selected arm, with tuple components kept in source order, before the shared if-result channel is written and the if becomes void.

The existing tuple non-nullability TODO still applies: a tuple containing a nondefaultable reference cannot be generalized into local traffic without an explicit representation and proof.

## Direct v130 probe

The ignored probe `.tmp/flatten-probes/tuple-if.wat` contains a `(result i32 i64)` if whose then and else arms each end in one `tuple.make` over distinct arithmetic components. Its output is `.tmp/flatten-probes/tuple-if.out.wat`.

`wasm-opt version 130 --all-features --flatten -S` emits:

- condition work before the if;
- then-component work only in the then arm and else-component work only in the else arm;
- one tuple construction per selected arm;
- one shared typed tuple result local for both arms;
- a void if and explicit final return traffic.

## Local interpretation

Starshine reuses the exact tuple-tail bridge admitted for blocks in both if regions. Before mutation, both arms must either have independently scalar exact tails or one exclusively owned `TupleMake` tail whose exact defaultable result vector and already-flat scalar children match the if result vector. Only after both arms preflight does the rewrite replace tuple shells with ordered scalar writes into the same typed local vector, delete the detached tuple nodes, erase if/label arity, and rewrite the exclusive outer consumer span.

Mixed supported/unsupported arms, shared or non-tail tuple roots, mismatched vectors, nondefaultable tuple references, tuple-made branch channels, loops, and legacy try remain fail-closed.
