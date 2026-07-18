# Raw Sources

Use this directory for committed, immutable source captures that belong in the repo-backed wasm knowledge base.

- Treat captured sources as read-only after import except for redaction or format normalization needed to remove sensitive data.
- `raw/research/` is the temporary numbered-investigation workspace. It is empty of numbered notes after the 2026-07-18 full absorption pass; completed notes should be deleted after durable conclusions and references move into living wiki pages.
- Topic raw-source directories such as `raw/binaryen/`, `raw/fuzzing/`, `raw/ir2/`, `raw/moonbit/`, `raw/node/`, `raw/release/`, `raw/validation/`, `raw/wasm/`, and `raw/wiki/` hold durable primary-source manifests or source snapshots grouped by source family.
- Preserve provenance whenever possible: original URL, title, author, date, and capture date.
- Keep filenames stable and descriptive.
- Prefer adding a short companion note or wiki-page citation over editing the source itself.
- Do not commit secrets, credentials, tokens, or private material that should not live in git.
