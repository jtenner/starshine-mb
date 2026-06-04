# Binaryen `version_130` release-horizon recheck

Captured: 2026-06-04

Purpose: recheck the repo-wide Binaryen public release baseline after the living wiki had been corrected down to `version_125` on 2026-06-02.

## Primary sources checked

- Official GitHub release page for `version_130`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_130>
  - Observed facts: page title is `version_130`, the page marks it `Latest`, release author line says it was released on `01 Jun 21:02`, and the release points at commit `5d704ad` with summary `Version 130 (#8793)`.
- Official GitHub `main` changelog
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md>
  - Observed facts: `Current Trunk` is immediately followed by `v130`; the `v130` section lists user-visible changes including `MarkJSCalled`, `RemoveExports`, Wide Arithmetic support, fuzzer-mode additions, relaxed-SIMD renaming, and MemorySegment-to-DataSegment API renames.
- Chromium mirror refs listing
  - URL: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+refs>
  - Observed facts: the tag list includes `version_130` before `version_129`, `version_128`, `version_127`, `version_126`, and `version_125`.
- Chromium-hosted `main` changelog
  - URL: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/heads/main/CHANGELOG.md>
  - Observed facts: it matches the official changelog structure with `Current Trunk`, then `v130`, then `v129`.

## Takeaways

- The public Binaryen release baseline is `version_130` as of this 2026-06-04 check.
- The 2026-06-02 `version_125` correction note remains useful provenance but is superseded for current release-horizon decisions by this recheck.
- The earlier 2026-06-01 `version_130` bridge is no longer just a stale false start; it is historical evidence that had the right target but should still be superseded by this stronger 2026-06-04 recheck because the release page, official changelog, and Chromium mirror now agree in the same captured note.
- Detailed pass dossiers should not be bulk-retagged from their reviewed `version_129` or current-main source contracts just because the global release baseline moved. Retag only after pass-specific source rereads.
- The `v130` changelog records two upstream pass names that are not yet Starshine implemented-pass coverage: `MarkJSCalled` and `RemoveExports`. Treat them as upstream release-horizon facts until a dedicated pass-tracker expansion decides whether to create living dossiers.
