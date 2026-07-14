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

# Binaryen `version_130` `flatten` tuple-made loop binary refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen evaluates a concrete conditional branch payload before its selector, stores that value once for the target, and restores it on the not-taken path. Generic flattening preserves later binary evaluation, including a potentially trapping binary opcode, after false-path restoration. Tuple component order is preserved by postorder traversal; the non-nullability TODO continues to exclude nondefaultable tuple lanes.

## Direct v130 probe

The ignored probe `.tmp/flatten-probes/tuple-loop-br-if-binary.wat` uses a typed loop with parameters `(i32, i64)`, distinct results `(f32, f64)`, one tuple-made `br_if`, and immediate reversed `i64.div_s` and `i32.add` false-path consumers with simple right operands. Its output is `.tmp/flatten-probes/tuple-loop-br-if-binary.out.wat`.

`wasm-opt version 130 --all-features --flatten -S` confirms:

- tuple component work precedes condition work;
- not-taken flow restores and extracts the tuple lanes before binary evaluation;
- the original `i64.div_s` trap behavior and `i32.add` operation remain in source order;
- loop result traffic remains distinct and later.

## Local interpretation

HOT repeats the tuple node id across scalar branch slots and each false-path binary's left operand. Starshine now admits only the exact direct-loop-body ownership shape where every immediate reversed false-path root is a drop of the tuple lane directly, a single-use exact unary/conversion, or a single-use exact binary. A binary must keep the tuple lane in child zero, have one already-simple right operand, and produce exactly the corresponding loop-parameter lane type.

The rewrite evaluates tuple components once into existing entry locals, keeps the condition later, replaces each binary left operand with the matching reversed local read, preserves the exact opcode and right operand, clears branch/loop arity, deletes the tuple shell, and retains distinct result locals. Non-simple right operands, type-changing or missing-exact binary nodes, shared/non-immediate consumers, nesting, mixed ownership, mismatches, and nondefaultable lanes remain fail-closed.
