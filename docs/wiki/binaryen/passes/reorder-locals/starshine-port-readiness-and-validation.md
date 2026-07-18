---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ./index.md
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/reorder_locals_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./names-roundtrip-and-porting.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ./multivalue-call-scope.md
  - ../simplify-locals-nostructure/index.md
  - ../coalesce-locals/index.md
---

# Starshine validation bridge for `reorder-locals`

## Why this page exists

`reorder-locals` is already implemented in Starshine, but the old folder split made one important distinction too implicit:

- **explicit-pass correctness** is solved enough for the current supported module pass and covered by focused tests;
- **current preset coverage** is the public three-slot cleanup story backed by the early tuple/no-structure lane plus the late simplify/coalesce reorder sandwich;
- **future preset work** still needs ordered neighborhood evidence for the remaining non-`reorder-locals` no-DWARF gaps before Starshine can claim broader preset parity.

This page is the bridge from the algorithm pages to validation work. Use it when deciding whether a future change only preserves the standalone pass, preserves the current public three-slot cleanup story, or changes `reorder-locals` placement/count inside `optimize` / `shrink`.

## Current Starshine status

The 2026-07-02 O4Z closeout re-proved the explicit pass against the local `version_130` oracle: dedicated `reorder-locals-all`, ordinary GenValid, and `random-all-profiles` GenValid lanes each compared/normalized `10000/10000` with zero failures. The external wasm-smith lane compared `9956/10000` with one `unreachable-control-debris` compare-normalized residual, zero remaining mismatches, and `44` Binaryen/oracle command failures; see [research note 1401](./index.md).

