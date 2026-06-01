# Binaryen `late-pipeline-dispatch` current-trunk release-horizon refresh

_Capture date:_ 2026-06-01  
_Status:_ immutable current-trunk source bridge for the `docs/wiki/binaryen/passes/late-pipeline-dispatch.md` dossier

## Official sources consulted

- Binaryen official GitHub `CHANGELOG.md` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md>
- Binaryen official GitHub release page for `version_129`: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen Chromium mirror `main` changelog: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/heads/main/CHANGELOG.md>
- Binaryen Chromium refs listing: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+refs>

## Durable observations

- The public tagged release horizon still tops out at `version_129`; the current GitHub `main` changelog now has a `v130` section, so the earlier "no newer documented optimization-pass addition" wording in the living wiki is stale.
- The `v130` current-trunk section includes new additions beyond API renames, including `MarkJSCalled`, `RemoveExports`, and `Wide Arithmetic` support.
- The current-trunk section also includes new fuzzer modes and relaxed-SIMD / `MemorySegment`-to-`DataSegment` rename work, so it is clearly a live drift watch rather than a static pass catalog.
- The `late-pipeline-dispatch` page should keep the tagged-release baseline at `version_129`, but it should now explicitly note that current trunk has already moved past that baseline.
- The Chromium mirror remains a corroborating source for the public release-horizon story, but the official GitHub `main` changelog is the primary evidence for the new trunk additions.
