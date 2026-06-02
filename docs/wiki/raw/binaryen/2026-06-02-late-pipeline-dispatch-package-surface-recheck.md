# Binaryen `late-pipeline-dispatch` package-surface recheck

_Capture date:_ 2026-06-02  
_Status:_ immutable current-surface source bridge for `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`

## Sources checked

- Binaryen official GitHub release page for `version_125`: <https://github.com/WebAssembly/binaryen/releases/tag/version_125>
- Binaryen official GitHub `CHANGELOG.md` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md>
- Binaryen Chromium refs listing: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+refs>
- Binaryen Chromium-hosted `main` changelog: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/heads/main/CHANGELOG.md>
- Debian experimental `wasm-opt` manpage for Binaryen `122`: <https://manpages.debian.org/experimental/binaryen/wasm-opt.1.en.html>
- Rust `wasm_opt::Pass` docs: <https://docs.rs/wasm-opt/latest/wasm_opt/enum.Pass.html>
- Rust `wasm_opt` crate overview: <https://docs.rs/wasm-opt/latest/wasm_opt/>
- Bundled Binaryen README excerpt mirrored in `wasm-opt-sys`: <https://docs.rs/crate/wasm-opt-sys/latest/source/binaryen/README.md>

## Durable observations

- The public Binaryen release baseline is still `version_125`; nothing in the package-surface spot check changes the release-horizon correction note.
- The Debian manpage still lists the late-tail names this page expects, including `--global-refining`, `--heap-store-optimization`, `--memory-packing`, `--once-reduction`, `--optimize-instructions`, `--precompute`, `--precompute-propagate`, `--remove-unused-brs`, `--vacuum`, `--minimize-rec-groups`, `--string-lowering`, and `--remove-unused-types`.
- The published `wasm_opt::Pass` enum page still advertises the same naming convention as the command line, but it remains incomplete on this surface: `HeapStoreOptimization`, `MinimizeRecGroups`, and `StringLowering` are still absent from the current enum listing even though the crate overview now claims the `Pass` enum exposes or represents all Binaryen optimization passes.
- The bundled README excerpt mirrored through `wasm-opt-sys` still misspells `RemoveUnusedBrs` as `RemoveUnsedBrs`.
- The 2026-04-18 package-surface reading therefore still holds as of this 2026-06-02 recheck: Debian is a useful lower bound, docs.rs is self-contradictory on completeness, and the mirrored README is context-only for exact spelling.

## Durable follow-up

- Keep `docs/wiki/binaryen/passes/late-pipeline-dispatch.md` as the living summary of the late-tail roster and package-surface caveats.
- Update the page's source list and index/tracker summaries to cite this recheck alongside the existing 2026-06-02 release-horizon correction materials.
