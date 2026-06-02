# Binaryen `release-horizon` correction: `version_125` is the latest public tag

_Capture date:_ 2026-06-02  
_Status:_ immutable release-horizon source bridge for the living Binaryen release-oracle pages

## Official sources consulted

- Binaryen official GitHub release page for `version_125`: <https://github.com/WebAssembly/binaryen/releases/tag/version_125>
- Binaryen official GitHub `CHANGELOG.md` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md>
- Binaryen Chromium refs listing: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+refs>
- Binaryen Chromium-hosted `main` changelog: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/heads/main/CHANGELOG.md>

## Durable observations

- The newest public Binaryen release baseline is `version_125`, not `version_130`.
- The official GitHub release page for `version_125` exists and shows the release as published on 2025-11-19, with `512 commits` to `main` since that release.
- The Chromium refs listing's tag section shows `version_125` and older tags; no public `version_126`+ tag is visible there.
- The official GitHub `main` changelog's latest tagged-release section is `v125`.
- The earlier 2026-06-01 `version_130` release-horizon bridge is therefore stale and should be treated as superseded by this correction when updating living wiki pages.

## Durable follow-up

- Update the living release-horizon pages, pass catalog, tracker, and top-level wiki index to cite `version_125` as the latest public Binaryen release baseline.
- Keep detailed pass dossiers anchored to their reviewed `version_129` / current-main surfaces unless a later per-pass reread says otherwise.
