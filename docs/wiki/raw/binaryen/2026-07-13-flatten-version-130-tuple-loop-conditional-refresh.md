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

# Binaryen `version_130` `flatten` tuple-made loop conditional refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's `Break` path evaluates a concrete inputful-loop `br_if` payload before its condition, writes the loop target temporary, clears the branch payload, and preserves the same concrete value on the not-taken path. Generic postorder flattening preserves tuple-component order, while loop result routing remains separate from the loop parameter/backedge channel.

The owner still carries a non-nullability TODO for tuple types containing nondefaultable references. That boundary remains fail-closed.

## Direct v130 probe

The ignored probe `.tmp/flatten-probes/tuple-loop-br-if.wat` contains a typed loop with parameters `(i32, i64)`, results `(f32, f64)`, and one `br_if` carrying a `tuple.make` over ordered `i32.add` and `i64.add` components, followed by the immediate two-lane false-path drops. Its output is `.tmp/flatten-probes/tuple-loop-br-if.out.wat`.

`wasm-opt version 130 --all-features --flatten -S` confirms:

- tuple component work precedes condition work;
- one tuple payload feeds both the loop backedge and not-taken flow;
- the backedge becomes payloadless after the loop parameter temporary is updated;
- false-path consumption occurs before the distinct `(f32, f64)` result tuple is routed.

## Local interpretation

HOT represents the one tuple payload as the same node id repeated across every scalar branch payload slot and each immediate false-path drop. Starshine now admits only that exact ownership shape: the tuple vector exactly matches the defaultable loop parameter vector, every component has a supported scalar origin, the branch is a direct loop-body root, and the immediately following reversed direct-drop span owns all remaining tuple uses. The rewrite evaluates components once in order into the existing entry-local vector, rewrites the drops to matching reversed reads, preserves condition order, clears branch/loop arity, deletes the tuple shell, and keeps loop-result locals distinct.

Non-immediate, non-drop, shared, nested, mixed, mismatched, nondefaultable-reference, and richer tuple-made loop conditional flows remain fail-closed.