A 2026-05-07 stable-boundary replay on the checked-in debug artifact kept the policy honest: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --binaryen-nop-until-stable 5 --reorder-locals` still reported `Binaryen no-pass converged: no` and `Canonical wasm equal: no`, but it also reported `Normalized WAT equal: yes` and `Canonical function compare equal: yes`. That confirms the remaining full-artifact raw drift still belongs to the Binaryen multivalue-call writeback boundary documented in [`./multivalue-call-scope.md`](./multivalue-call-scope.md), not to the standalone sorter contract.

Starshine currently exposes `reorder-locals` as an active module pass:

- registry entry: `pass_registry_entries()` in `src/passes/optimize.mbt`
- dispatcher case: the `reorder-locals` module-pass branch in `src/passes/pass_manager.mbt`
- owner entrypoint: `reorder_locals_run_module_pass(...)` in `src/passes/reorder_locals.mbt`
- registry category test: `pass registry classifies active, boundary-only, and removed names` in `src/passes/registry_test.mbt`
- explicit CLI coverage: focused `--reorder-locals` command coverage in `src/cmd/cmd_wbtest.mbt`

Starshine now schedules the public Binaryen-shaped three-slot cleanup story in both public presets:

```text
code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs
...
local-subtyping -> coalesce-locals -> local-cse -> simplify-locals -> vacuum -> reorder-locals -> coalesce-locals -> reorder-locals -> vacuum -> merge-blocks
```

Current preset tests lock that state by name: `tuple-optimization exact preset prereqs place code-pushing before the tuple slot` checks the early neighborhood order, `optimize and shrink presets schedule Binaryen-shaped reorder-locals cleanup slots` checks the three public `reorder-locals` occurrences and their immediate neighbors, and `optimize and shrink presets keep the late simplify-locals reorder sandwich together` checks the late `simplify-locals -> vacuum -> reorder-locals -> coalesce-locals -> reorder-locals -> vacuum` cluster. The 2026-07-12 scheduling note [`1561`](./index.md) supersedes the earlier one-slot public policy from [`0709`](./index.md).

That means new work should no longer treat repeated top-level public `reorder-locals` scheduling as an open RL policy gap by itself. Remaining preset work is now about the neighboring no-DWARF owners that still diverge from Binaryen, not the `reorder-locals` slot count.

## Explicit-pass contract to preserve

A local change to `src/passes/reorder_locals.mbt` should preserve these source-backed rules:

| Rule | Local implementation surface | Test surface |
| --- | --- | --- |
| Parameters never move. | `rl_defined_func_param_cache(...)`, `rl_params_for_type_idx(...)`, and the param prefix in `rl_rewrite_func(...)`. | Multiple-defined-function and params-only tests in `src/passes/reorder_locals_test.mbt:210` and `:280`. |
| Body-local accesses are counted across `local.get`, `local.set`, and Starshine's separate `local.tee`. | `rl_scan_instruction(...)` in `src/passes/reorder_locals.mbt:105`. | Access-count / first-use, write-only, and tee-only tests in `src/passes/reorder_locals_test.mbt:294`, `:328`, and `:364`. |
| Live body locals sort by descending count, then first observed use, then original index as a stable fallback. | `rl_sort_used_body_locals(...)` in `src/passes/reorder_locals.mbt:125`. | Access-count / first-use test plus carrier fixture in `src/passes/reorder_locals_test.mbt:294` and `:500`. |
| Zero-access body locals are removed, but write-only and tee-only locals survive. | `rl_note_access(...)`, `rl_rewrite_func(...)`, and the `old_to_new` `-1` dropped-local sentinel. | Write-only, tee-only, and trailing-local trim tests at `src/passes/reorder_locals_test.mbt:328`, `:364`, and `:346`. |
| Nested structured bodies have local indices rewritten uniformly. | `rl_rewrite_instrs_in_place(...)` covers `block`, `loop`, `if`, and `try_table`. | Nested rewrite test at `src/passes/reorder_locals_test.mbt:391`. |
| Grouped local runs are rebuilt, not flattened permanently. | `rl_flatten_locals(...)` plus `rl_push_local_run(...)`. | Local-run assertions throughout `src/passes/reorder_locals_test.mbt`. |
| Local names follow the new indices and stale raw name payloads are cleared. | `rl_rewrite_name_map(...)`, `rl_rewrite_local_names(...)`, and `rl_rewrite_name_sec(...)`. | Name-section coverage in `src/passes/reorder_locals_test.mbt`; CLI binary-write coverage in `src/cmd/cmd_wbtest.mbt`. |
| Imported-function local names are preserved. | `rl_rewrite_local_names(...)` keeps entries with `func_idx < imported_func_count`. | Name-section test at `src/passes/reorder_locals_test.mbt:454`. |

## Binaryen strategy mapping

The upstream strategy remains the small `ReorderLocals.cpp` contract described in [`./binaryen-strategy.md`](./binaryen-strategy.md):

1. Count `LocalGet` and `LocalSet` uses.
2. Keep parameters before body locals.
3. Sort live body locals by descending count and first-use order.
4. Truncate the body-local list at the first zero-count local.
5. Rewrite local users.
6. Rebuild local-name maps.

The main representation difference is tee handling:

- Binaryen's tee path is represented through `LocalSet`.
- Starshine's boundary instruction enum has a distinct `LocalTee`, so `rl_scan_instruction(...)` and `rl_rewrite_instrs_in_place(...)` mention it explicitly.

That is not semantic divergence. It is an IR-shape difference that tests must keep visible.

## Preset-readiness gate

Do **not** change the current three public `reorder-locals` slots in Starshine `optimize` or `shrink` just because the explicit pass is green.

Binaryen's no-DWARF optimizer uses `reorder-locals` as repeated glue around neighboring local passes:

1. `simplify-locals-nostructure -> vacuum -> reorder-locals`
2. `simplify-locals -> vacuum -> reorder-locals -> coalesce-locals`
3. `... -> coalesce-locals -> reorder-locals -> vacuum`

Starshine now claims the early public lane plus the late local-cleanup cluster, but a faithful future preset change still needs evidence for the specific ordered cluster being changed, not only for this pass alone.

Minimum evidence for changing preset scheduling:

- `moon info`, `moon fmt`, and focused `moon test src/passes` / `moon test src/cmd` remain green.
- Explicit `--pass reorder-locals` or equivalent pass-fuzz comparisons still pass against Binaryen for ordinary generated modules.
- The neighboring local-pass cluster has local equivalents or documented no-op/removed decisions for the specific preset slot being claimed.
- Ordered no-DWARF replay shows that the changed `reorder-locals` placement does not introduce raw-writeback, local-name, or multivalue-call regressions beyond the already documented writer boundary in [`./multivalue-call-scope.md`](./multivalue-call-scope.md).
- Preset tests update the exact occurrence count and neighbor assertions in the same change that supplies the replay evidence.

## Beginner-to-advanced validation ladder

Start with small, semantic checks before running broader parity:

1. **Shape tests:** preserve the examples in [`./wat-shapes.md`](./wat-shapes.md): hot-local reordering, first-use ties, write-only survival, tee-only survival, dead-tail removal, all-body-local removal, fixed params, nested users, and metadata repair.
2. **Module-representation tests:** keep grouped local runs and function-type parameter lookup covered. This is where Starshine differs most from Binaryen's in-memory AST view.
3. **Metadata tests:** always include a local-name map and a raw name-section payload when touching name repair; dropping or reordering locals without invalidating raw payload is a binary-output bug.
4. **CLI/binary roundtrip:** keep an adapter-level wasm input/output test because Binaryen's dedicated print-roundtrip fixtures prove that declaration order must survive serialization.
5. **Oracle parity:** compare explicit `reorder-locals` against Binaryen for generated modules before changing scheduler behavior.
6. **Preset replay:** preserve the current preset-slot tests, and only after the relevant local-pass neighbors are ready, test any ordered no-DWARF sequence that changes the current three-slot `reorder-locals` public schedule.

## Non-goals and stale-reference guardrails

- Do not describe `reorder-locals` as `coalesce-locals`, register allocation, dead-store elimination, or a generic liveness pass.
- Do not use the multivalue-call caveat as evidence that `ReorderLocals.cpp` is more complex than it is; that caveat belongs to writer/lowering compatibility.
- Do not call the Starshine implementation a HOT pass. It is module-scoped because it needs function type parameters, grouped local declarations, local-name maps, and raw custom-section invalidation.
- Do not add, remove, or reorder public preset `reorder-locals` occurrences without updating the exact occurrence-count tests and adding the cluster-level scheduling evidence described above.

## Sources

- Current preset-scheduling reconciliation: [research note 0709](./index.md)
- [`../../../raw/binaryen/2026-07-02-reorder-locals-version-130-source-refresh.md`](../../../raw/binaryen/2026-07-02-reorder-locals-version-130-source-refresh.md)
- [research note 0430](./index.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
- [`./parity.md`](./parity.md)
- [`./multivalue-call-scope.md`](./multivalue-call-scope.md)
- [`../../../../../src/passes/reorder_locals.mbt`](../../../../../src/passes/reorder_locals.mbt)
- [`../../../../../src/passes/reorder_locals_test.mbt`](../../../../../src/passes/reorder_locals_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
