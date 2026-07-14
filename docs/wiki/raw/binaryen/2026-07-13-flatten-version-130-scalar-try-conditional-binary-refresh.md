---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-try-conditional-break-refresh.md
  - ./2026-07-13-flatten-version-130-scalar-try-conditional-unary-convert-refresh.md
  - ./2026-07-13-flatten-version-130-tuple-loop-binary-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` scalar legacy-try binary false-flow refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's conditional `Break` path evaluates a concrete payload before its condition, writes the named-target break temp, removes the branch payload, and leaves a local read on the not-taken path. Ordinary postorder flattening then keeps a following binary operation after the branch and spills its result before the direct consumer. When the payload is the binary left operand and the right operand is already Flat-IR-simple, replacing only the left operand preserves source order and keeps any binary trap exclusively on the not-taken path.

## Direct v130 probe

The ignored `.tmp/flatten-probes/scalar-try-conditional-binary-consumer.wat` probe carries one rich `i32` payload through `br_if` to a legacy-try label. On the not-taken path the payload is the left operand of `i32.div_s` with a constant right operand, so division-by-zero remains a possible false-path trap; the binary result is immediately dropped before an independent do fallthrough, and the catch produces the matching result. Its `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` confirms payload-before-condition order, a payload-free branch, the division after the branch, one shared try-result channel, and void try output.

## Local interpretation

Starshine now admits an exact scalar try-label `br_if` false-flow consumer when the branch is immediately followed in the same try arm by a direct `drop` of one single-use exact binary, the payload is the binary's left operand, the right operand is already simple, and the binary result type exactly matches the payload type. The payload is staged once before condition work; only the binary left input changes to a read from the shared try-result local. The binary remains after the branch, so traps and source order are preserved.

This does not admit a rich or payload-dependent right operand, reversed payload position, type-changing binary flow, nested or non-immediate consumers, shared binary results, extra payload uses, represented typed catch payloads, or exceptional-transfer repair.
