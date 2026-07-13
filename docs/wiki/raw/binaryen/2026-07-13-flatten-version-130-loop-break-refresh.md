---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/test/lit/passes/flatten_all-features.wast
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` loop/break refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`
- Broad fixture: `test/lit/passes/flatten_all-features.wast`

## Source-backed composition

The v130 owner does not give loop-targeting `Break` a scalar-only exception. It applies the same concrete-`Type` rules used elsewhere:

- a concrete branch value writes the named target's one `breakTemps` channel and is removed from the branch;
- a conditional branch additionally keeps false-path flow through a local read;
- a concrete loop result writes a separate result temp before the loop becomes valueless;
- postorder preludes preserve entry, payload, condition, and fallthrough source order.

For a multivalue typed loop, Binaryen sees one tuple `Type`; HOT exposes ordered entry, backedge, and result children. A local port must therefore prove each vector independently and must not alias loop-entry traffic with loop-result traffic merely because their element types match.

## Direct v130 probe

A local `wasm-opt version 130` probe combined three functions:

- a two-parameter/two-result loop with a plain `br` backedge;
- the adjacent loop with a value-carrying `br_if` backedge and false-path consumers;
- a mixed loop/if `br_table` fanout for the next target-family proof.

The plain and conditional outputs preserve these semantic facts:

- independently effect-shaped entries run before the loop;
- backedge payload components run once in source order;
- conditional payloads run before the condition and remain available on the false path;
- branch payload arity is cleared;
- independently scalar fallthrough results use traffic distinct from the loop-entry channel;
- the loop result becomes explicit local traffic.

Ignored probe artifacts are under `.tmp/flatten-probes/multivalue-loop-plain-breaks*`.

## Local interpretation

The first admitted non-table family is an inputful multivalue-result loop with:

- exact independently scalar defaultable entries;
- an exact independently scalar plain `br` backedge;
- exact independently scalar fallthrough results;
- one exclusive ordered outer consumer span;
- distinct entry and result local vectors.

The adjacent `br_if` and mixed loop/if table families remain separate red-first slices until their false-path and multi-target ownership proofs land. Public `flatten` wiring remains removed.
