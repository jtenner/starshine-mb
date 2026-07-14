---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-multivalue-try-conditional-tuple-unary-convert-refresh.md
  - ./2026-07-13-flatten-version-130-multivalue-try-conditional-binary-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` tuple-made multivalue legacy-try binary refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen visits the concrete multivalue `Break` before the surrounding legacy `Try`. The carried tuple is evaluated before the condition and routed through the try target temp. On the not-taken path, later scalar consumers remain after the conditional branch, so binary effects and traps are not hoisted onto the taken path.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-conditional-tuple-binary-consumers.wat` probe carries same-typed `(i32, i32)` lanes through a try-label `br_if`. The immediate false path consumes the second lane with `i32.div_s` by zero and the first with `i32.add`. Its `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` confirms component-before-condition order, reverse stack-lane consumption, payload-free branching, and binary placement after the branch; the division trap remains false-path-only.

## Local interpretation

The prior try matcher accidentally inherited tuple-binary admission from the loop consumer helper. The route is now explicit and directly tested. Starshine admits one exclusively owned repeated `TupleMake` only when every component has an exact defaultable scalar type and supported origin, the tuple owns exactly the branch slots plus one immediate reversed consumer per lane, each binary is single-use with an exact opcode, the tuple is its left operand, the right operand is Flat-IR-simple, and the binary result exactly matches the selected lane type and is directly dropped. Same-typed lanes are distinguished by the immediate reversed consumer position, not by type alone.

This does not admit reversed tuple binary operands, rich right operands, type-changing consumers, non-immediate or nested consumers, shared tuple uses, mixed tuple/scalar payloads, arbitrary whole-tuple producers, represented typed catch payloads, or exceptional-transfer repair.
