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

# Binaryen `version_130` `flatten` loop conditional-consumer refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

For a value-carrying `br_if`, Binaryen stores the payload before the condition, keeps the real branch as a prelude, and leaves a local read for not-taken flow. With a concrete multivalue payload, the tuple value remains available to later false-path expressions. Those expressions are not limited to direct drops: they may consume tuple components in ordinary scalar expressions after the conditional branch.

## Direct v130 probe

The ignored probe `.tmp/flatten-probes/multivalue-loop-br-if-consumers.wat` uses an inputful `(i32, i64) -> (i32, i64)` loop. Its conditional backedge leaves the pair on the false path, then consumes the i64 component in trapping `i64.div_s` and the i32 component in `i32.add` before producing the loop results.

`wasm-opt version 130 --all-features --flatten` emits:

- one ordered tuple payload store before the condition;
- the condition store and payloadless `br_if`;
- false-path tuple extraction through locals;
- the original potentially trapping i64 division before the original i32 add;
- separate later loop-result traffic.

This confirms that the false-path ownership contract is broader than direct drops while preserving payload-before-condition order, reverse stack-consumption order, one evaluation, and expression effects/traps.

## Local interpretation

HOT represents the tuple as ordered scalar payload nodes. Starshine now admits one additional exact false-path span: each immediate post-branch root is a `drop` of a single-use scalar `Binary` whose left child is the corresponding payload in reverse stack order, whose right child is already a Flat IR simple operand, and whose result type exactly matches the payload type. Existing direct drops remain admitted. Shared payloads, nested/non-immediate consumers, non-simple siblings, different producer kinds, and type mismatches remain fail-closed before mutation.
