---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-try-conditional-break-refresh.md
  - ./2026-07-13-flatten-version-130-loop-conditional-unary-convert-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` scalar legacy-try unary/conversion false-flow refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's conditional `Break` path evaluates a concrete payload before its condition, writes the target temp, removes the branch payload, and leaves a local read on the not-taken path. Ordinary postorder flattening then keeps a following unary or conversion in its original false-flow position, replacing only its payload input and spilling the unary/conversion result before its direct consumer. The branch payload, condition, and false-path operation therefore remain single-evaluation and source ordered.

## Direct v130 probe

The ignored `.tmp/flatten-probes/scalar-try-conditional-unary-convert-consumers.wat` probe contains two `br_if` uses of one legacy-try label. The first not-taken path applies `i32.clz`; the second applies `i64.extend_i32_s`; each result is immediately dropped before an independent do fallthrough, and the catch produces the matching `i32` result. Its `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` confirms payload-before-condition order, payload-free branches, false-path unary/conversion work after each branch, one shared try-result channel, and void try output.

## Local interpretation

Starshine now admits an exact scalar try-label `br_if` false-flow consumer when the branch payload has exactly two uses, the branch is immediately followed in the same try arm by a direct `drop`, and that drop consumes either the payload itself or one single-use exact unary/conversion whose first and only operand is the payload. The payload is staged once before condition work; only the false-flow consumer input changes to a read from the shared try-result local. The unary/conversion remains after the branch, so its effects, traps, and order are not hoisted.

This does not admit binary consumers, nested or non-immediate consumers, shared wrapper results, additional payload uses, mismatched/nondefaultable branch channels, represented typed catch payloads, or exceptional-transfer repair.
