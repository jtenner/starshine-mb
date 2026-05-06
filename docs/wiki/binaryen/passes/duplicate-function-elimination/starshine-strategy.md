---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0524-2026-05-06-duplicate-function-elimination-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-04-duplicate-function-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-duplicate-function-elimination-validation-primary-sources.md
  - ../../../raw/research/0425-2026-04-27-duplicate-function-elimination-validation-bridge.md
  - ../../../raw/binaryen/2026-04-26-duplicate-function-elimination-current-main-and-starshine-strategy-health.md
  - ../../../raw/research/0399-2026-04-26-duplicate-function-elimination-strategy-health.md
  - ../../../raw/binaryen/2026-04-22-duplicate-function-elimination-primary-sources.md
  - ../../../raw/research/0242-2026-04-22-duplicate-function-elimination-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/duplicate_function_elimination_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./type-compaction-and-metadata.md
  - ./scheduler-validation-and-parity.md
  - ./parity.md
---

# Starshine strategy for `duplicate-function-elimination`

## First correction

Despite the older historical page filename, this is **not** a HOT-IR pass in Starshine today.
It is an active **module pass**.
That is the honest description for both the upstream Binaryen contract and the current local implementation.

The 2026-04-26 health cleanup renamed the living page from `starshine-hot-ir-strategy.md` to `starshine-strategy.md` so the filename no longer contradicts the strategy. Older raw/research notes may still mention the historical filename as immutable audit evidence.

## Why Starshine keeps it module-scoped

Even upstream Binaryen DFE is whole-module:

- it compares defined functions against other defined functions
- it rewrites function references across bodies and module-level surfaces
- it cares about survivor choice and module ordering

Current Starshine adds still more module-only work around that core:

- compactable element-expression canonicalization
- duplicate simple function-type compaction after a successful merge
- broad type-index rewriting needed by that compaction
- name-section stripping
- function-annotation-section rewrite bookkeeping

So the practical rule is simple:

- keep `duplicate-function-elimination` documented and tested as a module pass
- do not force it into HOT-IR terminology just for symmetry with the hot-pass folders

## Public code-location map

### 1. Registry and dispatcher surface

- `src/passes/optimize.mbt:241`
  - registers `duplicate-function-elimination` as an active **module pass** entry, not a hot pass
- `src/passes/pass_manager.mbt:8672-8673`
  - dispatches the module-pass name to `dfe_run_module_pass_with_perf(...)`
- `src/passes/optimize.mbt:379-402`
  - current public `optimize` / `shrink` presets do **not** include DFE

That already tells readers two important local facts:

- the pass is public and runnable by name
- but it is not yet scheduled inside the public presets the way upstream Binaryen schedules DFE in its no-DWARF optimizer

## 2. Core one-round duplicate-detection and rebuild loop

The current local core lives in `src/passes/duplicate_function_elimination.mbt:3245-3534`.

The main entrypoints are:

- `dfe_iteration(...)` at `:3245-3498`
- `dfe_run_module_pass_with_perf(...)` at `:3500-3532`
- `dfe_run_module_pass(...)` at `:3534-3536`

What this local core does:

1. computes a canonical-type map up front when simple duplicate function types exist
2. normalizes function bodies against that map before equality comparison
3. hashes candidate functions into local collision groups
4. exact-compares only within those groups
5. keeps the earliest equal function as the survivor
6. rebuilds the function/type arrays for kept definitions
7. rewrites function indices across the module
8. then runs the extra local cleanup stages described below

The most important current local boundary is here too:

- this is still **one explicit DFE iteration** today
- the pass does not yet model Binaryen's option-dependent multi-round behavior

That exact limitation is why the local test suite intentionally locks a single-pass transitive-unlock result.

## 3. Function-reference rewrite surface

The function-index rewrite engine lives in `src/passes/duplicate_function_elimination.mbt:2523-2827`.

The highest-value owner functions are:

- `dfe_rewrite_func_idx(...)` at `:2523-2535`
- `dfe_rewrite_instruction_func_idxs(...)` at `:2537-2588`
- `dfe_rewrite_module_func_idxs(...)` at `:2712-2827`

This is where the current local pass rewrites the survivor mapping through module surfaces such as:

- direct calls and `ref.func`
- exported function indices
- `start`
- element segments
- other module-level function-index carriers

This is the local mirror of the core upstream Binaryen DFE contract.

## 4. Local extra cleanup that goes beyond upstream DFE proper

### Element canonicalization and name stripping

- `dfe_canonicalize_elem_kind(...)` / `dfe_canonicalize_elem_segments(...)` at `src/passes/duplicate_function_elimination.mbt:62-114`
- `dfe_strip_name_sec(...)` at `:116-118`

These helpers are Starshine-local extras.
They canonicalize compactable `ref.func` element-expression segments back to `funcs` form and drop the name section.

### Duplicate simple-type compaction

- `dfe_duplicate_simple_type_canonical_map(...)` at `src/passes/duplicate_function_elimination.mbt:142-183`
- `dfe_canonicalize_duplicate_simple_type_indices(...)` at `:3172-3243`

