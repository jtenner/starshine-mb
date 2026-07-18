---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ../raw/research/1573-2026-07-18-binaryen-version-131-release-impact-audit.md
  - https://github.com/WebAssembly/binaryen/releases/tag/version_131
  - https://github.com/WebAssembly/binaryen/compare/version_130...version_131
  - https://github.com/WebAssembly/binaryen/commit/1251efbc1ea471c1311d2726b2bbe061ff2a291c
  - ../raw/binaryen/2026-07-10-memory-packing-imported-overlap-current-main-refresh.md
  - ../raw/research/0704-2026-06-04-binaryen-v130-release-horizon-recheck.md
  - ../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md
  - ../raw/research/0706-2026-06-04-v130-mark-js-called-remove-exports-tracker-expansion.md
  - ../raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md
  - https://github.com/WebAssembly/binaryen/releases/tag/version_130
  - https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md
  - https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+refs
  - https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/heads/main/CHANGELOG.md
related:
  - no-dwarf-default-optimize-path.md
  - passes/late-pipeline-dispatch.md
  - passes/index.md
  - passes/tracker.md
  - ../wasm-wide-arithmetic-boundary.md
---

# Binaryen Release Horizon And Source Oracles

## Overview

This page is the short policy reference for how the wiki should read Binaryen's public release horizon and current-trunk evidence.

Use it when you need to answer a basic question like:

- What is the newest public Binaryen tag we should treat as the stable baseline?
- Which source should we trust when the public tag and current trunk disagree?
- When should a pass dossier stay anchored to an older tag on purpose?

The current answer is:

- the newest public Binaryen release baseline is `version_131`, published on **2026-07-15** and resolving to commit `1f903c14babf829745b421b92ff0f286e93e4209`;
- the v130-to-v131 range contains `92` commits, adds public `constraint-analysis` plus hidden test pass `remove-start`, and leaves the default optimization scheduler unchanged;
- six accepted Starshine implementation areas are reopened for released behavior changes: `optimize-instructions`, `memory-packing`, `remove-unused-module-elements`, `directize`, `heap2local`, and the shared `inlining` / `inlining-optimizing` engine;
- `pick-load-signs` has already completed an explicit v131 audit and remains closed;
- the live `main` changelog and pass-specific current-main reads are now the drift watch for anything beyond `version_131`;
- detailed pass pages may still stay anchored to `version_129`, `version_130`, or a specific current-main recheck when that is the last source-backed contract that page has actually reviewed.

The v131 baseline is substantive. Its changelog names `@binaryen.inline`, acqrel `atomic.fence`, the JS parser API merge, and the new [`constraint-analysis`](passes/constraint-analysis/index.md) pass; the full tag diff also contains released pass behavior changes beyond the short changelog. Newly refreshed upstream-only routes include open-world [`remove-unused-types`](passes/remove-unused-types/index.md), open-world [`unsubtyping`](passes/unsubtyping/index.md), recursion-safe [`print-boundary`](passes/print-boundary/index.md), non-shared-atomic [`safe-heap`](passes/safe-heap/index.md), and public-type-safe [`merge-j2cl-itables`](passes/merge-j2cl-itables/index.md). Keep this page as the release-horizon anchor, but send exact algorithm questions to the owning dossier and the [v131 release-impact audit](../raw/research/1573-2026-07-18-binaryen-version-131-release-impact-audit.md).

## Supersession timeline

- 2026-06-01: an earlier bridge capture treated the public release horizon as `version_130`, but later checks considered its evidence contradictory.
- 2026-06-02: correction note 0698 temporarily moved the wiki baseline back to `version_125`; keep it as provenance, not as the current baseline.
- 2026-06-04: the official GitHub `version_130` release page, changelog, and Chromium mirror re-established v130 as the stable baseline, superseding the temporary `version_125` correction.
- 2026-07-15: Binaryen published `version_131` at tag commit `1f903c14babf829745b421b92ff0f286e93e4209`.
- 2026-07-18: research note 1573 audited the complete v130-to-v131 range, confirmed the default pass order is unchanged, added the new pass to the tracker, and reopened the six affected Starshine implementation areas. This supersedes v130 for current release-horizon decisions.

## Source hierarchy

| Layer | Preferred source | What it is good for |
| --- | --- | --- |
| Public release baseline | Official GitHub release page for `version_131` | The newest tagged public release horizon. |
| Oracle/security boundary | Official Binaryen commit `1251efb` | The `IRBuilder::makeBrOn` reachable-assertion fix; classify matching older-Binaryen crashes as tool/oracle failures unless a fixed-build replay proves otherwise. |
| Durable local evidence | research note 1573 plus the official release/compare/changelog URLs below | The retained repo-authored summary, pass-impact classification, and reopening decisions for the latest release. |
| Live trunk drift watch | Official GitHub `main` changelog plus a pass-specific current-main source/PR read | Whether trunk has moved past `version_131` in a way that matters to the docs. |
| Corroboration | Chromium refs listing and Chromium-hosted `main` changelog | Secondary confirmation that the public tag and trunk story match. |
| Superseded correction | `docs/wiki/raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md` | Provenance for the temporary `version_125` correction; not the current baseline after 0704. |
| Historical bridge | 2026-06-01 capture (ingested and removed) | Earlier `version_130` bridge; its useful facts are retained by the stronger 2026-06-04 recheck. |
| Discovery only | Search snippets, search-result summaries, and mirrored excerpts | Good for finding the official URL; not authoritative when they disagree with direct official pages. |
| Pass-specific contract pages | Individual `docs/wiki/binaryen/passes/*` dossiers | The exact algorithm, test map, and Starshine status for one pass. |

