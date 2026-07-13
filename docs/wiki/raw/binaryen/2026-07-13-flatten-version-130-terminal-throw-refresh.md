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

# Binaryen `version_130` `flatten` terminal-throw refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's generic postorder handling applies to `throw` and `throw_ref`: concrete operands are flattened first, then any remaining unreachable expression is moved into the owning prelude and replaced at its old operand slot by `unreachable`. This preserves throw arguments, argument order, the exceptional effect, and later sibling-prelude order. It is independent of the legacy-catch nested-`pop` repair performed at function exit.

## Direct v130 probes

The ignored probes `.tmp/flatten-probes/nested-throw.wat` and `.tmp/flatten-probes/nested-throw-ref.wat` place the exceptional terminal in a `select` condition. `wasm-opt version 130 --all-features --flatten` emits:

- ordered local writes for the two `throw` arguments before the real throw;
- one real `throw` or `throw_ref` in the prelude;
- `unreachable` in the old `select` condition slot;
- the enclosing unreachable placeholders required by the now-dead expression context.

The `throw` output keeps the i32 argument before the i64 argument. The `throw_ref` output keeps the exception reference before the exceptional transfer.

## Local interpretation

Starshine admits `Throw` and `ThrowRef` through the same owner-region terminal-placeholder path as `br`, `br_table`, and `return`. Child operands are flattened before the real terminal is sequenced once, later sibling preludes remain later, and the old operand becomes `unreachable`. Legacy catch-payload tracking, nested-`pop` repair, `rethrow`, and `delegate` remain separately gated. Public `flatten` wiring remains removed.
