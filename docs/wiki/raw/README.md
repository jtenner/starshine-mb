# Raw Sources

Use this directory for committed, immutable source captures that belong in the repo-backed wasm knowledge base.

- Treat captured sources as read-only after import except for redaction or format normalization needed to remove sensitive data.
- `raw/research/` holds repo-authored numbered investigations that were moved out of `docs/` after they stopped being the active normative contract.
- Topic raw-source directories such as `raw/binaryen/`, `raw/moonbit/`, and `raw/wasm/` hold durable primary-source manifests or source snapshots grouped by source family.
- Preserve provenance whenever possible: original URL, title, author, date, and capture date.
- Keep filenames stable and descriptive.
- Prefer adding a short companion note or wiki-page citation over editing the source itself.
- Do not commit secrets, credentials, tokens, or private material that should not live in git.
