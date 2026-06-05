# Research Archive

This directory holds repo-authored numbered investigations that are no longer kept in `docs/`.

## Filename And Serial Policy

New research notes use `NNNN-YYYY-MM-DD-kebab-title.md`, where `NNNN` is the next **unused** zero-padded serial after scanning `docs/`, `docs/wiki/`, and this archive. Pick `max(existing serials) + 1`; do not fill historical gaps or reuse an older prefix just because the date/topic seems related.

This archive intentionally preserves some older duplicate serial prefixes from pre-schema or migration-era work, such as the 0076/0077/0078/0079/0080, 0431/0434/0438/0444/0461/0472/0475, 0557/0570, and 0688/0689 families visible in the current listing. Treat those as historical provenance and stable filenames, not as permission to create another duplicate. If a duplicate makes a citation ambiguous, cite the full filename rather than only the numeric prefix.

If a future automation step assigns serials, it must follow the same rule and check the complete filename set before writing.

## When To Archive

Move a numbered note here when its durable conclusions live in `docs/wiki/` or when it otherwise stops being the active normative contract. Keep active repo policy, schema, ADRs, and live handoffs in `docs/`; keep completed investigations, execution plans, source reconciliations, and debugging ledgers here.

Treat archived research notes as source material, not the main living answer. A living wiki page should summarize the current contract and cite the archived note only for provenance, detailed evidence, or superseded history.

## Move Checklist

- Keep the original numbered filename stable when moving a research note here.
- Before moving, search `docs/`, `docs/wiki/`, `agent-todo.md`, and the current diff for references to the old path.
- Repoint live references to the new `docs/wiki/raw/research/...` path so backlog notes, wiki sources, and catalog entries stay valid.
- Rewrite internal links in the moved note so they still resolve from this directory. Source-code links usually need to move from `../src/...` to `../../../../src/...`; wiki-page links usually need to move from `./wiki/...` to `../../...`; same-directory research-note links should stay `./...` instead of escaping back through `docs/wiki/raw/research/...`.
- If old audit-log entries intentionally keep the historical path, leave them unchanged; add a new `docs/wiki/log.md` entry for the archival move instead of rewriting history.
- Do not leave a full duplicate copy in `docs/`. If an old public path must keep working for a short transition, replace it with a tiny forwarding stub and remove that stub once live references no longer need it.
- Treat archived notes as committed sources: after archival, only edit them for redaction, format normalization, or link repair needed by the move.
