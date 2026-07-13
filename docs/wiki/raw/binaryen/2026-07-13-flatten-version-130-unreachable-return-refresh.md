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

# Binaryen `version_130` `flatten` unreachable-return refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

After special handling and refinalization, Binaryen treats every remaining unreachable expression uniformly: the real expression becomes a prelude and an `unreachable` placeholder remains in the old child slot. This rule is not branch-specific. A nested `return` must therefore execute at its original source-order point, while later sibling preludes remain later and the old operand becomes unreachable.

## Direct v130 probe

The ignored probe `.tmp/flatten-probes/nested-return.wat` places a value-returning `return` in the left operand of `i32.add` and an effect-shaped call in the right operand. `wasm-opt version 130 --all-features --flatten` emits:

- the return-value computation;
- the real `return`;
- the later sibling computation;
- the old `i32.add` with `unreachable` in the return slot;
- the enclosing unreachable placeholder.

This proves both source order and the requirement to keep the terminal effect rather than replacing it in place.

## Local interpretation

Starshine now admits nested `Return` through the same owner-region placeholder path already used for `br` and `br_table`. The return payload is flattened first, the real return is sequenced once, and the old operand becomes `unreachable`. Throws and repair-sensitive EH terminals remain separate because whole-function legacy-EH gating and nested-pop repair are still incomplete. Public `flatten` wiring remains removed.
