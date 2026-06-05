# Research Archive

This directory holds repo-authored numbered investigations that are no longer kept in `docs/`. New research notes use the next unused zero-padded serial after scanning `docs/`, `docs/wiki/`, and `docs/wiki/raw/research/`; historical duplicate serial prefixes are stable provenance and must not be reused for new files.

## When To Archive

Move a numbered note here when its durable conclusions live in `docs/wiki/` or when it otherwise stops being the active normative contract. Keep active repo policy, schema, ADRs, and live handoffs in `docs/`; keep completed investigations, execution plans, source reconciliations, and debugging ledgers here.

Treat archived research notes as source material, not the main living answer. A living wiki page should summarize the current contract and cite the archived note only for provenance, detailed evidence, or superseded history.

## Move Checklist

- Keep the original numbered filename stable when moving a research note here, even if it uses a historical duplicate serial prefix.
- Before moving, search `docs/`, `docs/wiki/`, `agent-todo.md`, and the current diff for references to the old path.
- Repoint live references to the new `docs/wiki/raw/research/...` path so backlog notes, wiki sources, and catalog entries stay valid.
- Rewrite internal links in the moved note so they still resolve from this directory. Source-code links usually need to move from `../src/...` to `../../../../src/...`; wiki-page links usually need to move from `./wiki/...` to `../../...`; same-directory research-note links should stay `./...` instead of escaping back through `docs/wiki/raw/research/...`.
- If old audit-log entries intentionally keep the historical path, leave them unchanged; add a new `docs/wiki/log.md` entry for the archival move instead of rewriting history.
- Do not leave a full duplicate copy in `docs/`. If an old public path must keep working for a short transition, replace it with a tiny forwarding stub and remove that stub once live references no longer need it.
- When adding a fresh investigation directly to this archive, compute the next available serial from the union of `docs/`, `docs/wiki/`, and this directory; do not fill historical holes or reuse duplicate prefixes just because an old collision already exists.
- Treat archived notes as committed sources: after archival, only edit them for redaction, format normalization, or link repair needed by the move.
