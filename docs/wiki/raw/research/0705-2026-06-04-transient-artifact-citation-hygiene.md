---
kind: research-note
status: supported
last_reviewed: 2026-06-04
sources:
  - ../../../README.md
  - ../../../../AGENTS.md
  - ../../tooling/fuzz-corpus-policy.md
  - ../../tooling/pass-fuzz-compare.md
  - ../README.md
  - ./0700-2026-06-03-memory-packing-o4z-audit.md
  - ./0701-2026-06-03-once-reduction-o4z-audit.md
  - ./0702-2026-06-03-pick-load-signs-o4z-audit.md
  - ./0703-2026-06-03-remove-unused-names-o4z-audit.md
related:
  - ../../tooling/fuzz-corpus-policy.md
  - ../../tooling/pass-fuzz-compare.md
  - ../../binaryen/passes/memory-packing/index.md
  - ../../binaryen/passes/memory-packing/parity.md
  - ../../binaryen/passes/once-reduction/index.md
  - ../../binaryen/passes/once-reduction/parity.md
  - ../../binaryen/passes/pick-load-signs/index.md
  - ../../binaryen/passes/remove-unused-names/index.md
---

# Transient Artifact Citation Hygiene - 2026-06-04

## Question

How should living wiki pages cite local pass-fuzz, self-opt, and generated-artifact evidence without depending on machine-local `.tmp/` or `.artifacts/` paths that are not committed raw sources?

## Sources Checked

- [`docs/README.md`](../../../README.md) and [`AGENTS.md`](../../../../AGENTS.md) define the repo docs split: normative docs in `docs/`, living knowledge in `docs/wiki/`, committed raw sources and numbered research under `docs/wiki/raw/`, and local-only files outside committed docs.
- [`docs/wiki/raw/README.md`](../README.md) says raw sources are committed, immutable captures and research notes grouped under `docs/wiki/raw/`.
- [`docs/wiki/tooling/pass-fuzz-compare.md`](../../tooling/pass-fuzz-compare.md) documents that compare-pass writes replay artifacts under a caller-chosen output directory, commonly `.tmp/<run-name>`, and that durable signoff should copy aggregate facts into the affected pass dossier or research note.
- [`docs/wiki/tooling/fuzz-corpus-policy.md`](../../tooling/fuzz-corpus-policy.md) already says large generated corpora should not be committed by default and noisy machine-local bulk output should stay under `.tmp/` unless explicitly promoted.
- Fresh O4z audit research notes for [`memory-packing`](./0700-2026-06-03-memory-packing-o4z-audit.md), [`once-reduction`](./0701-2026-06-03-once-reduction-o4z-audit.md), [`pick-load-signs`](./0702-2026-06-03-pick-load-signs-o4z-audit.md), and [`remove-unused-names`](./0703-2026-06-03-remove-unused-names-o4z-audit.md) already contain the durable aggregate facts needed by the corresponding living pages.

## Durable Conclusions

1. Living wiki pages may mention `.tmp/<run-name>` or `.artifacts/<run-name>` as **replay identifiers** when the path is useful to find a local run directory, but they should not rely on those paths as committed source links.
2. If a run matters after the local machine state disappears, copy the command, aggregate counts, classification, and any small essential excerpts into a numbered `docs/wiki/raw/research/` note or another committed raw-source manifest.
3. Living pages should cite the committed note, source file, test file, or official upstream URL as their durable source. Local run directories can remain in prose only when clearly scoped as transient replay paths.
4. For old generated-artifact O4z evidence, prefer the later absorbed research note when one exists. The raw research note should preserve the audited facts so landing pages and parity pages do not link directly to untracked `.artifacts/` payloads.
5. This rule does not require deleting all historical `.tmp` strings from prose. It targets link hygiene: avoid markdown links or frontmatter `sources` entries to uncommitted local artifact paths unless the path has been deliberately promoted into the repository.

## Applied In This Run

- Repointed the remaining `.artifacts` frontmatter/source-list citations in the audited `memory-packing`, `once-reduction`, `pick-load-signs`, and `remove-unused-names` living pages to their committed 2026-06-03 O4z audit research notes.
- Added a policy paragraph to [`tooling/fuzz-corpus-policy.md`](../../tooling/fuzz-corpus-policy.md) so future corpus, compare-pass, and generated-artifact pages know how to promote evidence before citing it.

## Follow-Up

A broader cleanup can continue replacing `.artifacts` source links in older pass dossiers as each dossier gains a committed raw research note with equivalent aggregate evidence. Do this incrementally; do not silently delete useful historical slot numbers, timings, or mismatch classifications without first preserving them in committed notes.