This is the main local feature that most obviously goes beyond upstream Binaryen DFE.
It only runs after a successful function merge and then compacts duplicate simple function types.

### Wide type-index rewriting needed by that compaction

The type-rewrite machinery spans most of the file because it must reach many type-bearing surfaces:

- scan-and-rewrite helpers begin around `src/passes/duplicate_function_elimination.mbt:185-2394`
- the function-body scan path most readers should start from is `dfe_scan_rewrite_func_type_idxs(...)` at `:1088-1116`
- the whole-module type rewrite entrypoint is `dfe_rewrite_module_type_idxs(...)` at `:2394-2521`

The important teaching point is not every helper name.
It is the contract:

- once Starshine compacts duplicate simple types, it must rewrite typed blocks, typed selects, concrete ref forms, call-indirect/call-ref signatures, GC type uses, and related module metadata coherently

### Annotation and type-name repair

- `dfe_rewrite_func_annotation_sec(...)` / `dfe_rewrite_func_annotation_sec_in_module(...)` at `src/passes/duplicate_function_elimination.mbt:2663-2711`
- `dfe_rewrite_type_name_sec(...)` at `:2903-2940`

These helpers are another clear line between upstream DFE proper and the broader local cleanup bundle.

## 5. How the current local pass is ordered

`dfe_run_module_pass_with_perf(...)` at `src/passes/duplicate_function_elimination.mbt:3500-3532` makes the local stage order explicit:

1. run the one-round duplicate-elimination core
2. if nothing merged, still canonicalize compactable element segments and strip names
3. if something merged, canonicalize compactable element segments
4. then compact duplicate simple types and rewrite the module accordingly

That is a very different story from upstream Binaryen's smaller hash/equality/rewrite loop.
The local docs should keep saying that plainly.

## Current strengths

- exact module-pass ownership is now easy to trace in one file
- whole-module function-reference rewriting is explicit and tested
- the local extra-cleanup bundle is substantial and documented rather than hidden
- perf hooks are already wired through the module-pass entrypoints

## Current deliberate differences from Binaryen

### Narrower than Binaryen

- one explicit DFE iteration instead of Binaryen's option-dependent multi-round budget
- no current public `optimize` / `shrink` preset scheduling for DFE

### Broader than Binaryen

- element-expression canonicalization back to `funcs`
- duplicate simple function-type compaction
- broad type-index rewriting required by that compaction
- name-section stripping
- function-annotation-section rewrite bookkeeping

That two-way split is the main parity rule for this folder.

## Read-along test map

Focused local pass tests live in `src/passes/duplicate_function_elimination_test.mbt`:

- `:99-194`
  - rewrites function references through call / `ref.func` / export / start / elem surfaces
- `:196-252`
  - locks the current **single-pass** transitive-unlock boundary
- `:254-698`
  - locks duplicate simple-type compaction and the resulting typed block / typed select / concrete-ref rewrite surfaces
- `:700-764`
  - locks compactable element-expression canonicalization even without function merges
- `:766-848`
  - locks name stripping and annotation-map rewrite bookkeeping

CLI coverage lives in `src/cmd/cmd_wbtest.mbt:4010-4036`, which proves the explicit `--duplicate-function-elimination` command-line surface.

## 2026-05-06 direct validation refresh

The refreshed direct explicit-pass lane is green after the fuzzer / compare harness changes:

- `moon info`, `moon fmt`, and `moon test` passed.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass duplicate-function-elimination --out-dir .tmp/pass-fuzz-duplicate-function-elimination` reported `6759 / 10000` compared cases, `6759` normalized matches, `0` mismatches, and `20` Binaryen empty-recursion-group parser/canonicalization command failures.

This proves the current direct module-pass surface under the refreshed harness. It does not change the current one-iteration boundary or add DFE to public presets.

## Practical validation rule

For the full scheduler / iteration checklist, read [`scheduler-validation-and-parity.md`](./scheduler-validation-and-parity.md). It makes explicit that focused explicit-pass tests do not yet prove Binaryen-equivalent preset scheduling, because Starshine currently has one duplicate-elimination iteration and omits DFE from public `optimize` / `shrink` presets.

When you need to validate or review current Starshine behavior, read the code in this order:

1. `src/passes/optimize.mbt:231-240`
2. `src/passes/pass_manager.mbt:8627-8648`
3. `src/passes/duplicate_function_elimination.mbt:3245-3534`
4. `src/passes/duplicate_function_elimination.mbt:2523-2827`
5. `src/passes/duplicate_function_elimination.mbt:3172-3243`
6. `src/passes/duplicate_function_elimination_test.mbt:99-848`

That path gives the cleanest local explanation from registry -> dispatcher -> module-pass core -> rewrite surface -> extra cleanup -> proof tests. After that, use [`scheduler-validation-and-parity.md`](./scheduler-validation-and-parity.md) to decide whether a change is preserving explicit-pass behavior, changing local extra cleanup, or trying to close the Binaryen scheduler/iteration gap.
