# Numbered Research Workspace

Current status: **empty of numbered research notes as of 2026-07-18**. The 1,757 investigations present at the start of the closeout were absorbed into living wiki pages and removed. [`../../research-archive-closeout.md`](../../research-archive-closeout.md) records the result and ownership policy. Exact deleted text remains available through git history.

This directory remains the temporary workspace for substantial repo-authored investigations that need a numbered document while active. It is not a permanent agent-only archive.

## Serial policy

New notes use `[serial]-[YYYY-MM-DD]-[kebab-title].md` with the next zero-padded serial after checking:

- active numbered documents in `docs/`, `docs/wiki/`, and this directory;
- repository history for deleted or moved serials;
- historical duplicate prefixes.

Deleted and historical serials remain reserved. Do not fill holes or reuse a number because this directory is empty.

## Investigation lifecycle

1. Start a numbered note here only when the work is substantial enough to need an investigation, audit, benchmark ledger, or execution plan outside an existing living page.
2. Link the active note from the relevant backlog, tracker, or living dossier while the investigation is in progress.
3. Keep direct source, test, command, uncertainty, contradiction, and supersession evidence in the active note.
4. As conclusions stabilize, update the maintained `docs/wiki/` owner pages instead of growing a permanent per-probe ladder.
5. At closeout, repoint live references, verify the living owner contains the durable contract and reopening criteria, then delete the numbered note in the same change.
6. Use git history when exact old text is needed. Recheck that text against current source before restoring any conclusion.

Do not keep a completed note merely as a citation target. Prefer living owner pages, repository source/tests, and retained primary-source captures under sibling `docs/wiki/raw/` directories.

## Closeout checklist

- Durable conclusions, measurements, caveats, and reopening criteria are present in maintained wiki pages.
- The wiki index, tracker/backlog, and log route readers to those owners.
- All `raw/research/<numbered-note>` links, source entries, comments, fixtures, and machine-readable evidence paths are repointed.
- No deleted numbered filename remains as a live raw-note citation.
- Frontmatter is valid and every `sources:` list remains nonempty.
- Newly introduced relative links resolve.
- The numbered note is deleted; git history preserves exact provenance.

## Forwarding stub hygiene

Forwarding stubs under `docs/` are transitional compatibility shims, not research archives or living documentation. A valid stub should be tiny: title, living wiki-page link, and a warning not to add new references there. It must not link to a deleted numbered note.

Current intentional stubs:

| Legacy path | Living page | Current reason to keep |
| --- | --- | --- |
| [`../../../0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../0063-2026-03-24-pass-port-batches-and-registry-map.md) | [`../../ir2/registry-map.md`](../../ir2/registry-map.md), [`../../ir2/execution-plan.md`](../../ir2/execution-plan.md) | Compatibility for old pass-port links. |
| [`../../../0064-2026-03-24-ir2-test-matrix.md`](../../../0064-2026-03-24-ir2-test-matrix.md) | [`../../ir2/test-matrix.md`](../../ir2/test-matrix.md) | Compatibility for the old test-matrix path. |
| [`../../../0065-2026-03-24-ir2-execution-plan.md`](../../../0065-2026-03-24-ir2-execution-plan.md) | [`../../ir2/execution-plan.md`](../../ir2/execution-plan.md) | Compatibility plus repo tests that still check the old handoff path. |
| [`../../../0089-2026-04-15-fuzz-stack-hardening-execution-plan.md`](../../../0089-2026-04-15-fuzz-stack-hardening-execution-plan.md) | [`../../validate/fuzz-hardening.md`](../../validate/fuzz-hardening.md) | Compatibility for the old validator-fuzz plan path. |

Remove a stub only after repo-local tests and live references no longer require it. Update this table, [`../../index.md`](../../index.md), and [`../../log.md`](../../log.md) in the same change.
