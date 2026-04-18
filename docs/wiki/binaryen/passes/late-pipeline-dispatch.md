---
kind: concept
status: supported
last_reviewed: 2026-04-18
sources:
  - ../../raw/research/0080-2026-04-11-late-pipeline-pass-dispatch-audit.md
  - ../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - ../../../../src/cli/cli.mbt
  - ../../../../src/cmd/cmd.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/passes/trace_golden_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Late `-O4z` Pipeline Dispatch

## Durable Conclusions

- `-O4z` still resolves to `optimize_level=4` and `shrink_level=4`; when no explicit pass flags are present, `shrink` owns the tail roster.
- The late tail is implemented in-tree. The current module-pass slice includes `memory-packing`, `once-reduction`, `global-refining`, and `global-struct-inference`.
- The current hot-pass slice includes `dead-code-elimination`, `vacuum`, `optimize-instructions`, `heap-store-optimization`, `pick-load-signs`, `precompute`, `heap2local`, and `simplify-locals`.
- The broader preset still interleaves `ssa-nomerge`, `remove-unused-names`, and `remove-unused-brs` around that tail; this page keeps those supporting cleanup passes implicit to stay compact.
- `vacuum` is a registered hot pass in `src/passes/optimize.mbt` and runs through the hot-pass dispatcher in `src/passes/pass_manager.mbt`.
- The remaining work for these pages is documentation depth, not dispatcher reachability.

## Current Ordered Audit

- The 2026-04-18 generated `cmd.wasm` audit observed 56 top-level slots, 34 implemented Starshine slots, and 7 hard corruption slots.
- The hard-failure cluster is concentrated in `remove-unused-brs`, `optimize-instructions`, `precompute`, and `vacuum`; the expensive-but-successful cluster includes `simplify-locals`, `dead-code-elimination`, `tuple-optimization`, `ssa-nomerge`, and `heap2local`.
- Slot-specific raw follow-ups are `0094` through `0100`; use those notes for the exact failing states when reducing one corruption slot at a time.

## Compact Roster

- Module-pass owners: `src/passes/pass_manager.mbt`
- Hot-pass owners: `src/passes/optimize.mbt` and `src/passes/pass_manager.mbt`
- Use `binaryen/passes/index.md` for navigation; use the per-pass pages for algorithmic detail as they are added.

## Current Binaryen Terminology Check

- A 2026-04-18 web check against non-GitHub primary-ish sources still shows upstream-facing Binaryen surfaces exposing the same command-line names this wiki uses for `global-refining`, `heap-store-optimization`, `memory-packing`, `once-reduction`, `optimize-instructions`, `precompute`, `remove-unused-brs`, and `vacuum`.
- The Debian experimental `wasm-opt` manpage for Binaryen `122` still lists `--global-refining`, `--heap-store-optimization`, `--memory-packing`, `--once-reduction`, `--optimize-instructions`, `--precompute`, `--precompute-propagate`, `--remove-unused-brs`, and `--vacuum`.
- That same Debian manpage is also a useful source-lag reminder, not just a terminology check: it already exposes some upstream-only passes outside Starshine's implemented subset, including `--minimize-rec-groups`, `--string-lowering`, and `--remove-unused-types`, but it still does not expose later additions like `--strip-toolchain-annotations` that show up in the newer Chromium-hosted release-note trail.
- The current `wasm_opt` Rust bindings remain non-exhaustive and lag even further on the upstream-only surface: they still include `GlobalRefining`, `HeapStoreOptimization`, `MemoryPacking`, `OnceReduction`, `OptimizeInstructions`, `Precompute`, `PrecomputePropagate`, `RemoveUnusedBrs`, `Vacuum`, `RemoveUnusedTypes`, and related older GC-era passes, but they do not surface newer names such as `MinimizeRecGroups` or `StringLowering`. They also describe `Dce` as `Removes unreachable code`, which matches this repo's `dead-code-elimination` terminology at the behavioral level.
- A second 2026-04-18 check against the Chromium-hosted Binaryen mirror shows current trunk activity without renaming these late passes: `Precompute` had a substantial child-retention rewrite on 2025-08-27, a 2026-03-23 fix that keeps GC writes like `ArrayStore` in the effects model, a 2026-03-25 fix that stopped constant-folding GC `struct` / `array` atomic RMW and `cmpxchg` ops, and a later 2026-03-26 multibyte-array-access follow-up that makes `array.load` stay `NONCONSTANT_FLOW` for now instead of being folded like ordinary constant reads; `RemoveUnusedBrs` gained a `branch -> trap => trap` rewrite on 2026-02-27; and `Vacuum` stopped turning explicit `unreachable` into `nop` on 2026-02-27 so unreachability can propagate to callers.
- The Chromium-hosted Binaryen refs page visible to this maintenance run still shows `refs/heads/main` plus `version_129` (`2026-04-01`) as the newest directly reachable release tag in that public mirror listing; earlier directly reachable tag pages for `version_127` (`2026-03-10`) and `version_128` (`2026-03-13`) remain part of the same non-GitHub evidence trail.
- Those directly reachable changelog sections still show the same upstream-only pass additions outside this repo's current implementation set: `--minimize-rec-groups` is already present by `version_119`, `--string-lifting` and `TypeRefiningGUFA` are present by `version_124`, `ReorderTypes` is called out in `version_125`, and `--remove-relaxed-simd` plus `--strip-toolchain-annotations` are present by `version_126`.
- The newer reachable `version_127` / `version_128` / `version_129` changelog sections did not add another optimization pass name relevant to this folder map; `version_128` is explicitly a bugfix release, while `version_127` and `version_129` highlight proposal/API/tooling changes such as Custom Page Sizes, multibyte array load/store support, and new API surfaces.
- The current `main` branch changelog page reachable in that same Chromium mirror also does not currently advertise a newer optimization-pass addition: its `Current Trunk` section now leads with C/JS API renames from `MemorySegment` to `DataSegment`, not a new optimization pass. Treat that as a useful freshness check, not a complete pass-history audit, because changelog coverage is narrower than source-level pass enumeration.
- That matters for source-of-truth hygiene: this folder map tracks Starshine's implemented Binaryen pass subset, not the full current upstream pass catalog. The Debian manpage and docs.rs enum are useful lower-bound public surfaces, but they are incomplete in different directions, so neither should be treated as authoritative evidence that a newer upstream-only pass was added, renamed, or removed. Because this run avoids GitHub by policy, treat the reachable Chromium-hosted release-note set as the public changelog baseline through `version_129`, while still treating commit-level trunk activity as a separate drift watch rather than a complete audit of every Binaryen pass change on `main`.
- Those mirror commits are newer than the repo's `version_129` tagged source oracle for implemented-pass deep dives, so they should be tracked as post-`version_129` behavior drift, not as proof that this repo's existing folder names are stale.
- Because this maintenance run avoids GitHub by policy, this terminology check should be treated as a current naming sanity check plus a lightweight trunk-activity watch, not as a full source audit of every Binaryen pass on `main`.
- The safest non-GitHub source-of-truth rule remains: use the Chromium refs page to anchor what the latest directly reachable release tag is, use tagged release-note pages to bound public pass-addition claims, and use the current `main` changelog only as a narrow drift watch for obviously documented post-tag changes.

