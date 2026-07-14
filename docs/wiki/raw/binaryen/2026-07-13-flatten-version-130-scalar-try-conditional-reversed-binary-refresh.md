---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-scalar-try-conditional-binary-refresh.md
  - ./2026-07-13-flatten-version-130-try-conditional-break-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` scalar legacy-try reversed binary false-flow refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's conditional `Break` path evaluates the payload before the condition, writes the named-target temp, removes the branch payload, and leaves a local read on the not-taken path. Ordinary postorder flattening preserves a following binary expression. If the payload is the right operand and the left operand is already Flat-IR-simple, replacing only that right input keeps the binary after the branch and preserves every effect or trap on the false path; the simple left operand has no movable effect to reorder.

## Direct v130 probe

The ignored `.tmp/flatten-probes/scalar-try-conditional-reversed-binary-consumer.wat` probe places a legacy-try-label `br_if` in the right operand of `i32.div_s`, with `i32.const 42` as the simple left operand. Its `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` confirms payload-before-condition order, a payload-free branch, the division after the branch with the constant still on the left, void try output, and one shared result channel.

## Local interpretation

Starshine now admits the immediate scalar try false-flow binary in either operand position when the opposite operand is Flat-IR-simple, the binary is exact and single-use, its result type exactly matches the payload type, and the result is directly dropped. Generic flowing-use replacement changes only the payload operand to the shared try-result local read, so a trapping binary remains exclusively on the not-taken path.

This does not admit a rich or payload-dependent opposite operand, type-changing binary flow, nested or non-immediate consumers, shared binary results, typed catch payloads, or exceptional-transfer repair.
