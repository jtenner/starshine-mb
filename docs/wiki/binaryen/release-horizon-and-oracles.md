---
kind: concept
status: supported
last_reviewed: 2026-09-16
sources:
  - https://github.com/WebAssembly/binaryen/releases/tag/version_132
  - https://github.com/WebAssembly/binaryen/compare/version_131...version_132
  - version-132-upgrade.md
  - https://github.com/WebAssembly/binaryen/releases/tag/version_131
  - https://github.com/WebAssembly/binaryen/compare/version_130...version_131
  - https://github.com/WebAssembly/binaryen/commit/1251efbc1ea471c1311d2726b2bbe061ff2a291c
  - passes/memory-packing/index.md
  - passes/remove-exports/index.md
  - ./passes/remove-exports/index.md
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

The current comparison baseline is **`version_132`**, published **2026-08-12**
at `79dfe6b412a3c22bfdb190ed6a4d79adf734db5d`. New correctness and performance
comparisons use a verified v132 binary. The [v132 upgrade](version-132-upgrade.md)
records the reproduced 59-commit / 220-file delta, implementation boundaries and
the released transform-shape catalog. Use that catalog when a v132 question is
about the input pattern or output form rather than the public release date.
Version 131 remains the historical source of existing measurements and signoffs;
none of those results is silently relabeled v132. Post-tag fixes remain a separate
intake, including DAE2 #8994 and constraint correctness guardrails. The v132 tag
does not add constraint analysis to default optimization presets.

The following v131 context is retained as historical evidence:

The v131 baseline is substantive. Its changelog names `@binaryen.inline`, acqrel `atomic.fence`, the JS parser API merge, and the new [`constraint-analysis`](passes/constraint-analysis/index.md) pass; the full tag diff also contains released pass behavior changes beyond the short changelog. Newly refreshed upstream-only routes include open-world [`remove-unused-types`](passes/remove-unused-types/index.md), open-world [`unsubtyping`](passes/unsubtyping/index.md), recursion-safe [`print-boundary`](passes/print-boundary/index.md), non-shared-atomic [`safe-heap`](passes/safe-heap/index.md), and public-type-safe [`merge-j2cl-itables`](passes/merge-j2cl-itables/index.md). Keep this page as the release-horizon anchor, but send exact algorithm questions to the owning dossier and the v131 release-impact audit.

## Supersession timeline

- 2026-06-01: an earlier bridge capture treated the public release horizon as `version_130`, but later checks considered its evidence contradictory.
- 2026-06-02: correction note 0698 temporarily moved the wiki baseline back to `version_125`; keep it as provenance, not as the current baseline.
- 2026-06-04: the official GitHub `version_130` release page, changelog, and Chromium mirror re-established v130 as the stable baseline, superseding the temporary `version_125` correction.
- 2026-07-15: Binaryen published `version_131` at tag commit `1f903c14babf829745b421b92ff0f286e93e4209`.
- 2026-07-18: research note 1573 audited the complete v130-to-v131 range, confirmed the default pass order is unchanged, added the new pass to the tracker, and reopened the six affected Starshine implementation areas. This superseded v130 for release-horizon decisions at that time; v132 is the current baseline.

- 2026-09-10: the verified v132 tag and exact v131-to-v132 inventory supersede v131 as the comparison baseline; historical pass signoffs retain their original oracle.

## Source hierarchy

