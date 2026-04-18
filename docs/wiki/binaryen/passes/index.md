---
kind: entity
status: supported
last_reviewed: 2026-04-18
sources:
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/registry_test.mbt
  - ./late-pipeline-dispatch.md
related:
  - ../no-dwarf-default-optimize-path.md
  - ./late-pipeline-dispatch.md
---

# Binaryen Pass Folder Map

## Scope

- This page is the namespace catalog for active implemented pass folders under `docs/wiki/binaryen/passes/`.
- Treat each pass folder as the stable home for:
  - `wat-shapes.md` when the pass is meaningfully shape-driven
  - `binaryen-strategy.md`
  - `starshine-hot-ir-strategy.md`
  - pass-specific notes, decisions, or parity pages

## Active Module Passes

- [`duplicate-function-elimination/index.md`](duplicate-function-elimination/index.md) - Expanded folder with hub page, shapes, strategy pages, metadata notes, and parity status.
- [`remove-unused-module-elements/index.md`](remove-unused-module-elements/index.md) - Expanded folder with hub page, shapes, strategy pages, retention rules, and parity status.
- [`memory-packing/index.md`](memory-packing/index.md) - Active module pass; the landing page now also records the current non-GitHub `--memory-packing` terminology sanity check.
- [`once-reduction/index.md`](once-reduction/index.md) - Active module pass; the landing page now also records the current non-GitHub `--once-reduction` terminology sanity check.
- [`global-refining/index.md`](global-refining/index.md) - Active module pass; the landing page now also records the current non-GitHub `--global-refining` terminology sanity check.
- [`global-struct-inference/index.md`](global-struct-inference/index.md) - Folder now has a landing page plus the existing parity note.
- [`reorder-locals/index.md`](reorder-locals/index.md) - Folder now has a landing page plus parity and multivalue-call scope notes.

## Active Hot Passes

- [`ssa-nomerge/index.md`](ssa-nomerge/index.md) - Folder now has a landing page plus the current parity note for the fixed dead-param family, fresh green compare evidence, and the remaining `Func 523` / `suspicious-escape-carrier` trace-level raw-lowering skips.
- [`vacuum/index.md`](vacuum/index.md) - Active hot pass; the landing page now records the current non-GitHub `unreachable`-preservation drift note plus the exact remaining slot-23 / slot-33 ordered-audit blockers.
- [`dead-code-elimination/index.md`](dead-code-elimination/index.md) - Active hot pass; the landing page now records the current `Dce` naming evidence plus the 2026-04-18 ordered-audit fact that DCE is expensive-but-successful rather than a current corruption blocker.
- [`remove-unused-names/index.md`](remove-unused-names/index.md) - Folder now has a landing page plus the current parser-gap note.
- [`remove-unused-brs/index.md`](remove-unused-brs/index.md) - Expanded folder with hub page, shape catalog, strategy pages, bailout notes, parity status, the retired slot-14 large-condition guard, and the newer upstream branches-to-traps drift note.
- [`optimize-instructions/index.md`](optimize-instructions/index.md) - Active hot pass; the landing page now records the fully retired slot-16 `Func 652` / `Func 1818` HOT-lower bugs and the remaining later slot-44 blocker.
- [`heap-store-optimization/index.md`](heap-store-optimization/index.md) - Active hot pass; the landing page now records the direct Debian manpage as the stronger current non-GitHub naming source and notes that the published `wasm_opt::Pass` enum page still omits `HeapStoreOptimization` even though that same page explicitly says its exposed variants follow command-line pass names with Rust capitalization conventions.
- [`heap2local/index.md`](heap2local/index.md) - Folder now has a landing page plus the current parity note, current `Heap2Local` terminology sanity check, and the ordered-audit note that H2L is expensive-but-successful rather than currently corrupting the generated artifact.
- [`pick-load-signs/index.md`](pick-load-signs/index.md) - Folder now has a landing page plus the current parity note.
- [`tuple-optimization/index.md`](tuple-optimization/index.md) - Expanded folder with shapes, strategies, scheduler notes, reduced repro tracking, and parity status.
- [`precompute/index.md`](precompute/index.md) - Active hot pass; the landing page now records the current non-GitHub child-retention plus March 2026 GC-write, GC-atomic no-fold, and multibyte-array `array.load` no-fold drift notes, alongside the exact slot-19 `func 108` raw-result-loss blocker.
- [`simplify-locals/index.md`](simplify-locals/index.md) - Expanded folder with overview, shapes, strategies, implementation map, validation, performance, and parity status.

