---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-multivalue-try-conditional-break-refresh.md
  - ./2026-07-13-flatten-version-130-scalar-try-conditional-unary-convert-refresh.md
  - ./2026-07-13-flatten-version-130-loop-conditional-unary-convert-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` multivalue legacy-try unary/conversion false-flow refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen treats a concrete multivalue `Break` payload as one value. The conditional branch path evaluates that payload before its condition, writes the named-target temp, removes the payload from `br_if`, and leaves the temp value on the not-taken path. Ordinary postorder flattening then keeps unary and conversion consumers after the branch while replacing their inputs with explicit local traffic. Legacy `Try` routing independently writes reachable do/catch fallthrough values and makes the try void.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-conditional-unary-convert-consumers.wat` probe carries `(i32, i64)` through a `br_if` to a legacy-try label. On the not-taken path the top `i64` lane is consumed by `i64.clz`, then the `i32` lane is consumed by `i64.extend_i32_s`; both results are directly dropped before an independent do fallthrough, and the catch produces the matching result vector. Its `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` confirms component-before-condition order, a payload-free branch, unary/conversion work after the branch in reverse stack-consumption order, void try output, and one shared final result channel.

## Local interpretation

HOT can expose a multivalue branch as independently scalar payload lanes even though Binaryen's source owner sees one concrete tuple value. Starshine now admits that exact representation when each distinct defaultable payload has only the branch use plus one immediate false-flow consumer in the same try arm. The immediate reversed consumer span may directly drop a lane or drop one single-use exact unary/conversion whose sole operand is that lane. Ordered payloads write the shared try-result vector before condition work; only each false-flow consumer input becomes the corresponding reversed local read, so unary/conversion work remains exclusively on the not-taken path.

This does not yet widen repeated `TupleMake` false flow beyond direct drops, admit binary, nested, non-immediate, shared, or mismatched consumers, represent arbitrary whole-tuple producers or typed catch payloads, or implement exceptional-transfer repair.