| Layer | Preferred source | What it is good for |
| --- | --- | --- |
| Public release baseline | Official GitHub release page for `version_132` | The newest tagged public release horizon. |
| Oracle/security boundary | Official Binaryen commit `1251efb` | The `IRBuilder::makeBrOn` reachable-assertion fix; classify matching older-Binaryen crashes as tool/oracle failures unless a fixed-build replay proves otherwise. |
| Durable local evidence | research note 1573 plus the official release/compare/changelog URLs below | The retained repo-authored summary, pass-impact classification, and reopening decisions for the historical v131 release; use the v132 upgrade for the current release. |
| Live trunk drift watch | Official GitHub `main` changelog plus a pass-specific current-main source/PR read | Whether trunk has moved past `version_132` in a way that matters to the docs. |
| Corroboration | Chromium refs listing and Chromium-hosted `main` changelog | Secondary confirmation that the public tag and trunk story match. |
| Superseded correction | `docs/wiki/binaryen/release-horizon-and-oracles.md` | Provenance for the temporary `version_125` correction; not the current baseline after 0704. |
| Historical bridge | 2026-06-01 capture (ingested and removed) | Earlier `version_130` bridge; its useful facts are retained by the stronger 2026-06-04 recheck. |
| Discovery only | Search snippets, search-result summaries, and mirrored excerpts | Good for finding the official URL; not authoritative when they disagree with direct official pages. |
| Pass-specific contract pages | Individual `docs/wiki/binaryen/passes/*` dossiers | The exact algorithm, test map, and Starshine status for one pass. |

Do not flatten those layers together. A page can be correct about the public release horizon without being the right place to teach the full pass algorithm, and a pass page can stay intentionally anchored to `version_129` while still acknowledging that the public release horizon has advanced.

## How to read Binaryen pages

1. **If the question is "what is the latest public Binaryen release?"** use `version_132` and this page.
2. **If the question is "did trunk drift after the latest tag?"** use the official `main` changelog first, then the Chromium mirror as corroboration.
3. **If the question is "what does this pass actually do?"** use the pass-specific dossier and its raw research notes, not the release-horizon page.
4. **If the question is "what should I update in the wiki when a new release lands?"** update this page, the top-level catalog, the pass catalog/tracker pages, and any dossier that explicitly names the newest public tag.
5. **If a release note names a pass not yet tracked locally,** record it first as an upstream release-horizon fact, then create a dedicated tracker/dossier only after a pass-specific source read. `mark-js-called` / `remove-exports` remain the example: the 2026-06-04 reads proved owner/test existence and behavior, while the 2026-07-11 recheck renewed their current-main contract without converting either into a local pass.

## Current state

Version 132 is the comparison and research baseline. The current release inventory
and source-derived work are in [version-132-upgrade.md](version-132-upgrade.md).
Keep detailed pass dossiers anchored to their actually reviewed source tags until
they are re-audited. A newer comparison target is not proof of new optimizer or
proposal support, nor does it invalidate historical measured v131 results.

Use `.tmp/binaryen-version_132/bin/wasm-opt` or another explicitly verified v132
binary. CI and performance sweeps require v132; compare-pass defaults to requiring
132 and supports an explicit historical version for replay. Record the resolved
path, version and executable hash. Bare PATH resolution is not evidence of the
correct oracle version.

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

- Retained release-horizon recheck: research note 0704
- Pass-specific `mark-js-called` / `remove-exports` current-main recheck: [`passes/remove-exports/index.md`](passes/remove-exports/index.md)
- Retained `mark-js-called` / `remove-exports` tracker expansion: [research note 0706](./passes/remove-exports/index.md)
- Superseded 2026-06-02 correction: research note 0698
- Historical 2026-06-01 bridge: ingested and removed; its release-horizon facts are retained in the 0704 recheck above.
- Official BrOn assertion-fix commit: <https://github.com/WebAssembly/binaryen/commit/1251efbc1ea471c1311d2726b2bbe061ff2a291c>
- Current-main `memory-packing` drift bridge: [`passes/memory-packing/index.md`](passes/memory-packing/index.md)
- V131 release-impact audit: research note 1573
- Official GitHub `version_131` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_131>
- Official GitHub v130-to-v131 compare: <https://github.com/WebAssembly/binaryen/compare/version_130...version_131>
- Historical official GitHub `version_130` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_130>
- Official GitHub `main` changelog: <https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md>
- Chromium refs listing: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+refs>
- Chromium-hosted `main` changelog: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/heads/main/CHANGELOG.md>
