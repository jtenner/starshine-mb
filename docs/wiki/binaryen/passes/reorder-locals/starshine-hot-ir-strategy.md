---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0540-2026-05-06-reorder-locals-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-reorder-locals-current-main-recheck.md
  - ../../../raw/research/0472-2026-05-05-reorder-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-reorder-locals-validation-primary-sources.md
  - ../../../raw/research/0430-2026-04-27-reorder-locals-validation-bridge.md
  - ../../../raw/binaryen/2026-04-22-reorder-locals-primary-sources.md
  - ../../../raw/research/0253-2026-04-22-reorder-locals-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0237-2026-04-21-reorder-locals-starshine-strategy-followup.md
  - ../../../raw/research/0142-2026-04-20-reorder-locals-binaryen-research.md
  - ../../../raw/research/0073-2026-04-02-reorder-locals-binaryen-comparison.md
  - ../../../raw/research/0074-2026-04-02-binaryen-multivalue-call-local-disparity.md
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
  - ./names-roundtrip-and-porting.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ./parity.md
  - ./multivalue-call-scope.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine module-pass strategy for `reorder-locals`

This page describes the **current local MoonBit implementation**, not the full upstream Binaryen `ReorderLocals.cpp` contract. For signoff sequencing and the distinction between explicit-pass correctness and preset-readiness, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

