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

# Binaryen `version_130` `flatten` tuple-made loop-break refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's `visitBreak` treats a concrete tuple-valued plain loop break as one carried value. It evaluates the tuple once, stores it in the loop target's break temporary, clears the original branch payload, and later routes the loop backedge through the loop-entry channel. Generic postorder flattening preserves tuple component order and effects/traps before the branch.

The owner still carries a non-nullability TODO for tuples containing nondefaultable references, so those values remain outside the admitted local bridge.

## Direct v130 probe

The ignored probe `.tmp/flatten-probes/tuple-loop-br.wat` has a typed `(i32, i64) -> i32` loop and a conditional arm containing a plain `br` whose payload is `tuple.make` over ordered arithmetic components. Its output is `.tmp/flatten-probes/tuple-loop-br.out.wat`.

`wasm-opt version 130 --all-features --flatten -S` emits:

- component work and tuple construction inside the selected arm before the branch;
- one payloadless inner branch;
- explicit tuple traffic into the loop-entry carrier;
- distinct loop-result traffic and an explicit final return.

## Local interpretation

HOT represents the one tuple payload by repeating the same `TupleMake` node across the loop branch's scalar payload slots. Starshine admits only an exact plain-`br` bridge: the tuple is exclusively owned by those slots, its defaultable ordered result vector matches the loop parameter vector rather than the loop result vector, and each component has a supported scalar origin.

After ordinary child preludes preserve component source order, the branch writes each component once into the existing typed loop-entry locals, clears its payload, deletes the detached tuple shell, and leaves the loop's distinct result vector unchanged.

Tuple-made `br_if`, `br_table`, shared/mixed backedges, mismatched vectors, nondefaultable references, non-loop targets beyond the separately admitted plain block/if branch, and arbitrary multivalue producers remain fail-closed.
