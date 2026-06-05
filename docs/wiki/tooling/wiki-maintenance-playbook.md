---
kind: workflow
status: supported
last_reviewed: 2026-06-04
sources:
  - ../../README.md
  - ../../../AGENTS.md
  - ../raw/wiki/2026-06-04-wiki-maintenance-source-bridge.md
  - ../index.md
  - ../log.md
related:
  - ../raw/README.md
  - ../raw/research/README.md
  - ./fuzz-corpus-policy.md
  - ./validation-gates.md
---

# Wiki Maintenance Playbook

## Purpose

Use this playbook when doing broad Starshine wiki maintenance: source ingest, page refreshes, stale-reference cleanup, citation repair, schema alignment, and whole-wiki health checks.

This page is deliberately an **operational checklist**, not a second schema. The normative schema remains [`../../README.md`](../../README.md), and the compact repo rules remain [`../../../AGENTS.md`](../../../AGENTS.md). The current methodology bridge is [`../raw/wiki/2026-06-04-wiki-maintenance-source-bridge.md`](../raw/wiki/2026-06-04-wiki-maintenance-source-bridge.md), which ties the local workflow back to the LLM Wiki / LLM Wiki v2 pattern and current Starshine policy.

## Mental Model

The wiki has four cooperating layers:

| Layer | What belongs there | Maintenance rule |
| --- | --- | --- |
| Raw sources | Durable primary-source manifests, source snapshots, source-reading notes, or external-source bridges under [`../raw/`](../raw/) | Keep them immutable after capture except redaction or format normalization. |
| Research archive | Numbered one-off investigations under [`../raw/research/`](../raw/research/) | Preserve history; file durable conclusions into living pages instead of forcing readers through long investigations. |
| Living pages | Maintained explanations under [`../`](../) | Update these in place when a concept evolves; avoid near-duplicate topic pages. |
| Catalog and audit trail | [`../index.md`](../index.md) and [`../log.md`](../log.md) | Keep the index navigable and the log detailed enough to explain what changed and why. |

A strong wiki update usually touches at least one living page and the log. It touches raw sources when evidence changed or a new durable source was used. It touches the index when a page is created, renamed, substantially reframed, or new raw-source routing needs to be discoverable. For research-note filenames, use the next unused zero-padded serial described in [`../raw/research/README.md`](../raw/research/README.md); historical duplicate prefixes are provenance, not reusable slots.

## Target Selection

Pick the highest-value maintenance target by asking:

1. **Will this prevent a future bug or wrong port?** Prefer validation, binary encoding, IR invariants, pass contracts, oracle differences, and release gates over cosmetic prose.
2. **Is there stale or contradictory evidence?** Reconcile conflicts explicitly; do not smooth them away.
3. **Is the reader route broken?** Fix missing backlinks, index omissions, duplicate pages, and broad pages that fail to route readers to the focused contract.
4. **Is a source claim too weak?** Replace chat-memory or transient-run claims with source files, tests, official upstream docs, committed raw manifests, or numbered research notes.
5. **Is there a local/spec split?** Make upstream behavior, Binaryen-oracle behavior, Starshine implementation, tests, and known gaps visible in one place.

Avoid creating a new page when an existing focused page can be updated. A new page is justified when the topic has its own invariant, workflow, subsystem, or decision that would otherwise bloat an unrelated page.

## Evidence Ladder

Use the strongest available evidence for each claim:

1. **Normative local policy:** [`../../README.md`](../../README.md), [`../../../AGENTS.md`](../../../AGENTS.md), release/process pages.
2. **Exact repository evidence:** source files, tests, generated `.mbti` public API files, checked-in scripts, and command wrappers.
3. **Primary upstream sources:** official WebAssembly spec pages, Binaryen source/tests/releases, MoonBit docs, Node/package docs, or maintainer-authored issue/PR discussions.
4. **Committed raw manifests or numbered research:** source bridges under [`../raw/`](../raw/) and investigations under [`../raw/research/`](../raw/research/).
5. **Transient run artifacts:** `.tmp` / `.artifacts` paths, local timing directories, and one-off command output. Mention them as replay identifiers only after promoting the durable summary into a committed raw note when they support a lasting claim.

