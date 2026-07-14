---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-multivalue-try-conditional-unary-convert-refresh.md
  - ./2026-07-13-flatten-version-130-scalar-try-conditional-binary-refresh.md
  - ./2026-07-13-flatten-version-130-loop-conditional-consumer-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` independently scalar multivalue legacy-try binary false-flow refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen evaluates a concrete multivalue conditional `Break` payload before its condition, writes the named-target temp, removes the payload from `br_if`, and leaves the value available on the not-taken path. Ordinary postorder flattening keeps following binary consumers after the branch. When a payload lane is the binary left operand and the right operand is already Flat-IR-simple, replacing only the left input preserves source order and keeps binary effects or traps exclusively on the false path.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-conditional-binary-consumers.wat` probe carries `(i32, i64)` through a legacy-try-label `br_if`. The false path consumes the top `i64` lane with `i64.div_s` by zero and then the `i32` lane with `i32.add`, directly dropping both results before an independent do fallthrough; the catch supplies the matching result vector. Its `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` confirms component-before-condition order, a payload-free branch, both binaries after the branch in reverse stack-consumption order, the division trap remaining false-path-only, and one shared void-try result channel.

## Local interpretation

Starshine's independently scalar HOT representation is admitted only when each defaultable lane has exactly the branch use plus one immediate reversed consumer. A binary consumer must be single-use, exact, same-typed with its payload lane, directly dropped, place the payload on the left, and have a simple right operand. The payload vector writes the shared try-result locals once before condition work; only each binary left input becomes the corresponding reversed local read.

This does not admit tuple-made multivalue try binary consumers, rich or payload-dependent right operands, reversed payload positions in multivalue flow, type-changing binary results, non-immediate or shared consumers, typed catch payloads, or exceptional-transfer repair.
