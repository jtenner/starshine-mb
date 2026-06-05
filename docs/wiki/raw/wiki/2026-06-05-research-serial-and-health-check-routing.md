---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-06-05
sources:
  - https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
  - https://gist.github.com/rohitg00/2067ab416f7bbe447c1977edaaa681e2
  - ../../../../docs/README.md
  - ../../../../AGENTS.md
  - ../README.md
  - ../../log.md
---

# Research Serial And Health-Check Routing

- Capture date: 2026-06-05
- Source family: wiki-maintenance methodology plus Starshine repository policy
- Purpose: source bridge for the living [`../../tooling/wiki-maintenance-playbook.md`](../../tooling/wiki-maintenance-playbook.md) and [`../research/README.md`](../research/README.md) after a health check found that the log already claimed the serial policy was clarified, while the archived-research README still lacked the explicit rule.

## Primary sources checked

1. Andrej Karpathy, `LLM Wiki`: <https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f>
2. Rohit Gupta, `LLM Wiki v2`: <https://gist.github.com/rohitg00/2067ab416f7bbe447c1977edaaa681e2>
3. Starshine canonical docs/wiki schema: [`../../../../docs/README.md`](../../../../docs/README.md)
4. Starshine repo-agent rules: [`../../../../AGENTS.md`](../../../../AGENTS.md)
5. Current raw-source rules: [`../README.md`](../README.md) and [`../research/README.md`](../research/README.md)
6. Current wiki log: [`../../log.md`](../../log.md)

## Durable takeaways

- The LLM Wiki pattern still supports Starshine's raw-source / living-page / schema split, plus the ingest/query/lint loop and index/log bookkeeping. The current public gist remains an idea file rather than a Starshine-specific policy source.
- The LLM Wiki v2 extension still emphasizes lifecycle, supersession, self-healing lint, auditability, and treating completed investigations as sources. Those ideas support Starshine's archive-plus-living-page approach, but the exact serial-number rule is local policy from `AGENTS.md` and `docs/README.md`.
- Starshine's current canonical rule is: new research notes use the next unused zero-padded serial after scanning `docs/`, `docs/wiki/`, and `docs/wiki/raw/research/`. Historical duplicate serial prefixes stay stable as provenance but must not be reused.
- The 2026-06-05 log already recorded a serial-policy clarification, but the current archived-research README did not yet carry the explicit next-unused-serial rule. The living playbook also needed a concrete health-check instruction to scan for accidental new serial reuse before adding research notes.
- The repair should update living operational guidance and the research README. It should not rewrite old archived note filenames, because those names are provenance and some historical duplicates are explicitly tolerated.

## Starshine reconciliation

- [`../../../../docs/README.md`](../../../../docs/README.md) and [`../../../../AGENTS.md`](../../../../AGENTS.md) remain the normative serial-policy sources.
- [`../research/README.md`](../research/README.md) should carry the practical placement rule for agents working in the archive.
- [`../../tooling/wiki-maintenance-playbook.md`](../../tooling/wiki-maintenance-playbook.md) should remind autonomous wiki runs to scan for serial reuse during raw-source placement and whole-wiki health checks.
- [`../../log.md`](../../log.md) should record this as schema/maintenance health work, not as a change to WebAssembly semantics or pass behavior.

## Follow-up questions

- If a future wiki-lint tool lands, teach it to compute the next available research serial and flag duplicate new filenames while leaving historical duplicates alone.
- If old numbered notes are moved from `docs/` later, keep their original filenames stable even when their serial prefix collides with another historical file.
