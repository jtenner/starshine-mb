---
kind: research
status: working
last_reviewed: 2026-05-06
sources:
  - ../../../src/passes/optimize.mbt
  - ../../../src/passes/pass_manager.mbt
  - ../../../src/passes/registry_test.mbt
  - ../../../src/passes/optimize_test.mbt
  - ../../../src/passes/local_subtyping_test.mbt
  - ../../../src/passes/local_cse_test.mbt
  - ../../../src/passes/merge_locals_test.mbt
  - ../../../src/passes/avoid_reinterprets_test.mbt
  - ../../../src/cmd/cmd_wbtest.mbt
  - ../../binaryen/passes/index.md
  - ../../binaryen/passes/tracker.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../../agent-todo.md
related:
  - ../../binaryen/passes/index.md
  - ../../binaryen/passes/tracker.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
---

# 2026-05-06 Starshine pass audit

## Question

Audit all currently tracked Starshine pass spellings against the registry and the wiki, verify the active implemented passes against tests plus a direct Binaryen smoke lane, and identify concrete work that still needs to be done.

## Method

1. Read `src/passes/optimize.mbt` and `src/passes/pass_manager.mbt` as the source of truth for:
   - active hot passes
   - active module passes
   - presets
   - boundary-only names
   - removed names
2. Checked that every registry spelling maps to a living wiki dossier under `docs/wiki/binaryen/passes/`, allowing for known folder-name aliases.
3. Ran the in-repo test surface:
   - `moon test src/passes`
   - `moon test src/cmd`
4. Ran direct Binaryen smoke parity for every pass listed by `bun scripts/pass-fuzz-compare.ts --list-passes`:
   - `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0xA11D --max-failures 5 --pass <name> --out-dir .tmp/pass-audit-20260506/<name>`
5. Compared the current registry state against the top-level pass wiki catalog pages:
   - `docs/wiki/binaryen/passes/index.md`
   - `docs/wiki/binaryen/passes/tracker.md`
   - relevant per-pass landing pages where the catalog looked stale.

## Registry snapshot

From `src/passes/optimize.mbt` on 2026-05-06:

- Active implemented pass spellings: `38`
  - hot: `20`
  - module: `18`
- Presets: `2` (`optimize`, `shrink`)
- Boundary-only names: `37`
- Removed names: `12`

Every registry spelling has a living wiki home.
Known name-to-folder aliases checked in this audit:

- `redundant-set-elimination` -> `rse/`
- `remove-unused-nonfunction-module-elements` -> `remove-unused-non-function-elements/`
- `dead-argument-elimination-optimizing` -> `dae-optimizing/`
- `simplify-locals-no-structure` -> `simplify-locals-nostructure/`
- `re-reloop` -> `rereloop/`
- `simplify-locals-no-tee` -> `simplify-locals-notee/`
- `simplify-locals-no-tee-no-structure` -> `simplify-locals-notee-nostructure/`
- `simplify-locals-no-nesting` -> `simplify-locals-nonesting/`

## Test and smoke-audit result

### Repo tests

- `moon test src/passes`: **747 / 747 passed**
- `moon test src/cmd`: **130 / 130 passed**

### Direct compare-pass smoke summary

`bun scripts/pass-fuzz-compare.ts --list-passes` currently exposes `38` direct pass spellings.
The audit ran all `38`.

- Clean smoke parity in this audit: `32 / 38`
- Smoke mismatches found: `6 / 38`
- Validation failures: `0`
- Generator failures: `0`
- Command failures: `0`

Artifacts live under `.tmp/pass-audit-20260506/`.

### Smoke-green active passes

These passed the 100-case smoke lane in this audit:

- `avoid-reinterprets`
- `coalesce-locals`
- `code-folding`
- `code-pushing`
- `dead-code-elimination`
- `directize`
- `duplicate-function-elimination`
- `duplicate-import-elimination`
- `global-struct-inference`
- `heap-store-optimization`
- `heap2local`
- `local-cse`
- `local-subtyping`
- `merge-blocks`
- `merge-locals`
- `once-reduction`
- `optimize-casts`
- `pick-load-signs`
- `redundant-set-elimination`
- `remove-unused-module-elements`
- `remove-unused-names`
- `remove-unused-nonfunction-module-elements`
- `reorder-globals`
- `reorder-locals`
- `simplify-locals`
- `simplify-locals-no-structure`
- `simplify-locals-nostructure`
- `simplify-locals-notee-nostructure`
- `string-gathering`
- `tuple-optimization`
- `untee`
- `vacuum`

### Smoke failures that need follow-up

| Pass | Smoke result | Audit finding |
| --- | --- | --- |
| `global-refining` | `99/100` matches, `1` mismatch | Mismatch repro shows Starshine preserving a mutable `exnref` global where Binaryen narrows to `nullexnref`. This looks like a real nullability/type-tightening gap, not just a naming drift. |
| `memory-packing` | `96/100` matches, `4` mismatches | Repros show representation drift around empty/active data-segment rewriting. One case leaves Starshine with an empty segment plus a new active segment where Binaryen keeps a single active segment. |
| `optimize-instructions` | `5/10` matches before `maxFailuresHit` | Repros show canonicalization drift on constant folds: Starshine chooses signed op spellings (`lt_s`, `div_s`, `shr_s`, etc.) where Binaryen emits unsigned forms, plus `eqz` simplification shape drift. |
| `precompute` | `5/10` matches before `maxFailuresHit` | Repros share a dead-control cleanup shape where Starshine leaves an explicit `block` / `br_table` scaffold and Binaryen normalizes to `nop` padding before `unreachable`. |
| `remove-unused-brs` | `5/10` matches before `maxFailuresHit` | Repros share the same dead `br_table` / wrapper cleanup drift seen in the saved artifact family: Starshine keeps explicit branch scaffolding that Binaryen deletes. |
| `ssa-nomerge` | `5/10` matches before `maxFailuresHit` | Repros show local-declaration shaping drift: Binaryen introduces/removes temp locals differently than Starshine even when the body stays semantically similar. |

