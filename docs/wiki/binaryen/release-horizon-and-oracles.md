---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - ../raw/binaryen/2026-06-05-binaryen-bron-assertion-oracle-boundary.md
  - ../raw/binaryen/2026-06-04-binaryen-v130-release-horizon-recheck.md
  - ../raw/research/0704-2026-06-04-binaryen-v130-release-horizon-recheck.md
  - ../raw/binaryen/2026-06-04-mark-js-called-remove-exports-behavior-refresh.md
  - ../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md
  - ../raw/research/0706-2026-06-04-v130-mark-js-called-remove-exports-tracker-expansion.md
  - ../raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md
  - ../raw/binaryen/2026-06-01-binaryen-v130-current-trunk-release-horizon.md
  - https://github.com/WebAssembly/binaryen/releases/tag/version_130
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

The current answer is:

- the newest public Binaryen release baseline is `version_130`, confirmed on 2026-06-04 by the official GitHub release page, the official `main` changelog, the Chromium refs listing, and the Chromium-hosted `main` changelog;
- the 2026-06-05 BrOn assertion/security recheck confirms `version_130` is after Binaryen commit `1251efb`, the April 2026 fix for a reachable assertion while parsing malformed `br_on*` / descriptor-branch operands;
- the live `main` changelog is the drift watch for anything beyond `version_130`;
- detailed pass pages may still stay anchored to `version_129` or a specific current-main recheck when that is the last source-backed contract that page has actually reviewed.

That `v130` baseline is substantive, not just a renumbering. The changelog includes user-visible surface changes such as [`mark-js-called`](passes/mark-js-called/index.md), [`remove-exports`](passes/remove-exports/index.md), Wide Arithmetic support, relaxed-SIMD naming changes, and MemorySegment-to-DataSegment API renames. Keep this page as the release-horizon anchor, but still send pass-specific algorithm questions to the owning dossier.

## Supersession timeline

- 2026-06-01: an earlier bridge capture treated the public release horizon as `version_130`, but later checks considered its evidence contradictory.
- 2026-06-02: correction note 0698 temporarily moved the wiki baseline back to `version_125`; keep it as provenance, not as the current baseline.
- 2026-06-04: the official GitHub `version_130` release page is reachable and marked latest, the official `main` changelog puts `v130` immediately below `Current Trunk`, and Chromium corroborates the tag/changelog ordering. This 0704 recheck supersedes both the 2026-06-01 bridge and the 2026-06-02 `version_125` correction for current release-horizon decisions.

## Source hierarchy

| Layer | Preferred source | What it is good for |
| --- | --- | --- |
| Public release baseline | Official GitHub release page for `version_130` | The newest tagged public release horizon. |
| Oracle/security boundary | `docs/wiki/raw/binaryen/2026-06-05-binaryen-bron-assertion-oracle-boundary.md` | Current-source bridge for the `IRBuilder::makeBrOn` reachable-assertion fix; classify matching older-Binaryen crashes as tool/oracle failures unless a fixed-build replay proves otherwise. |
| Durable local evidence | `docs/wiki/raw/binaryen/2026-06-04-binaryen-v130-release-horizon-recheck.md` plus research note 0704 | The repo-captured, immutable summary of the latest release-horizon read. |
| Live trunk drift watch | Official GitHub `main` changelog | Whether trunk has moved past the newest tag in a way that matters to the docs. |
| Corroboration | Chromium refs listing and Chromium-hosted `main` changelog | Secondary confirmation that the public tag and trunk story match. |
| Superseded correction | `docs/wiki/raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md` | Provenance for the temporary `version_125` correction; not the current baseline after 0704. |
| Historical bridge | `docs/wiki/raw/binaryen/2026-06-01-binaryen-v130-current-trunk-release-horizon.md` | Earlier `version_130` bridge; superseded by the stronger 2026-06-04 recheck. |
| Discovery only | Search snippets, search-result summaries, and mirrored excerpts | Good for finding the official URL; not authoritative when they disagree with direct official pages. |
| Pass-specific contract pages | Individual `docs/wiki/binaryen/passes/*` dossiers | The exact algorithm, test map, and Starshine status for one pass. |

