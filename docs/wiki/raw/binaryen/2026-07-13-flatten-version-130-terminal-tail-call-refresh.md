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

# Binaryen `version_130` `flatten` terminal tail-call refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's generic unreachable-expression path is not limited to `return` or exception terminals. A nested `return_call`, `return_call_indirect`, or `return_call_ref` has its operands flattened first, is sequenced as the real terminal in the owning prelude, and is replaced at the old operand slot by `unreachable`. Direct arguments, indirect selectors, and reference callees therefore retain source order, one evaluation, traps, and the tail-call transfer.

## Direct v130 probes

The ignored probes are:

- `.tmp/flatten-probes/nested-return-call.wat`;
- `.tmp/flatten-probes/nested-return-call-indirect.wat`;
- `.tmp/flatten-probes/nested-return-call-ref.wat`.

`wasm-opt version 130 --all-features --flatten` emits operand local writes before the corresponding terminal, keeps exactly one real tail call, sequences later sibling work afterwards, and leaves `unreachable` in the old arithmetic operand. The indirect probe preserves argument-before-selector order. The reference probe preserves argument-before-callee order.

## Local EH representation check

Before selecting this bounded terminal family, the local executable representation was rechecked for the smallest typed legacy catch-payload step. `src/lib` has no Binaryen-style typed payload `Pop` instruction, and HOT lift models modern catch clauses as catch-arm metadata rather than a movable legacy payload node. A real nested-pop repair slice would therefore require coordinated lib instruction, validation, binary/text, lift/lower, catch-entry ownership, and exclusion semantics; that is not a safe single-commit representation change. The existing explicit EH prerequisite gate remains correct.

## Local interpretation

Starshine now admits `ReturnCall`, `ReturnCallIndirect`, and `ReturnCallRef` through the owner-region terminal-placeholder path. Their children are flattened in source order before the real terminal is sequenced once, later sibling preludes remain later, and the old operand becomes `unreachable`. Legacy typed catch-payload tracking, nested-`pop` repair, `rethrow`, and `delegate` remain separately fail-closed. Public `flatten` wiring remains removed.