## Wiki alignment findings

## 1. Top-level pass catalog pages are stale

The top-level catalog pages do not currently match the active registry.

### `docs/wiki/binaryen/passes/tracker.md`

The tracker still says:

- active implemented passes in the registry: `29`

The actual registry now exposes `38` implemented pass spellings.

The tracker also still places several active passes in the unimplemented queue or omits them from the active table:

- `avoid-reinterprets`
- `code-folding`
- `local-cse`
- `local-subtyping`
- `merge-locals`
- `optimize-casts`
- `remove-unused-nonfunction-module-elements`
- plus the active alias spellings that affect the raw count story

### `docs/wiki/binaryen/passes/index.md`

The pass catalog still describes several active passes as removed or unimplemented, including:

- `code-folding`
- `optimize-casts`
- `local-subtyping`

That page also still groups some now-active dossiers under the “missing / newly-activated” queue rather than the active-implemented set.

## 2. Some per-pass landing/status pages are stale

The landing pages or Starshine-status subpages for some newly activated passes still contain removed/unimplemented wording even though the registry and dispatcher are active now.

Most obvious stale folders from this audit:

- `optimize-casts/`
- `code-folding/`
- `merge-locals/`
- `avoid-reinterprets/`
- `remove-unused-non-function-elements/`

`local-subtyping/` and `local-cse/` have already had their landing pages corrected, but top-level catalog drift still hides that correction.

## 3. Boundary-only and removed pass coverage is present

The audit did **not** find missing wiki coverage for any currently tracked boundary-only or removed registry name.
The problem is not missing dossiers; it is mainly:

- stale top-level categorization
- stale status wording in some active pass pages
- remaining implementation/parity work on a smaller subset of active passes

## What work needs to be done now

### A. Fix active-pass parity regressions found by this audit

Highest-priority behavior work surfaced by the smoke lane:

1. `optimize-instructions`
   - close constant-fold canonicalization drift vs Binaryen
   - decide whether signed/unsigned canonical form differences are intentional or bugs
2. `precompute`
   - remove the dead `block` / `br_table` control residue that Binaryen normalizes away
3. `remove-unused-brs`
   - finish dead branch-wrapper cleanup for the shared `br_table` residue family
4. `ssa-nomerge`
   - reconcile temp-local shaping with Binaryen or document/approve the divergence
5. `global-refining`
   - investigate the nullable `exnref` -> `nullexnref` tightening mismatch
6. `memory-packing`
   - align empty-segment / rewritten-segment normalization with Binaryen

### B. Repair stale wiki status surfaces

At minimum, refresh:

- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- active dossier pages that still claim removed/unimplemented status for:
  - `code-folding`
  - `optimize-casts`
  - `merge-locals`
  - `avoid-reinterprets`
  - `remove-unused-nonfunction-module-elements`

### C. Finish full signoff for smoke-green passes before calling them done

This audit only ran a **100-case smoke lane** for each active compare-pass-supported spelling.
It did **not** rerun the repo-standard full signoff ladder (`10000` compare-pass cases plus artifact lanes where applicable) for all passes.
So “smoke green in this audit” is weaker than “fully re-signed-off today”.

## Passes still not fully verified after this audit

These categories still need more verification work:

### Active passes with fresh smoke failures

- `global-refining`
- `memory-packing`
- `optimize-instructions`
- `precompute`
- `remove-unused-brs`
- `ssa-nomerge`

### Active passes that were only smoke-checked, not fully re-signed-off in this audit

All other direct compare-pass-supported active spellings still need the repo-standard `10000`-case parity rerun if the goal is same-day pass signoff rather than audit triage:

- `avoid-reinterprets`
- `coalesce-locals`
- `code-folding`
- `code-pushing`
- `dead-code-elimination`
- `directize`
- `duplicate-function-elimination`
- `duplicate-import-elimination`
- `global-struct-inference`
- `heap-store-optimization`
- `heap2local`
- `local-cse`
- `local-subtyping`
- `merge-blocks`
- `merge-locals`
- `once-reduction`
- `optimize-casts`
- `pick-load-signs`
- `redundant-set-elimination`
- `remove-unused-module-elements`
- `remove-unused-names`
- `remove-unused-nonfunction-module-elements`
- `reorder-globals`
- `reorder-locals`
- `simplify-locals`
- `simplify-locals-no-structure`
- `simplify-locals-nostructure`
- `simplify-locals-notee-nostructure`
- `string-gathering`
- `tuple-optimization`
- `untee`
- `vacuum`

### Registry presets not fully replayed in this audit

The preset spellings were not revalidated end-to-end here:

- `optimize`
- `shrink`

Those still need ordered-neighborhood and artifact replay rather than direct single-pass compare-pass smoke.

### Boundary-only and removed passes

These cannot be behavior-verified as active Starshine passes yet because the registry still marks them boundary-only or removed.
For them, the remaining work is implementation and later parity validation, not just re-running the current direct pass harness.

## Bottom line

The pass surface is in better shape than the top-level wiki currently suggests:

- tests are green
- every tracked pass spelling has a dossier
- `32 / 38` direct pass spellings were smoke-green today

But the audit found two kinds of real work:

1. **behavior/parity work** on `6` active passes
2. **wiki status repair** because the top-level pass catalogs still materially underreport the active implementation surface

So the repo is **not** in a state where the current tracker can be treated as the source of truth without cross-checking `src/passes/optimize.mbt`.