Do not flatten those layers together. A page can be correct about the public release horizon without being the right place to teach the full pass algorithm, and a pass page can stay intentionally anchored to `version_129` while still acknowledging that the public release horizon has advanced.

## How to read Binaryen pages

1. **If the question is "what is the latest public Binaryen release?"** use `version_131` and this page.
2. **If the question is "did trunk drift after the latest tag?"** use the official `main` changelog first, then the Chromium mirror as corroboration.
3. **If the question is "what does this pass actually do?"** use the pass-specific dossier and its raw research notes, not the release-horizon page.
4. **If the question is "what should I update in the wiki when a new release lands?"** update this page, the top-level catalog, the pass catalog/tracker pages, and any dossier that explicitly names the newest public tag.
5. **If a release note names a pass not yet tracked locally,** record it first as an upstream release-horizon fact, then create a dedicated tracker/dossier only after a pass-specific source read. `mark-js-called` / `remove-exports` remain the example: the 2026-06-04 reads proved owner/test existence and behavior, while the 2026-07-11 recheck renewed their current-main contract without converting either into a local pass.

## Current state

Direct official sources establish `version_131` as the newest public tag. The v131 audit found no default scheduler change, so the existing no-DWARF 56-slot O4z roster remains current, but several direct-pass contracts changed and old v130 closeout evidence is not sufficient for those owners.

The key wiki-maintenance consequence is that `version_131` is the public release baseline, but it does **not** force every detailed pass dossier to pretend it has been re-audited. Keep older source anchors explicit until a dedicated v131 read exists. Current-main findings already captured before the release—such as `memory-packing` imported overlap, open-world `unsubtyping`, recursive-safe `print-boundary`, and toolchain inline hints—should now be relabeled as released v131 behavior rather than post-v130 drift.

The local `wasm-opt` on `PATH` reported `version_116` on 2026-07-18. V131 parity evidence must use an explicit verified official v131 binary through `--wasm-opt-bin`; bare PATH resolution is not a valid oracle for this baseline.

## BrOn Assertion And Oracle-Failure Boundary

The upstream Binaryen `IRBuilder::makeBrOn` fix records an important current-tooling caveat. Binaryen commit `1251efb` fixed a reachable assertion in `IRBuilder::makeBrOn(...)` where malformed `br_on*` / descriptor-branch operands could reach later reference-only finalization logic. The upstream issue and PR were on `main` in April 2026; `version_130` was tagged after that fix.

For Starshine, this is an oracle-classification rule, not a new Starshine behavior claim:

- if an older installed `wasm-opt` asserts while parsing or validating a BrOn-family malformed input, report it as Binaryen `tool-failure` / oracle failure until replayed on a fixed build;
- do not treat that crash as evidence that Starshine accepted an invalid module, rejected a valid one, or miscompiled a pass output;
- do not use NVD's version-range metadata alone to change the public release baseline. The actionable wiki evidence is the upstream issue/PR/commit plus release/tag ancestry.

Starshine's own reference-branch semantics still live in [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md), with descriptor-local non-branch forms routed through [`../custom-descriptors/descriptor-instruction-surface.md`](../custom-descriptors/descriptor-instruction-surface.md).

## Where this page points next

- [`no-dwarf-default-optimize-path.md`](no-dwarf-default-optimize-path.md) — the no-DWARF `-O` / `-Os` path audit that uses the release horizon as a guardrail.
- [`passes/late-pipeline-dispatch.md`](passes/late-pipeline-dispatch.md) — the compact `-O4z` / `shrink` tail-roster page that also uses the same release-horizon evidence.
- [`passes/index.md`](passes/index.md) — the living Binaryen pass catalog.
- [`passes/tracker.md`](passes/tracker.md) — the living pass-coverage tracker.

## Sources

- Retained release-horizon recheck: [`../raw/research/0704-2026-06-04-binaryen-v130-release-horizon-recheck.md`](../raw/research/0704-2026-06-04-binaryen-v130-release-horizon-recheck.md)
- Pass-specific `mark-js-called` / `remove-exports` current-main recheck: [`../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md`](../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md)
- Retained `mark-js-called` / `remove-exports` tracker expansion: [`../raw/research/0706-2026-06-04-v130-mark-js-called-remove-exports-tracker-expansion.md`](../raw/research/0706-2026-06-04-v130-mark-js-called-remove-exports-tracker-expansion.md)
- Superseded 2026-06-02 correction: [`../raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md`](../raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md)
- Historical 2026-06-01 bridge: ingested and removed; its release-horizon facts are retained in the 0704 recheck above.
- Official BrOn assertion-fix commit: <https://github.com/WebAssembly/binaryen/commit/1251efbc1ea471c1311d2726b2bbe061ff2a291c>
- Current-main `memory-packing` drift bridge: [`../raw/binaryen/2026-07-10-memory-packing-imported-overlap-current-main-refresh.md`](../raw/binaryen/2026-07-10-memory-packing-imported-overlap-current-main-refresh.md)
- V131 release-impact audit: [`../raw/research/1573-2026-07-18-binaryen-version-131-release-impact-audit.md`](../raw/research/1573-2026-07-18-binaryen-version-131-release-impact-audit.md)
- Official GitHub `version_131` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_131>
- Official GitHub v130-to-v131 compare: <https://github.com/WebAssembly/binaryen/compare/version_130...version_131>
- Historical official GitHub `version_130` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_130>
- Official GitHub `main` changelog: <https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md>
- Chromium refs listing: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+refs>
- Chromium-hosted `main` changelog: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/heads/main/CHANGELOG.md>