## Tail Dispatch Notes

- [`late-pipeline-dispatch.md`](late-pipeline-dispatch.md) - Compact `-O4z` / `shrink` tail roster and dispatch note, now also recording that the non-GitHub Debian manpage, docs.rs pass-enum page, and bundled README overview are all incomplete in different ways; in particular the README mirror currently misspells `RemoveUnusedBrs` as `RemoveUnsedBrs`, the Chromium refs page still shows `version_129` as the newest directly reachable release tag, the current `main` changelog still lacks a newer documented optimization-pass addition, and the living ordered-audit summary now names the exact five remaining generated-artifact blockers instead of only the broader failing-pass cluster.

## Current Maintenance Rule

- Every implemented pass should now have a stable folder landing page, even when detailed subpages are still missing.
- Expand folders from scaffold to full multi-entry form in priority order, starting from passes that already have artifact parity work or active backlog slices.
- The 2026-04-18 non-GitHub terminology check in [`late-pipeline-dispatch.md`](late-pipeline-dispatch.md) found the current upstream-facing pass names still aligned with this folder map; the direct Debian manpage evidence explicitly covers `--heap-store-optimization` and `--remove-unused-brs`, while the published `wasm_opt::Pass` enum page is incomplete enough that it omits `HeapStoreOptimization` entirely. Keep treating Binaryen `Dce` versus the wiki's `dead-code-elimination` label and Binaryen `precompute-propagate` versus the repo's `precompute` landing page as aliases, not as rename pressure.
- That same check now has directly reachable Chromium-hosted release notes through `version_129`, and the public Chromium refs listing still shows `version_129` as the newest release tag visible without GitHub. The pass-addition story visible in those public notes is still the same one already tracked here: `--minimize-rec-groups` is present by `version_119`, `--string-lifting` and `TypeRefiningGUFA` by `version_124`, `ReorderTypes` by `version_125`, and `--remove-relaxed-simd` plus `--strip-toolchain-annotations` by `version_126`.
- The Debian manpage, docs.rs enum, and bundled README overview remain useful terminology aids, but they are incomplete in different directions: Debian already shows some upstream-only passes such as `--minimize-rec-groups` and `--string-lowering`; the docs.rs enum explicitly says its exposed variants follow command-line pass names with Rust capitalization conventions, but it still only surfaces older entries like `RemoveUnusedTypes` and omits newer names such as `HeapStoreOptimization`, `MinimizeRecGroups`, and `StringLowering`; and the README overview currently misspells `RemoveUnusedBrs` as `RemoveUnsedBrs`. Keep relying on the Chromium-hosted release-note trail when the question is "was a newer upstream-only pass added or removed?" rather than just "does this older public package still know this pass name?".
- The newer reachable `version_127` / `version_128` / `version_129` changelog sections did not surface another optimization-pass addition relevant to this catalog, and the current Chromium-mirror `main` changelog now leads with `MemorySegment` -> `DataSegment` API rename notes rather than a new pass addition. That is still only a narrow freshness check, but it strengthens the current conservative reading that no newer documented optimization-pass addition is visible in the reachable non-GitHub changelog surfaces.
- When newer Chromium-mirror commits or release notes show behavior drift or newly added upstream passes without a local implementation, record that here or on the owning pass page instead of silently updating older `version_129`-backed summaries as if they were current-trunk facts.
