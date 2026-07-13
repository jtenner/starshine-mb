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

# Binaryen `version_130` `flatten` tuple-made table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's `Switch` path treats a concrete multivalue `tuple.make` payload as one value. It evaluates that value once into a staging local, copies the staged value to every unique target's typed break temporary, clears the table payload, and retains selector evaluation after payload staging. Generic postorder flattening preserves tuple-component source order before construction.

The owner still carries a non-nullability TODO for tuple types containing nondefaultable references. That boundary remains fail-closed.

## Direct v130 probe

The ignored probe `.tmp/flatten-probes/tuple-br-table.wat` contains a defaultable `(result i32 i64)` block exited by a repeated-target `br_table` carrying one `tuple.make` over ordered `i32.add` and `i64.add` components. Its output is `.tmp/flatten-probes/tuple-br-table.out.wat`.

`wasm-opt version 130 --all-features --flatten -S` emits:

- i32 component work before i64 component work;
- one tuple construction and one table staging write;
- one copy to the deduplicated target temporary;
- selector work after payload staging;
- a payloadless table and void target block.

## Local interpretation

HOT represents the one tuple payload as the same node id repeated across scalar table payload slots. Starshine now admits only that exact bridge: every payload slot is the same exclusively owned `TupleMake`; its ordered result and child vectors exactly match every target's defaultable block/if result or loop-parameter vector; and its children have supported scalar origins. The rewrite evaluates each component once in order into scalar staging locals, copies those reads to each unique target vector, evaluates selector work afterwards, clears table/control arity, and deletes the detached tuple shell.

Mixed tuple/scalar payloads, shared tuple producers, vector mismatches, nondefaultable references, and broader ambiguous table ownership remain fail-closed.
