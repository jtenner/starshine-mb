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

# Binaryen `version_130` `flatten` loop conditional unary/conversion refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's value-carrying `br_if` handling stores the complete payload before the condition and leaves a local read for false-path flow. Ordinary scalar consumers after the branch are then flattened by the generic prelude rule, regardless of whether they are binary, unary, or conversion expressions. Potential traps and exact opcodes remain at the original false-path point.

## Direct v130 probe

The ignored probe `.tmp/flatten-probes/multivalue-loop-br-if-unary-convert-consumers.wat` uses an inputful `(i32, i64) -> (i32, i64)` loop. The false path consumes the top i64 payload with `i64.clz`, then consumes the i32 payload with `i64.extend_i32_s`, before producing independent loop results. Its output is `.tmp/flatten-probes/multivalue-loop-br-if-unary-convert-consumers.out.wat`.

`wasm-opt version 130 --all-features --flatten -S` emits:

- ordered payload construction before condition work;
- a payloadless conditional backedge;
- reverse-order tuple extraction on the false path;
- the original `i64.clz` before the original signed extension;
- ordinary local-set preludes for both consumer results;
- distinct later loop-result traffic.

## Local interpretation

HOT exposes the multivalue false path as ordered scalar payload nodes and immediate reversed consumer roots. Starshine now admits an immediate `drop` of a single-use exact `Unary` or `Convert` node whose only child is the corresponding payload, in addition to direct drops and the existing exact binary form. The original verified opcode and result type remain unchanged; only the payload child becomes the matching typed entry-local read. Generic operand flattening then sequences the retained consumer immediately before its drop.

Shared payloads, shared consumer nodes, nested or non-immediate consumers, missing exact instructions, multi-child unary/conversion shapes, and other producer kinds remain fail-closed.
