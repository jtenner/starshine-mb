---
kind: concept
status: supported
last_reviewed: 2026-06-02
sources:
  - ../raw/binaryen/2026-06-02-binaryen-v125-current-trunk-release-horizon.md
  - ../raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md
  - https://github.com/WebAssembly/binaryen/releases/tag/version_125
  - https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md
  - https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+refs
  - https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/heads/main/CHANGELOG.md
related:
  - no-dwarf-default-optimize-path.md
  - passes/late-pipeline-dispatch.md
  - passes/index.md
  - passes/tracker.md
---

# Binaryen Release Horizon And Source Oracles

## Overview

This page is the short policy reference for how the wiki should read Binaryen's public release horizon and current-trunk evidence.

Use it when you need to answer a basic question like:

- What is the newest public Binaryen tag we should treat as the stable baseline?
- Which source should we trust when the public tag and current trunk disagree?
- When should a pass dossier stay anchored to an older tag on purpose?

The current answer is simple:

- the newest public Binaryen release baseline is `version_125`, and a 2026-06-02 revalidation against the direct release page, the `main` changelog, and the Chromium refs listing still points here;
- the live `main` changelog is the drift watch for anything beyond that tag;
- detailed pass pages may still stay anchored to `version_129` or a specific current-main recheck when that is the last source-backed contract that page has actually reviewed.

That `v125` baseline is substantive, not just a renumbering. Keep this page as the release-horizon anchor, but still send pass-specific questions to the owning dossier.

## Supersession timeline

- 2026-06-01: an earlier bridge capture briefly treated the public release horizon as `version_130`.
- 2026-06-02: revalidation against the direct official GitHub release page, the `main` changelog, and the Chromium refs listing showed `version_125` is still the newest public tag.
- The 2026-06-02 correction note 0698 supersedes the older bridge; cite 0698 when you need the current baseline, and keep the bridge only as provenance.

## Source hierarchy

| Layer | Preferred source | What it is good for |
| --- | --- | --- |
| Public release baseline | Official GitHub release page for `version_125` | The newest tagged public release horizon. |
| Historical bridge | `docs/wiki/raw/binaryen/2026-06-01-binaryen-v130-current-trunk-release-horizon.md` | The earlier bridge kept for provenance; superseded by the correction note below. |
| Correction note | `docs/wiki/raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md` | The distilled correction that supersedes the earlier `version_130` bridge. |
| Live trunk drift watch | Official GitHub `main` changelog | Whether trunk has moved past the newest tag in a way that matters to the docs. |
| Corroboration | Chromium refs listing and Chromium-hosted `main` changelog | Secondary confirmation that the public tag and trunk story match. |
| Discovery only | Search snippets, search-result summaries, and mirrored excerpts | Good for finding the official URL; not authoritative when they disagree with direct official pages. |
| Durable local evidence | `docs/wiki/raw/binaryen/2026-06-02-binaryen-v125-current-trunk-release-horizon.md` | The repo-captured, immutable summary of the latest release-horizon read. |
| Pass-specific contract pages | Individual `docs/wiki/binaryen/passes/*` dossiers | The exact algorithm, test map, and Starshine status for one pass. |

Do not flatten those layers together. A page can be correct about the public release horizon without being the right place to teach the full pass algorithm, and a pass page can stay intentionally anchored to `version_129` while still acknowledging that the public release horizon has advanced.

## How to read Binaryen pages

1. **If the question is "what is the latest public Binaryen release?"** use `version_125` and this page.
2. **If the question is "did trunk drift after the latest tag?"** use the official `main` changelog first, then the Chromium mirror as corroboration.
3. **If the question is "what does this pass actually do?"** use the pass-specific dossier and its raw research notes, not the release-horizon page.
4. **If the question is "what should I update in the wiki when a new release lands?"** update this page, the top-level catalog, the pass catalog/tracker pages, and any dossier that explicitly names the newest public tag.

## Current state

The 2026-06-02 correction note 0698 supersedes the earlier `version_130` bridge, and the direct official release page, `main` changelog, and Chromium refs listing still agree that `version_125` is the newest public tag. When a search snippet or mirrored summary disagrees with the direct official release page or changelog, trust the direct official URLs.

The key wiki-maintenance consequence is that `version_125` is still the public release baseline, but it does **not** force every detailed pass dossier to retag itself. Many pass pages still stay on the reviewed `version_129` source oracle until they get a fresh current-main reread.

## Where this page points next

- [`no-dwarf-default-optimize-path.md`](no-dwarf-default-optimize-path.md) — the no-DWARF `-O` / `-Os` path audit that uses the release horizon as a guardrail.
- [`passes/late-pipeline-dispatch.md`](passes/late-pipeline-dispatch.md) — the compact `-O4z` / `shrink` tail-roster page that also uses the same release-horizon evidence.
- [`passes/index.md`](passes/index.md) — the living Binaryen pass catalog.
- [`passes/tracker.md`](passes/tracker.md) — the living pass-coverage tracker.

## Sources

- Correction note: [`../raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md`](../raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md)
- Superseded 2026-06-01 bridge: [`../raw/binaryen/2026-06-01-binaryen-v130-current-trunk-release-horizon.md`](../raw/binaryen/2026-06-01-binaryen-v130-current-trunk-release-horizon.md)
- Immutable local release-horizon bridge: [`../raw/binaryen/2026-06-02-binaryen-v125-current-trunk-release-horizon.md`](../raw/binaryen/2026-06-02-binaryen-v125-current-trunk-release-horizon.md)
- Official GitHub `version_125` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_125>
- Official GitHub `main` changelog: <https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md>
- Chromium refs listing: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+refs>
- Chromium-hosted `main` changelog: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/heads/main/CHANGELOG.md>
