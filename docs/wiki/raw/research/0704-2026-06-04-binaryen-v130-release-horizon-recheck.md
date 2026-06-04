# Binaryen `version_130` release-horizon recheck

## Question

The living wiki currently says the latest public Binaryen release baseline is `version_125`, after a 2026-06-02 correction superseded an earlier `version_130` bridge. Is that still true on 2026-06-04?

## Sources

- Raw source capture: [`../binaryen/2026-06-04-binaryen-v130-release-horizon-recheck.md`](../binaryen/2026-06-04-binaryen-v130-release-horizon-recheck.md)
- Prior correction now superseded for current baseline decisions: [`0698-2026-06-02-binaryen-v125-release-horizon-correction.md`](0698-2026-06-02-binaryen-v125-release-horizon-correction.md)
- Earlier bridge with the same target but weaker/conflicted provenance: [`../binaryen/2026-06-01-binaryen-v130-current-trunk-release-horizon.md`](../binaryen/2026-06-01-binaryen-v130-current-trunk-release-horizon.md)

## Findings

The current release baseline is `version_130`.

The official GitHub `version_130` release page is reachable and marked `Latest`. The official GitHub `main` changelog puts `v130` immediately below `Current Trunk`. The Chromium refs listing includes `version_130` above the older tags, and the Chromium-hosted `main` changelog has the same `Current Trunk` / `v130` / `v129` ordering.

This supersedes the 2026-06-02 `version_125` correction for current release-horizon decisions. Keep 0698 as provenance for why the wiki briefly moved back to `version_125`; do not cite it as the current baseline after this recheck.

The earlier 2026-06-01 `version_130` bridge had the correct endpoint but should still be treated as historical. This 2026-06-04 note is the stronger current source because it reconciles the release page, official changelog, and Chromium mirror in one pass after the intervening contradiction.

## Wiki maintenance actions

- Update [`../../binaryen/release-horizon-and-oracles.md`](../../binaryen/release-horizon-and-oracles.md) to name `version_130` as the current public release baseline.
- Update [`../../binaryen/no-dwarf-default-optimize-path.md`](../../binaryen/no-dwarf-default-optimize-path.md), [`../../binaryen/passes/late-pipeline-dispatch.md`](../../binaryen/passes/late-pipeline-dispatch.md), [`../../binaryen/passes/index.md`](../../binaryen/passes/index.md), [`../../binaryen/passes/tracker.md`](../../binaryen/passes/tracker.md), and the top-level [`../../index.md`](../../index.md) so readers stop seeing the 2026-06-02 `version_125` correction as current.
- Do not bulk-retag pass dossiers from `version_129`; most detailed pass pages are source-backed by dedicated tag/current-main rereads and should move only after pass-specific source work.
- Record `MarkJSCalled` and `RemoveExports` as v130 upstream pass-surface facts for later tracker expansion rather than creating broad new dossiers in this release-horizon cleanup.

## Follow-up questions

- Should `MarkJSCalled` and `RemoveExports` get upstream-only or boundary-only tracker rows? That requires a pass-specific source read of `pass.cpp`, owner files, help output, and tests rather than this global release-horizon check.
- Should stale raw notes that mention `version_125` as the current horizon be annotated as superseded? They are immutable source captures, so the safer policy is to leave them as-is and route living pages through this note.