## Sources

- Archived audit: [`../../raw/research/0080-2026-04-11-late-pipeline-pass-dispatch-audit.md`](../../raw/research/0080-2026-04-11-late-pipeline-pass-dispatch-audit.md)
- Current ordered audit: [`../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`](../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md)
- [`../../../../src/cli/cli.mbt`](../../../../src/cli/cli.mbt)
- [`../../../../src/cmd/cmd.mbt`](../../../../src/cmd/cmd.mbt)
- [`../../../../src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt)
- [`../../../../src/passes/pass_manager.mbt`](../../../../src/passes/pass_manager.mbt)
- [`../../../../src/passes/optimize_test.mbt`](../../../../src/passes/optimize_test.mbt)
- [`../../../../src/passes/trace_golden_test.mbt`](../../../../src/passes/trace_golden_test.mbt)
- [`../../../../src/cmd/cmd_wbtest.mbt`](../../../../src/cmd/cmd_wbtest.mbt)
- Debian experimental manpage for `wasm-opt` `122`: <https://manpages.debian.org/experimental/binaryen/wasm-opt.1.en.html>
- Rust `wasm_opt::Pass` docs: <https://docs.rs/wasm-opt/latest/wasm_opt/enum.Pass.html>
  - Current direct checks for this maintenance pass: `RemoveUnusedTypes` is present, while `MinimizeRecGroups` and `StringLowering` are absent from the published enum page.
- Bundled Binaryen README excerpt mirrored in `wasm-opt-sys`: <https://docs.rs/crate/wasm-opt-sys/latest/source/binaryen/README.md>
- Binaryen Chromium mirror commit `9de4aca15b3125d54aabaf2913a0988ff500bdba` (`2025-08-27`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/9de4aca15b3125d54aabaf2913a0988ff500bdba>
- Binaryen Chromium mirror commit `8f85446ee05b32726979a38284a48b1c3719208a` (`2026-03-23`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/8f85446ee05b32726979a38284a48b1c3719208a>
- Binaryen Chromium mirror commit `10c876d4d246a2e697a166879bcb6df0d7b7bbca` (`2026-03-25`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/10c876d4d246a2e697a166879bcb6df0d7b7bbca%5E%21/>
- Binaryen Chromium mirror commit `86f0d65bcf87c2491698b7cfd526f2f0614a75dd` (`2026-03-26`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/86f0d65bcf87c2491698b7cfd526f2f0614a75dd%5E%21/>
- Binaryen Chromium mirror commit `9ee4a25ee15ab53e796cb0b3f320cafa2622c407` (`2026-02-27`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/9ee4a25ee15ab53e796cb0b3f320cafa2622c407%5E%21/>
- Binaryen Chromium mirror commit `f284d54ef60a5b6e6c33b4c1f4d4b423f7a6b1c3` (`2026-02-27`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/f284d54ef60a5b6e6c33b4c1f4d4b423f7a6b1c3%5E%21/>
- Binaryen Chromium mirror release notes for `version_119`: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/tags/version_119>
- Binaryen Chromium mirror release notes for `version_124`: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/tags/version_124>
- Binaryen Chromium mirror release notes for `version_125`: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/tags/version_125>
- Binaryen Chromium mirror release notes for `version_126`: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/tags/version_126>
- Binaryen Chromium mirror refs listing: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+refs>
- Binaryen Chromium mirror `main` changelog: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/heads/main/CHANGELOG.md>
- Binaryen Chromium mirror release notes for `version_127`: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/tags/version_127>
- Binaryen Chromium mirror release notes for `version_128`: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/tags/version_128>
- Binaryen Chromium mirror release notes for `version_129`: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/tags/version_129>
