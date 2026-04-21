---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md
  - ../../../raw/research/0069-2026-03-26-pick-load-signs.md
  - ../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md
  - ../../../../../src/passes/pick_load_signs.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/pick_load_signs_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine `pick-load-signs` HOT-IR strategy

This page describes the **current local implementation**, not upstream Binaryen's AST pass.

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

The in-tree MoonBit pass handles both i32 and i64 families.

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

- rebuilds the exact load instruction with the chosen signedness
- preserves the same memarg and address child
- creates a replacement HOT node with `@ir.hot_build_heap(...)`
- deletes the temporary built node
- replaces the original load node via `pass_replace_node(...)`

This is a node-local opcode rewrite, not a structural control-flow rewrite.

That part is very close to the spirit of upstream Binaryen, even though the surrounding analysis is different.

## Raw fast-skip behavior in the local pipeline

The local pass manager adds two important fast paths that are local infrastructure rather than upstream semantics.

### Module-level no-memory skip

Before running the pass, the hot pipeline checks whether the module has any memory at all.
If not, it traces:

- `pass[pick-load-signs]:skip-no-memory`

and skips the pass.

### Function-level raw candidate scan

Before lifting a function, the local pass manager performs a cheap raw scan looking for:

- a narrow-load producer surface
- a `local.get`
- any extension-looking surface

If that cheap scan finds no plausible candidate family, the function is skipped with:

- `reason: no-pick-load-signs-candidates`

and the aggregated trace hook reports:

- `skip-raw reason=no-pick-load-signs-candidates count=...`

This is a useful local performance rule, but it is not part of Binaryen's AST implementation contract.

## Current test and replay surface

The in-tree local evidence includes:

- focused pass tests in `src/passes/pick_load_signs_test.mbt`
- registry / preset checks in `src/passes/registry_test.mbt`
- native debug-artifact replay in `src/cmd/cmd_wbtest.mbt`
- archived green parity and smoke evidence in `0069` and `0079`

Those local tests intentionally cover more than the official upstream lit file, especially around:

- i64 forms
- raw skip behavior
- idempotence
- multiple same-local producers

That is useful local coverage, but it also means the local suite is partly documenting Starshine's broader behavior, not only upstream Binaryen's smaller `version_129` surface.

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
- and broader than upstream in its i64 recognition surface.

That means future changes should answer one question explicitly:

- are we preserving Binaryen semantics,
- or are we preserving current Starshine behavior?

For this pass, those two questions are no longer exactly the same.
