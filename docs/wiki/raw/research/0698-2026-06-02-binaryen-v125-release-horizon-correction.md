# 0698 — 2026-06-02 Binaryen release-horizon correction

## Question

Is `version_130` really the latest public Binaryen release horizon, or does the current public release baseline stop at `version_125`?

## Sources checked

- `https://github.com/WebAssembly/binaryen/releases/tag/version_125`
- `https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md`
- `https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+refs`
- `https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/heads/main/CHANGELOG.md`

## Finding

The newest public Binaryen release baseline is `version_125`.

Observed facts:

- The official GitHub release page for `version_125` exists and is the newest public release page surfaced in the current check.
- The official GitHub `main` changelog's latest tagged-release section is `v125`.
- The Chromium refs listing shows `version_125` among the visible tags, and no later public tag appears in the current check.
- The earlier living-wiki `version_130` release-horizon wording is therefore stale and should be repointed to `version_125`.

## Durable update

The living release-oracle pages should now cite this correction instead of the earlier `version_130` bridge.
Detailed pass dossiers should keep their reviewed `version_129` / current-main contracts unless a later pass-specific reread says otherwise.