Do not flatten those layers together. A page can be correct about the public release horizon without being the right place to teach the full pass algorithm, and a pass page can stay intentionally anchored to `version_129` while still acknowledging that the public release horizon has advanced.

## How to read Binaryen pages

1. **If the question is "what is the latest public Binaryen release?"** use `version_130` and this page.
2. **If the question is "did trunk drift after the latest tag?"** use the official `main` changelog first, then the Chromium mirror as corroboration.
3. **If the question is "what does this pass actually do?"** use the pass-specific dossier and its raw research notes, not the release-horizon page.
4. **If the question is "what should I update in the wiki when a new release lands?"** update this page, the top-level catalog, the pass catalog/tracker pages, and any dossier that explicitly names the newest public tag.
5. **If a release note names a pass not yet tracked locally,** record it first as an upstream release-horizon fact, then create a dedicated tracker/dossier only after a pass-specific source read. The 2026-06-04 `mark-js-called` / `remove-exports` update is the current example of that handoff: the first source read proved owner/test existence, and the later behavior refresh proved the configureAll-driven annotation and wildcard export-filter contracts.

## Current state

The 2026-06-04 recheck supersedes the earlier `version_125` correction. Direct official sources and Chromium corroboration now agree that `version_130` is the newest public tag. When a search snippet or mirrored summary disagrees with the direct official release page or changelog, trust the direct official URLs.

The key wiki-maintenance consequence is that `version_130` is the public release baseline, but it does **not** force every detailed pass dossier to retag itself. Many pass pages still stay on the reviewed `version_129` source oracle until they get a fresh current-main or `version_130` reread.

## BrOn Assertion And Oracle-Failure Boundary

The 2026-06-05 BrOn assertion recheck in [`../raw/binaryen/2026-06-05-binaryen-bron-assertion-oracle-boundary.md`](../raw/binaryen/2026-06-05-binaryen-bron-assertion-oracle-boundary.md) records an important current-tooling caveat. Binaryen commit `1251efb` fixed a reachable assertion in `IRBuilder::makeBrOn(...)` where malformed `br_on*` / descriptor-branch operands could reach later reference-only finalization logic. The upstream issue and PR were on `main` in April 2026; `version_130` was tagged after that fix.

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

- Current release-horizon recheck: [`../raw/research/0704-2026-06-04-binaryen-v130-release-horizon-recheck.md`](../raw/research/0704-2026-06-04-binaryen-v130-release-horizon-recheck.md)
- Immutable source capture for 0704: [`../raw/binaryen/2026-06-04-binaryen-v130-release-horizon-recheck.md`](../raw/binaryen/2026-06-04-binaryen-v130-release-horizon-recheck.md)
- Pass-specific v130 behavior/source reads for `mark-js-called` / `remove-exports`: [`../raw/binaryen/2026-06-04-mark-js-called-remove-exports-behavior-refresh.md`](../raw/binaryen/2026-06-04-mark-js-called-remove-exports-behavior-refresh.md), [`../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md`](../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md), [`../raw/research/0706-2026-06-04-v130-mark-js-called-remove-exports-tracker-expansion.md`](../raw/research/0706-2026-06-04-v130-mark-js-called-remove-exports-tracker-expansion.md)
- Superseded 2026-06-02 correction: [`../raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md`](../raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md)
- Historical 2026-06-01 bridge: [`../raw/binaryen/2026-06-01-binaryen-v130-current-trunk-release-horizon.md`](../raw/binaryen/2026-06-01-binaryen-v130-current-trunk-release-horizon.md)
- BrOn assertion / oracle boundary bridge: [`../raw/binaryen/2026-06-05-binaryen-bron-assertion-oracle-boundary.md`](../raw/binaryen/2026-06-05-binaryen-bron-assertion-oracle-boundary.md)
- Official GitHub `version_130` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_130>
- Official GitHub `main` changelog: <https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md>
- Chromium refs listing: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+refs>
- Chromium-hosted `main` changelog: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/heads/main/CHANGELOG.md>
