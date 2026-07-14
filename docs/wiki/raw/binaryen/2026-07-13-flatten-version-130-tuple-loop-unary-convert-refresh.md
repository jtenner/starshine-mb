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

# Binaryen `version_130` `flatten` tuple-made loop unary/convert refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's concrete `Break` handling evaluates a `br_if` payload before its condition, stores it once for the loop target, and preserves the same concrete value for not-taken flow. Generic postorder flattening then sequences unary and conversion consumers after that false-path value is restored. The pass retains its non-nullability TODO, so tuple lanes containing nondefaultable references remain outside the admitted local route.

## Direct v130 probe

The ignored probe `.tmp/flatten-probes/tuple-loop-br-if-unary-convert.wat` uses a typed loop with parameters `(i32, i64)`, distinct results `(f32, f64)`, one tuple-made conditional backedge, and immediate reversed false-path `i64.clz` and `i64.extend_i32_s` consumers. Its output is `.tmp/flatten-probes/tuple-loop-br-if-unary-convert.out.wat`.

`wasm-opt version 130 --all-features --flatten -S` confirms:

- tuple components execute before the condition;
- the not-taken tuple is restored before component extraction;
- extracted lanes feed the original unary/conversion operations in reverse stack order;
- unary/conversion operations remain after the conditional and before distinct loop-result traffic.

## Local interpretation

HOT represents the tuple payload as one node id repeated across scalar branch slots and false-path operand slots. Starshine now admits the exact exclusively owned direct-loop-body shape when every immediate reversed false-path root is a drop of either the tuple lane directly or one single-use exact unary/conversion whose only operand is that tuple lane. The tuple component vector must exactly match defaultable loop parameters and every component must have a supported scalar origin.

The rewrite evaluates tuple components once in source order into existing entry locals, preserves condition order, rewrites the unary/conversion operand to the matching reversed entry-local read, clears branch and loop arity, deletes the tuple shell, and keeps result locals distinct. Binary tuple consumers, shared or non-immediate consumers, nested branches, mixed ownership, type mismatch, and nondefaultable references remain fail-closed.
