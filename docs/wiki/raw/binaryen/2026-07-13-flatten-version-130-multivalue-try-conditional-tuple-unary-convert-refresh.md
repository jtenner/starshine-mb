---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-multivalue-try-conditional-break-refresh.md
  - ./2026-07-13-flatten-version-130-multivalue-try-conditional-unary-convert-refresh.md
  - ./2026-07-13-flatten-version-130-tuple-loop-unary-convert-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` tuple-made multivalue legacy-try unary/conversion false-flow refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's IR treats a concrete multivalue conditional `Break` payload as one tuple-typed expression. Flatten evaluates that tuple before the condition, writes the named-target temp, removes the payload from `br_if`, and leaves explicit local traffic on the not-taken path. Postorder flattening keeps following unary and conversion consumers after the branch and changes only their payload input. Legacy `Try` routing writes all reachable do/catch results through one concrete result temp and makes the try void.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-conditional-tuple-unary-convert-consumers.wat` probe carries `(i32, i64)` through a legacy-try-label `br_if`, applies `i64.clz` to the top lane and `i64.extend_i32_s` to the remaining lane on the not-taken path, then selects an independent do or catch result vector. Its `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` explicitly shows tuple construction before condition work, a payload-free branch, both consumers after the branch, and one shared void-try result channel.

## Local interpretation

HOT represents that one tuple value by repeating the same `TupleMake` node id in each branch payload slot and false-flow lane. Starshine now admits one exact exclusively owned repeated tuple when its ordered defaultable scalar components match the try result vector, have supported origins, and the tuple's only uses are all payload slots plus one immediate reversed consumer per lane. Each consumer may be a direct drop or a direct drop of one single-use exact unary/conversion whose sole input is the tuple lane. Components scalarize once in source order into the shared result vector, consumer inputs become reversed local reads, and the detached tuple shell is deleted only after complete ownership proof.

This does not admit tuple binary consumers, mixed tuple/scalar payload ownership, shared or non-immediate wrappers, arbitrary whole-tuple producers, represented typed catch payloads, or exceptional-transfer repair.
