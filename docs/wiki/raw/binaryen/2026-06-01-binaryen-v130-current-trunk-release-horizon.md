# Binaryen `late-pipeline-dispatch` current-trunk release-horizon refresh

_Capture date:_ 2026-06-01  
_Status:_ immutable current-trunk source bridge for the `docs/wiki/binaryen/passes/late-pipeline-dispatch.md` dossier

## Official sources consulted

- Binaryen official GitHub `CHANGELOG.md` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md>
- Binaryen official GitHub release page for `version_130`: <https://github.com/WebAssembly/binaryen/releases/tag/version_130>
- Binaryen Chromium mirror `main` changelog: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/heads/main/CHANGELOG.md>
- Binaryen Chromium refs listing: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+refs>

## Durable observations

- The public tagged release horizon now reaches `version_130`; the direct GitHub release page exists, and the Chromium refs listing also shows `version_130` as the newest visible tag in the mirror.
- The official GitHub `main` changelog still carries the matching `v130` section, so the earlier "no newer documented optimization-pass addition" wording in the living wiki is stale.
- The `v130` section includes new additions beyond API renames, including `MarkJSCalled`, `RemoveExports`, and `Wide Arithmetic` support.
- The `late-pipeline-dispatch` page should keep the tagged-release baseline at `version_130` now, while still treating the current `main` changelog as the live drift watch for anything beyond that tag.
- The Chromium mirror remains a corroborating source for the public release-horizon story, but the official GitHub `version_130` release page plus the `main` changelog are the primary evidence for the current latest Binaryen release.
