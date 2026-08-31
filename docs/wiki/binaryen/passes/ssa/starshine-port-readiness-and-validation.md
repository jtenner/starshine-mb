---
kind: concept
status: supported
last_reviewed: 2026-08-30
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/SSAify.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/LocalGraph.cpp
  - ../../../../../src/passes/ssa.mbt
  - ../../../../../src/passes/ssa_test.mbt
  - ../../../../../src/passes/ssa_wbtest.mbt
  - ../../../../../src/ir/local_graph.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/validate/gen_valid_ssa_full_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./starshine-strategy.md
  - ./fuzzing.md
  - ../ssa-nomerge/index.md
---

# Starshine full `ssa` implementation and validation contract

## Status

The full public `ssa` port is implemented and admitted.

Completed surfaces:

- active hot-pass registry and CLI name `ssa`;
- truthful CFG requirement and broad invalidation metadata;
- Binaryen v131 write-first then get/merge planning order;
- explicit/default/parameter source classification;
- fresh definitions, default materialization, merge locals, incoming tees, and entry prepends;
- normal, branch, loop, typed-control, nested-value, and exceptional predecessor coverage;
- raw stack-machine writeback;
- batched changed-definition validation and rollback;
- compare-pass admission to Binaryen `--ssa`;
- fifteen singleton GenValid profiles plus `ssa-all`;
- required four-lane fuzz closeout.

Presets remain intentionally unchanged and continue to use `ssa-nomerge`.

## Required invariants

### Phase order

Allocate fresh write locals before merge locals. This is observable in local numbering and shared-set nested tee order.

### Single-source reads

- explicit write: retarget to that write's final local;
- parameter entry: keep the parameter slot;
- legal ordinary default entry: materialize the exact default;
- nondefaultable entry: keep the read;
- zero sources: keep unreachable noise unchanged.

### Multi-source reads

- allocate one merge local per get;
- tee every explicit incoming value into that merge local;
- prepend a parameter copy only for parameter entry;
- rely on fresh-local initialization for ordinary default entry;
- when multiple gets share writes, nest tees in get order.

### Typed and exceptional control

Full-flow LocalGraph includes exceptional predecessor edges. Typed loop stack values remain separate from body-local source analysis; Starshine's lowerer may use fewer stack-carrier locals than Binaryen, but body-local merge semantics must remain identical.

### Transactionality

No partial mutation is allowed. Validate the complete plan before HOT mutation, and validate changed raw definitions in one batch before module commit.

## Test ladder

1. Planner and mutation tests in `src/passes/ssa_test.mbt`.
2. Stale/malformed plan rollback in `src/passes/ssa_wbtest.mbt`.
3. Registry/descriptor tests in `src/passes/registry_test.mbt`.
4. Public dispatcher and batched writeback tests in `src/passes/pass_manager_wbtest.mbt`.
5. Profile registry/generation tests in `src/validate/gen_valid_ssa_full_wbtest.mbt`.
6. `moon info`.
7. `moon fmt`.
8. `moon test`.
9. Fresh native release build.
10. Explicit Binaryen-v131 four-lane compare matrix from [`./fuzzing.md`](./fuzzing.md).
11. Focused typed-control runtime execution.
12. Production artifact timing and validity.

## Final correctness evidence

Final Moon suite: `10,825 / 10,825`.

Final compare matrix, native SHA-256 `a130c0c5f9f9bb3fcc1ad265dfc14e414d2f3184c9df1df01c0686774ee62b66`:

- regular GenValid: `100,000 / 100,000`, zero residuals/failures after source-backed cleanup normalization;
- wasm-smith: `9,956` comparable and matched, with `44` Binaryen-only parser/tool failures;
- `ssa-all`: all `10,000` valid and compared, with only `647` typed-control canonical-smaller residuals;
- random-all: all `10,000` valid and compared, with only `84` pre-existing canonical-smaller RemoveUnusedBrs cleanup/control residuals;
- typed-control runtime: `1,000 / 1,000` all-equal.

No Starshine validation, generator, property, or command failure remains in the four required lanes.

## Performance status

Feature and correctness closeout are complete, but whole-command parity is not.

The active raw implementation avoids broad HOT lowering and emits a smaller production artifact, but the serial raw LocalGraph/function envelope remains around `3.35x` Binaryen direct wall time on the canonical artifact. Keep that under `[WALL]001`; do not reopen semantic slices merely to disguise shared command overhead.

## Reopening criteria

Reopen full `ssa` correctness work for any of:

- a Starshine validation or command failure on a Binaryen-v131-valid input;
- a true semantic mismatch;
- a canonical size loss not justified by required behavior;
- missing source family in `ssa-all`;
- parameter/default prepend regression;
- incorrect shared-set tee order;
- exceptional predecessor omission;
- preset accidentally switching from `ssa-nomerge` to full `ssa`.

Reopen performance work separately for a raw-owner or whole-command optimization that preserves the final output/fuzz matrix.
