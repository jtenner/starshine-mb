# Raw Sources

Use this directory for committed, immutable source captures that belong in the repo-backed wasm knowledge base.

- Treat captured sources as read-only after import except for redaction or format normalization needed to remove sensitive data.
- `raw/research/` is the temporary numbered-investigation workspace. It currently contains active and recently retained investigations; completed notes should be deleted after durable conclusions and references move into living wiki pages. The 2026-07-18 archive closeout was a historical zero-note snapshot, not a permanent empty-directory invariant.
- The currently retained topic source directory is `raw/binaryen/`. Earlier `raw/wasm/`, `raw/ir2/`, `raw/validation/`, `raw/moonbit/`, `raw/node/`, `raw/release/`, `raw/fuzzing/`, and `raw/wiki/` captures were absorbed into living pages and removed; do not recreate them solely to restore old citation paths.
- Preserve provenance whenever possible: original URL, title, author, date, and capture date.
- Keep filenames stable and descriptive.
- Prefer adding a short companion note or wiki-page citation over editing the source itself.
- Do not commit secrets, credentials, tokens, or private material that should not live in git.
