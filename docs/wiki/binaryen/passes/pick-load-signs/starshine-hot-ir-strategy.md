---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0532-2026-05-06-pick-load-signs-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-pick-load-signs-current-main-recheck.md
  - ../../../raw/research/0455-2026-05-05-pick-load-signs-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-pick-load-signs-primary-sources.md
  - ../../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md
  - ../../../raw/research/0228-2026-04-21-pick-load-signs-implementation-followup.md
  - ../../../raw/research/0244-2026-04-22-pick-load-signs-primary-sources-and-code-map-followup.md
  - ../../../../../src/passes/pick_load_signs.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pick_load_signs_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./parity.md
  - ./starshine-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine `pick-load-signs` HOT-IR strategy

This page describes the **current local implementation**, not upstream Binaryen's AST pass.
For the concise Starshine status and code-map layer, start with [`./starshine-strategy.md`](./starshine-strategy.md).
For the upstream contract, start with [`./binaryen-strategy.md`](./binaryen-strategy.md).

## Current local surface

Starshine exposes `pick-load-signs` as an active hot pass with:

- descriptor name: `pick-load-signs`
- summary: `Pick narrower signed/unsigned load opcodes based on local use extension evidence.`
- required HOT analysis: `use_def`

The local descriptor also declares broad invalidation after mutation:

- CFG
- dominance
- liveness
- use-def
- effects
- loop info
- SSA

That is already a major structural difference from upstream Binaryen's tiny AST walker.

## Exact local code map

### Registry and preset placement

The public registry surface lives in `src/passes/optimize.mbt`:

- `pick_load_signs_descriptor()` declares the active HOT descriptor
- `pick_load_signs_summary()` provides the help text
- `pass_registry_entries()` registers `pick-load-signs` as a hot pass
- `optimize_preset_passes(...)` and `shrink_preset_passes(...)` place it after `heap-store-optimization` and before `precompute`

That file is the local answer to: “is this pass active, and where does it sit in the public preset order?”

### Pass-manager gates and dispatch

The HOT-pipeline integration lives in `src/passes/pass_manager.mbt`:

- `run_hot_pipeline_pls_candidate_scan_into(...)` does the cheap raw recursive instruction scan
- `run_hot_pipeline_pls_candidate_scan(...)` returns the three raw preconditions: candidate producer, `local.get`, and extension-looking surface
- `run_hot_pipeline_raw_pick_load_signs(...)` converts a failed raw scan into the `no-pick-load-signs-candidates` fast skip
- `run_hot_pipeline_apply_hot_pass(...)` enforces the module-level `skip-no-memory` rule and aggregates repeated raw-skip trace lines
- `run_hot_pipeline_run_descriptor(...)` dispatches the descriptor name `pick-load-signs` into `pick_load_signs_run(...)`

That means the practical local contract is not only the rewrite algorithm.
It also includes two performance-facing gates that upstream Binaryen does not have in this form:

- module-level no-memory skip
- function-level raw candidate screening before HOT lift

### Core algorithm owner file

The pass logic itself lives in `src/passes/pick_load_signs.mbt`.
The cleanest read-along is:

- `pls_scan_candidate_loads(...)`
  - finds exact `LocalSet(Load(...))` HOT candidates from use-def write nodes
- `pls_analyze_candidates(...)`
  - gathers use evidence per local, reusing `use_def` read and use-site queries
- `pls_extension_from_parent(...)`
  - classifies direct extend, mask, and shift-pair evidence
- `pls_extension_from_grandparent_zero_ext(...)`
  - classifies i32 shift-pair grandparent evidence
- `pls_extension_from_grandparent_zero_ext64(...)`
  - classifies the local i64 shift-pair grandparent family
- `pls_target_signedness(...)`
  - applies the same signed-weighted final choice policy the local port currently uses
- `pls_rewrite_candidates(...)`
  - rebuilds the exact load opcode with the chosen signedness and replaces the HOT node
- `pick_load_signs_run(...)`
  - drives the scan / analyze / rewrite sequence and emits the local trace labels

### Focused local proof lanes

The local tests are intentionally split across multiple files:

- `src/passes/pick_load_signs_test.mbt`
  - focused pass behavior: direct signed positives, zero-mask positives, shift-pair positives, unknown-use bailouts, tee bailouts, same-local multi-candidate rewrites, idempotence, and the no-memory skip
- `src/passes/perf_test.mbt`
  - raw-skip behavior: no-lift and aggregated `skip-raw reason=no-pick-load-signs-candidates` trace behavior
- `src/passes/registry_test.mbt`
  - registry category, descriptor requirement, and preset placement checks
- `src/cmd/cmd_wbtest.mbt`
  - CLI-visible `--pick-load-signs` replay on the debug artifact and the saved generated-artifact predecessor lane

## How the local pass works today

### 1. Candidate discovery is HOT/use-def-based

The local pass scans local write nodes via `@ir.local_write_nodes_borrowed(use_def, local_idx)` and selects candidates when:

- the write node is a `HotOp::LocalSet`
- its child is a live `HotOp::Load`
- the exact load instruction is one of the supported narrow-load opcodes

