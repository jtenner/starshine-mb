---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-06-04
sources:
  - https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
  - https://gist.github.com/rohitg00/2067ab416f7bbe447c1977edaaa681e2
  - ../../../../docs/README.md
  - ../../../../AGENTS.md
  - ../../index.md
  - ../../log.md
---

# Wiki Maintenance Source Bridge

- Capture date: 2026-06-04
- Source family: wiki-maintenance methodology plus Starshine repository policy
- Purpose: source bridge for the living [`../../tooling/wiki-maintenance-playbook.md`](../../tooling/wiki-maintenance-playbook.md). Keep detailed Starshine rules in [`../../../../docs/README.md`](../../../../docs/README.md) and concise operational guidance in the playbook.

## Primary sources checked

1. Andrej Karpathy, `LLM Wiki`: <https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f>
2. Rohit Gupta, `LLM Wiki v2`: <https://gist.github.com/rohitg00/2067ab416f7bbe447c1977edaaa681e2>
3. Starshine canonical docs/wiki schema: [`../../../../docs/README.md`](../../../../docs/README.md)
4. Starshine repo-agent rules: [`../../../../AGENTS.md`](../../../../AGENTS.md)
5. Current wiki catalog and audit trail: [`../../index.md`](../../index.md), [`../../log.md`](../../log.md)

## Durable takeaways

- The Karpathy note frames a repository wiki as an LLM-usable memory layer: raw docs are accumulated, searched, and distilled into maintained pages instead of relying on chat history or one-off context windows.
- The Gupta v2 note emphasizes a three-layer loop that maps well to this repo: raw sources, living wiki pages, and a log of ingestion or query-fileback events. It also motivates routine linting for contradictions, stale claims, and broken structure.
- Starshine already adopted those concepts in [`../../../../docs/README.md`](../../../../docs/README.md): raw sources under `docs/wiki/raw/`, numbered investigations under `docs/wiki/raw/research/`, living pages under `docs/wiki/`, [`../../index.md`](../../index.md) as the human catalog, and [`../../log.md`](../../log.md) as the chronological audit trail.
- The repo-specific addition is stronger evidence discipline: claims should cite exact source files, tests, raw manifests, official upstream pages, or numbered research notes; transient `.tmp` / `.artifacts` paths are replay hints, not durable frontmatter sources unless their essential evidence is promoted into committed raw notes.
- For autonomous maintenance, the highest-value loop is not "create a page every run." It is: choose the biggest current ambiguity or stale route, reconcile it against primary/local sources, update the smallest set of living pages, then run a whole-wiki health pass for links, index/log drift, citation quality, and duplicate concepts.

## Starshine reconciliation

- [`../../../../docs/README.md`](../../../../docs/README.md) remains the normative schema. The living playbook should not contradict it or become a second schema.
- [`../../../../AGENTS.md`](../../../../AGENTS.md) remains the compact always-read workflow contract. The playbook should help agents apply those rules without copying every rule.
- [`../../index.md`](../../index.md) should list durable living pages and high-level raw-source routing, not every historical research note.
- [`../../log.md`](../../log.md) should record durable additions, significant reframes, ingests, and health checks with enough detail to audit why a page changed.

## Follow-up questions

- If wiki-lint tooling lands later, this playbook should route manual checks to the tool command instead of expanding into a long checklist.
- If `docs/wiki/raw/` gains many methodology or maintenance-source manifests, split this `raw/wiki/` directory with its own README and add it to the raw-source catalog.
