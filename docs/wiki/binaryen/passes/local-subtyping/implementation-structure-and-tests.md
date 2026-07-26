---
kind: concept
status: strong
last_reviewed: 2026-07-26
sources:
  - ./index.md
  - ../../../../../src/passes/local_subtyping.mbt
  - ../../../../../src/passes/local_subtyping_test.mbt
  - ../../../../../src/passes/local_subtyping_wbtest.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
---

# `local-subtyping`: implementation and tests

## Upstream v131 map

| Source | Contract |
| --- | --- |
| `src/passes/LocalSubtyping.cpp` | GC-gated function-parallel scan, set/get collection, LUBs, structural dominance, declaration rewrite, get/tee repair, repeated ReFinalize |
| `src/ir/local-structural-dominance.h` | identifies reference locals with non-dominated gets |
| `test/lit/passes/local-subtyping.wast` | control refinalization, parameters, zero assignments, multiple LUBs, iteration, select/call-ref, nondefaultable locals, unreachable writes, non-null dominance, named/unnamed blocks, and ref-catch result boundaries |

The July 26, 2026 refresh used official Binaryen v131 and the hashes recorded in [`index.md`](./index.md).

## Starshine phase map

| Phase | Owner |
| --- | --- |
| module legacy-try guard and bounded fixed point | `local_subtyping_run_module_pass` |
| heap/reference subtyping | `ls_abs_heap_is_subtype`, `ls_heap_is_subtype`, `ls_ref_is_subtype` |
| pairwise and concrete-parent LUBs | `ls_ref_pair_lub`, `ls_ref_concrete_super_lub`, `ls_candidate_local_type` |
| raw typed-null and producer typing | `ls_ref_null_normalized_type`, `ls_raw_ref_producer_type` |
| raw/HOT assignment selection | `ls_collect_raw_assignments`, `ls_collect_assignments`, `ls_count_ref_body_local_writes_expr` |
| control-result refinalization | `ls_refine_control_results_expr` and shape-gated helpers |
| select/call-ref repair | `ls_refine_selects_expr` |
| non-null structural proof | `ls_non_null_dominated_linear_locals` |
| declaration rewrite | `ls_rewrite_func` |

## Test inventory

`src/passes/local_subtyping_test.mbt` covers:

- registry activation;
- child, concrete-parent, abstract-eq, and function-family LUBs;
- typed-null/exact-bottom and unreachable incompatible assignments;
- local.set/local.tee, parameter preservation, and no-default boundaries;
- repeated local-get, select, and call-ref refinement;
- straight-line, block, loop, if, branch, return, tail-call, throw, and try-table dominance;
- catch_ref/catch_all_ref conservative narrowing;
- historical validator boundaries and final module validation.

`src/passes/local_subtyping_wbtest.mbt` covers:

- ref-local write prefiltering;
- raw unreachable assignment typing and exact-bottom LUBs;
- official i31 control-result refinalization;
- validator-aligned abstract heap relationships.

`src/validate/gen_valid_tests.mbt` proves profile resolution, all seven aggregate members, deterministic aggregate sampling, external validation, and a visible trigger for every leaf.

Registry, dispatcher, preset, and CLI behavior remain covered in their existing owner tests.