So the local pass is still intentionally narrow.
But it learns that narrowness through HOT/use-def data, not through AST visitor callbacks.

### 2. Usage analysis is read-site based

For each candidate local, the local implementation gathers:

- all local read nodes through `@ir.local_read_nodes_borrowed(use_def, local_idx)`
- all use sites of each read via `@ir.node_use_sites_borrowed(use_def, read_id)`

It then tries to classify each use site as:

- signed evidence
- unsigned evidence
- or invalid / unknown

If any use site is unknown, the local usage record is marked invalid.

That is conceptually similar to Binaryen's “all uses must be recognized” rule, but the mechanism is very different.

### 3. The local implementation recognizes a broader family than upstream

The in-tree MoonBit pass handles both i32 and i64 families in code.

Recognized direct extend evidence includes:

- `i32.extend8_s`
- `i32.extend16_s`
- `i64.extend8_s`
- `i64.extend16_s`
- `i64.extend32_s`
- `i64.extend_i32_s`
- `i64.extend_i32_u`

Recognized zero-extension evidence includes:

- `i32.and` low-bit masks
- `i64.and` low-bit masks

Recognized shift-pair evidence includes:

- `i32.shl` followed by `i32.shr_s` / `i32.shr_u`
- `i64.shl` followed by `i64.shr_s` / `i64.shr_u`

The local code also caches shift-pair classification per parent node in `PLSShiftExtCacheEntry` so repeated grandparent scans do not redo the same work.

## Biggest local-vs-upstream difference

The most important current divergence is:

- upstream Binaryen `version_129` `pick-load-signs` is effectively i32-only
- local Starshine `pick-load-signs` explicitly recognizes i64 families too

That does not mean the local pass is necessarily wrong.
But it does mean the local pass is broader than the official source contract documented in this dossier.
Keep that difference explicit.

## Rewrite strategy

When a candidate should flip, the local pass:

- rebuilds the exact load instruction with the chosen signedness via `pls_load_with_signedness(...)`
- preserves the same memarg and address child
- creates a replacement HOT node with `@ir.hot_build_heap(...)`
- deletes the temporary built node
- replaces the original load node via `pass_replace_node(...)`

This is a node-local opcode rewrite, not a structural control-flow rewrite.
That part is close to the spirit of upstream Binaryen even though the surrounding analysis is different.

## Raw fast-skip behavior in the local pipeline

The local pass manager adds two important fast paths that are local infrastructure rather than upstream semantics.

### Module-level no-memory skip

Before running the pass, `run_hot_pipeline_apply_hot_pass(...)` checks `run_hot_pipeline_module_has_memory(mod_)`.
If the module has no defined or imported memory, it traces:

- `pass[pick-load-signs]:skip-no-memory`

and skips the pass.

### Function-level raw candidate scan

Before lifting a function, `run_hot_pipeline_raw_pick_load_signs(...)` uses `run_hot_pipeline_pls_candidate_scan(...)` to look for:

- a narrow-load producer surface
- a `local.get`
- any extension-looking surface

If that cheap scan finds no plausible candidate family, the function is skipped with:

- `reason: no-pick-load-signs-candidates`

and the aggregated trace hook later reports:

- `skip-raw reason=no-pick-load-signs-candidates count=...`

`src/passes/perf_test.mbt` locks both the no-lift and aggregation behavior.

## Current test and replay surface

The in-tree local evidence includes:

- focused pass tests in `src/passes/pick_load_signs_test.mbt`
- raw-skip perf coverage in `src/passes/perf_test.mbt`
- registry / preset checks in `src/passes/registry_test.mbt`
- CLI and debug-artifact replay in `src/cmd/cmd_wbtest.mbt`

Important honesty note:

- the code clearly supports broader i64 families
- but the focused local tests do **not** yet isolate dedicated i64 positive rewrite cases

So the correct current wording is:

- explicit local tests directly lock i32 and raw-skip behavior
- broader i64 support is source-confirmed in code and still covered only indirectly by broader replay/fuzz evidence

That narrower test statement replaces the older over-broad claim that dedicated local tests already covered i64 forms directly.

## What future strict-parity work must preserve

If Starshine wants to stay as close as possible to Binaryen `version_129`, future work should keep these distinctions explicit:

- exact non-tee `local.set(load ...)` producer requirement
- all-use recognition requirement
- signed-tie weighting rule
- atomic-load exclusion
- the fact that upstream `pick-load-signs` itself is effectively i32-only

And if Starshine intentionally keeps the broader i64 support, that should remain a documented divergence rather than an accidental one.

## Practical maintenance rule

Treat the current local implementation as:

- broadly green on present artifact and focused fuzz evidence,
- structurally different from upstream,
- broader than upstream in its coded i64 recognition surface,
- and narrower in explicitly isolated local i64 test coverage than the older page claimed.

That means future changes should answer two questions explicitly:

- are we preserving Binaryen semantics?
- are we preserving current Starshine behavior?

For this pass, those two questions are no longer exactly the same.
