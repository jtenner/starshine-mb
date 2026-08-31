---
kind: entity
status: supported
starshine_status: active
last_reviewed: 2026-08-30
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/SSAify.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/local-graph.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/LocalGraph.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/ssa.wast
  - ../../../../../src/passes/ssa.mbt
  - ../../../../../src/passes/ssa_test.mbt
  - ../../../../../src/ir/local_graph.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_ssa.mbt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./merge-locals-entry-prepends-and-default-values.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ./fuzzing.md
  - ../ssa-nomerge/index.md
  - ../tracker.md
---

# `ssa`

## Role

`ssa` is Binaryen's full local SSA pass and an active Starshine direct pass.

Both systems implement the same source-level intent:

1. analyze which local definitions or entry values can reach each local read;
2. give non-SSA writes fresh locals;
3. retarget single-source reads or materialize legal defaults;
4. create a fresh merge local for each multi-source read;
5. tee explicit incoming values into that merge local;
6. prepend parameter-entry copies when a parameter entry reaches a merge;
7. rely on fresh-local defaults for ordinary body-local entry values.

The defining distinction from [`ssa-nomerge`](../ssa-nomerge/index.md) is merge ownership. Full `ssa` materializes the join; `ssa-nomerge` preserves canonical merge traffic.

## Starshine status

Starshine's `ssa` implementation is complete for the Binaryen v131 source contract:

- active registry and CLI name;
- fresh set/tee definitions;
- parameter and default entries;
- explicit, parameter-entry, default-entry, and shared-set merge locals;
- loop, branch, `br_table`, typed-control, nested-value, and EH families;
- transactional raw writeback with batch validation and rollback;
- compare-pass admission to Binaryen `--ssa`;
- fifteen singleton GenValid profiles and `ssa-all`.

The default `optimize` / `shrink` scheduler remains on `ssa-nomerge`, matching the documented upstream sibling split.

## Implementation map

- [`../../../../../src/passes/ssa.mbt`](../../../../../src/passes/ssa.mbt)
  - descriptor, plan types, source classification, direct HOT mutation, raw stack-machine rewrite.
- [`../../../../../src/ir/local_graph.mbt`](../../../../../src/ir/local_graph.mbt)
  - full-flow reverse LocalGraph with exceptional predecessors and block/local caching.
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - public raw execution path and shared SSA batch rollback.
- [`../../../../../src/passes/ssa_test.mbt`](../../../../../src/passes/ssa_test.mbt)
  - planner, default, merge, branch, loop, typed, nested, EH, and regression coverage.
- [`../../../../../src/validate/gen_valid_ssa_full_wbtest.mbt`](../../../../../src/validate/gen_valid_ssa_full_wbtest.mbt)
  - singleton profile and aggregate contracts.
- [`./fuzzing.md`](./fuzzing.md)
  - exact final commands, counts, cache identity, mismatch classification, runtime, and performance evidence.

## Final evidence

Final native SHA-256: `a130c0c5f9f9bb3fcc1ad265dfc14e414d2f3184c9df1df01c0686774ee62b66`.

Pinned oracle: Binaryen v131 SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`.

- Moon: `10,825 / 10,825`.
- Regular GenValid: `100,000 / 100,000`, zero residuals/failures.
- wasm-smith: `9,956` comparable matches, `44` Binaryen-only parser/tool failures.
- `ssa-all`: `10,000 / 10,000`, only `647` typed-control outputs that are each four canonical bytes smaller in Starshine.
- Random all-profiles: `10,000 / 10,000`, only `84` pre-existing canonical-smaller cleanup/control residuals.
- Typed runtime: `1,000 / 1,000` all-equal.

## Intentional output wins

Starshine retains two measured differences instead of adding size-losing parity scaffolding:

- empty-arm nops are omitted;
- typed loop stack carriers use fewer locals/operations.

Both families are externally valid and canonically smaller; typed control also has direct all-equal runtime evidence.

## Performance

The transform is valid and feature-complete, but direct whole-command parity is still open under `[WALL]001`:

- Starshine no-trace direct command: about `4.024s`;
- Binaryen v131 direct command: about `1.202s`;
- Starshine output is `5,424` canonical bytes smaller on the measured artifact.

Do not conflate this shared serial raw/function-envelope gap with a missing SSA transformation family.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md): exact upstream v131 algorithm.
- [`./merge-locals-entry-prepends-and-default-values.md`](./merge-locals-entry-prepends-and-default-values.md): merge-local semantics.
- [`./wat-shapes.md`](./wat-shapes.md): concrete source/output shapes.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md): source and test ownership.
- [`./starshine-strategy.md`](./starshine-strategy.md): current local architecture.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md): final invariants and reopening criteria.
- [`./fuzzing.md`](./fuzzing.md): final fuzz/performance evidence.