When evidence is uncertain, say so. Useful labels include `current-main recheck`, `release-baseline`, `local/spec gap`, `Binaryen/tool failure`, `Starshine-local policy`, `deferred`, `superseded`, and `historical provenance`.

## Update Flow

1. **Inspect first.** Read [`../../README.md`](../../README.md), the relevant existing wiki pages, [`../index.md`](../index.md), [`../log.md`](../log.md), and overlapping raw/research notes before editing.
2. **Recheck primary sources when the claim can drift.** For WebAssembly, Binaryen, MoonBit, package, release, or tool behavior, use current official or maintainer-owned sources and record the capture date in a raw manifest when durable.
3. **Update the smallest coherent page set.** Keep one page canonical for the concept and link sibling pages to it instead of repeating the full explanation.
4. **Make the beginner path explicit.** Include a short overview, examples or shape tables, common traps, and exact source/test links.
5. **Make the advanced contract explicit.** Name invariants, legality boundaries, validation/signoff commands, pass/oracle semantics, and known local gaps.
6. **Refresh catalog and audit trail.** Update [`../index.md`](../index.md) for durable page additions or substantial reframes, and prepend or append a dated [`../log.md`](../log.md) entry following the existing style.
7. **Commit atomically.** Stage only the wiki/source files for the chosen target. Do not include unrelated local code changes.

## Raw Source Placement

| Source kind | Preferred location | Example use |
| --- | --- | --- |
| Official WebAssembly, proposal, or tool docs | Topic directory such as `raw/wasm/`, `raw/binaryen/`, `raw/moonbit/`, or `raw/wiki/` | Current-source bridge for a living page. |
| Local run or investigation summary | `raw/research/[serial]-[YYYY-MM-DD]-[title].md` using the next unused serial | Compare-pass audit, parity investigation, design spike, or substantial debugging session. |
| Completed old planning doc | `raw/research/` plus live-reference repointing | Preserve provenance after a living page becomes canonical. |
| Large generated artifacts | Usually not committed; promote only the minimal durable summary | Counts, command, classification, hashes, and reduced repro if needed. |

If adding a new raw topic directory, update [`../raw/README.md`](../raw/README.md), the top-level index raw-source routing, and the log.

## Whole-Wiki Health Check

After the main update, scan beyond the touched area for high-confidence fixes:

- empty markdown links or obvious malformed relative paths;
- pages that mention the updated concept but do not link to the canonical page;
- index entries missing for new or substantially reframed living pages;
- log entries missing for durable ingests or health fixes;
- duplicate or near-duplicate pages competing for the same concept;
- stale `docs/00xx` forwarding-stub references in living pages, unless preserved intentionally in historical raw notes;
- new research files that accidentally reuse an existing serial prefix;
- broad claims such as "all", "current", or "latest" that need a date, release tag, or local/spec qualifier;
- transient `.tmp` / `.artifacts` source links in frontmatter where a committed raw note should carry the evidence.

Make only high-confidence repairs during the health pass. If a conflict requires deeper research, record the uncertainty in the relevant living page or backlog rather than guessing.

## Common Mistakes

- **Creating a near-duplicate page.** Prefer a focused update plus cross-links.
- **Replacing history with a clean story.** Keep contradictions and supersession visible.
- **Citing a local artifact as durable proof.** Promote the summary into a raw note first.
- **Updating a page without index/log bookkeeping.** This makes future agents rediscover the same work.
- **Treating Binaryen parity as byte-for-byte identity.** For pass pages, distinguish semantic parity, normalized representation drift, size wins/losses, validation failures, and tool failures.
- **Forgetting local/spec gaps.** Starshine may intentionally lag or lead an official/proposal surface; teach the split instead of implying one side is absent.

## Signoff For Wiki-Only Changes

For prose-only wiki work, a focused diff review is usually enough before commit. Run broader validation when docs change command contracts, generated docs, schemas consumed by tooling, release policy, or public API references. If code or tests change, follow the normal validation ladder in [`validation-gates.md`](validation-gates.md) and the task-specific rules in [`../../../AGENTS.md`](../../../AGENTS.md).