The 2026-05-05 current-main recheck keeps the current policy explicit: the standalone module pass is active, while public `optimize` / `shrink` scheduling remains guarded by `src/passes/optimize_test.mbt:390` until neighboring local-pass coverage and ordered no-DWARF replay evidence are ready.
The 2026-05-06 refreshed direct signoff then re-proved the explicit pass with 6759/10000 compared cases, 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group command failures; see [`../../../raw/research/0540-2026-05-06-reorder-locals-direct-revalidation.md`](../../../raw/research/0540-2026-05-06-reorder-locals-direct-revalidation.md).
For the immutable manifests of the reviewed official Binaryen release, source, and dedicated test URLs behind the comparison on this page, see [`../../../raw/binaryen/2026-04-22-reorder-locals-primary-sources.md`](../../../raw/binaryen/2026-04-22-reorder-locals-primary-sources.md) and [`../../../raw/binaryen/2026-05-05-reorder-locals-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-reorder-locals-current-main-recheck.md).

## Current local surface

The upstream bridge for this local page stays small and explicit:

- reviewed Binaryen `version_129` owner file: `src/passes/ReorderLocals.cpp`
- reviewed core implementation region: lines `65-162`
- reviewed local owner file: `src/passes/reorder_locals.mbt`
- reviewed local module-pass entry: `reorder_locals_run_module_pass(...)` at `src/passes/reorder_locals.mbt:544`

That makes the Starshine-vs-Binaryen mapping easy to follow without pretending the local module-pass adaptation lives in the same representation layer as upstream.

Starshine exposes `reorder-locals` as an active **module pass** with:

- summary text: `Sort body locals by access frequency and drop unaccessed body locals.`
- registry category: `module_pass`
- explicit module-pass dispatch through `pass_manager.mbt`
- CLI support through `--reorder-locals`
- an intentional policy of keeping the pass out of the public `optimize` and `shrink` presets until the missing neighboring Binaryen locals passes land

The most important local rule is:

- **Starshine implements `reorder-locals` at the boundary-module layer because correctness here includes type-section parameter lookup, local-name rewriting, and stale raw-name-payload invalidation.**

So despite the filename pattern used elsewhere in the pass wiki, this is not a HOT-IR pass.

## Current local code map

The easiest way to follow the in-tree implementation is this file map:

- `src/passes/reorder_locals.mbt:2`
  - summary string used by the registry and docs
- `src/passes/reorder_locals.mbt:118`
  - `rl_scan_instruction(...)`: counts `local.get`, `local.set`, and `local.tee` accesses across nested boundary instructions
- `src/passes/reorder_locals.mbt:138`
  - `rl_sort_used_body_locals(...)`: descending-count plus first-use ordering over used body locals
- `src/passes/reorder_locals.mbt:280`
  - `rl_defined_func_param_cache(...)`: module-type-section lookup for each defined function's parameter list
- `src/passes/reorder_locals.mbt:312`
  - `rl_rewrite_func(...)`: no-op fast path, body-local rebuild, optional index rewrite, and grouped-local-run reconstruction
- `src/passes/reorder_locals.mbt:410`
  - `rl_rewrite_local_names(...)`: per-defined-function local-name-map repair while preserving imported-function entries
- `src/passes/reorder_locals.mbt:467`
  - `rl_rewrite_name_sec(...)`: full name-section rebuild and stale raw-payload invalidation trigger
- `src/passes/reorder_locals.mbt:544`
  - `reorder_locals_run_module_pass(...)`: end-to-end module rewrite over code and names
- `src/passes/reorder_locals_test.mbt:210`
  - multiple-defined-function and differing-param-arity coverage
- `src/passes/reorder_locals_test.mbt:280`
  - params-only no-op coverage
- `src/passes/reorder_locals_test.mbt:328`
  - write-only-local survival coverage
- `src/passes/reorder_locals_test.mbt:391`
  - nested `block` / `loop` / `if` / `try_table` index rewrite coverage
- `src/passes/reorder_locals_test.mbt:454`
  - local-name rewrite plus raw-name-payload clearing coverage
- `src/passes/reorder_locals_test.mbt:500`
  - Binaryen-materialized carrier-shape ordering coverage
- `src/passes/pass_manager.mbt:8684`
  - active module-pass dispatch site
- `src/passes/optimize.mbt:257`
  - registry entry
- `src/passes/optimize_test.mbt:390`
  - preset exclusion policy test
- `src/passes/registry_test.mbt:56`
  - module-pass-category assertion
- `src/cmd/cmd_wbtest.mbt:4296`
  - explicit CLI pass execution coverage

## How the local pass works today

## 1. It stays module-scoped because params and names live outside HOT IR

The local pass begins from full module state, not from a lifted HOT function.
That is deliberate.

Unlike the pure upstream AST view, Starshine needs module context for two things before it can even sort body locals correctly:

- parameter counts come from the function type section, not from the body-local run list
- local names live in `NameSec.local_names`, with an additional `raw_name_sec_payload` that must be invalidated when local layout changes

That is why the implementation starts with helpers like:

- `rl_module_subtypes(...)`
- `rl_params_for_type_idx(...)`
- `rl_defined_func_param_cache(...)`

A HOT-only pass would not own those boundary repairs cleanly.

## 2. The local access scan is intentionally close to Binaryen, but explicit about `local.tee`

`rl_scan_instruction(...)` recurses through:

- `block`
- `loop`
- `if`
- `try_table`

and records accesses for:

- `LocalGet`
- `LocalSet`
- `LocalTee`

That is the main local representation difference from Binaryen.
Upstream Binaryen counts tees through `LocalSet` because tee is encoded there; Starshine has a distinct boundary instruction, so the local pass spells the tee case out directly.

Durable consequence:

- write-only and tee-only body locals stay live locally for the same reason they do upstream

## 3. The sorter works only on used body locals

Instead of sorting every local and truncating a zero-count suffix afterward the way Binaryen does, Starshine collects only the body locals whose first use was actually observed.
Then `rl_sort_used_body_locals(...)` sorts that list by:

- descending access count
- then first-use rank
- then original index as the stable fallback

That is a smaller local data structure than Binaryen's full `newToOld`-over-all-locals array, but it preserves the same beginner-visible ordering rule for surviving body locals.

The crucial practical fast path is in `rl_rewrite_func(...)`:

- if every body local was used
- and the used list is already the original body-local prefix
- the function returns unchanged without rebuilding names or rewriting indices

So the local pass is deliberately cheap on already-canonical functions.

## 4. Rebuilding locals is run-based, not flat-list-only

The boundary `@lib.Func` stores locals as grouped runs.
To rebuild them, the local pass:

- flattens the existing body-local runs with `rl_flatten_locals(...)`
- picks the surviving types in sorted order
- rebuilds grouped runs with `rl_push_local_run(...)`

That means the Starshine strategy is not just “rewrite indices.”
It also preserves the repo's grouped-local representation while still dropping the untouched suffix logically.

This is one of the biggest local-port details a future refactor must preserve.

## 5. Expression rewrites are recursive boundary rewrites, not HOT-node remaps

If the used-body-local order changed, `rl_rewrite_func(...)` calls `rl_rewrite_expr(...)`, which recursively rewrites nested local users under:

- `block`
- `loop`
- `if`
- `try_table`

The rewrite surface is intentionally tiny:

- `local.get`
- `local.set`
- `local.tee`

That matches the upstream teaching: this is not a control pass and not a deep dataflow optimizer. It is a local-index remapper threaded through nested boundary syntax.

## 6. Name-section repair is part of the local algorithm, not post-pass cleanup

When any defined function changes, `reorder_locals_run_module_pass(...)` also rebuilds the name section.
The local code keeps three rules explicit:

- rewrite local names only for changed defined functions
- preserve imported-function local-name entries unchanged
- drop stale raw name payloads by rebuilding the module with the rewritten `NameSec`

That behavior lives in:

- `rl_rewrite_name_map(...)`
- `rl_rewrite_local_names(...)`
- `rl_rewrite_name_sec(...)`
- `rl_rebuild_module(...)`

This is the strongest reason the pass should be taught as module-scoped in Starshine even though the optimizer logic itself is per-function.

## 7. Preset policy is intentionally conservative

The registry exposes `reorder-locals` as implemented, but the public presets still refuse to schedule it.
That policy is locked by:

- `src/passes/optimize_test.mbt:390`

The reason is not that the local pass is unstable.
It is that upstream Binaryen runs `reorder-locals` in a cluster with neighboring locals passes that Starshine still lacks, so replaying those preset slots today would overstate parity.

The honest current policy is:

- explicit pass: yes
- module-pass implementation: yes
- preset slot parity claim: not yet

## What the local pass does not do

Compared with the full upstream Binaryen story around repeated scheduler placement and print-roundtrip behavior, Starshine currently does **not** claim these stronger things in the public presets:

- no-DWARF slot-for-slot scheduling parity
- broader neighboring locals-pass interactions from missing passes like `simplify-locals-nostructure`, `local-subtyping`, and `coalesce-locals`
- HOT-IR ownership of the pass

And compared with heavier nearby locals passes, the local implementation still does **not** do:

- liveness reasoning
- coalescing
- dead-store elimination
- type refinement
- multivalue packaging repair

## Biggest local-vs-upstream difference to keep explicit

The most important durable correction is:

- upstream Binaryen `reorder-locals` is a tiny per-function AST pass whose visible contract includes local-name repair and print-roundtrip order
- local Starshine `reorder-locals` is a **module pass** because those same visible contracts cross this repo's type-section, code-section, and name-section boundaries

That is an implementation-boundary difference, not a semantic disagreement about the ordering rule itself.

## Practical maintenance rule

Treat the current Starshine implementation as:

- a real active module pass
- a faithful local port of the core access-count plus first-use sorter
- a boundary-owned rewrite that must keep grouped locals, local names, imported-name entries, and raw-name-payload invalidation in sync

If future work ever tries to “simplify” this pass into a smaller per-function helper, the key question should be:

- who now owns parameter lookup and local-name / raw-name repair?

For this repo, that question is the difference between a correct port and an incomplete one.
