---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../../raw/research/0080-2026-04-11-late-pipeline-pass-dispatch-audit.md
  - ../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - ../../raw/research/0571-2026-05-19-late-tail-five-pass-neighborhood-baseline.md
  - ../../raw/research/0572-2026-05-19-public-preset-late-tail-scheduling.md
  - ../../raw/binaryen/2026-06-04-binaryen-v130-release-horizon-recheck.md
  - ../../raw/research/0704-2026-06-04-binaryen-v130-release-horizon-recheck.md
  - ../../raw/research/0105-2026-04-18-generated-o4z-precompute-slot19-retired-by-writeback-guards.md
  - ../../raw/research/0106-2026-04-18-generated-o4z-vacuum-slot23-retired-by-carrier-wrapper-guard.md
  - ../../raw/research/0107-2026-04-18-generated-o4z-vacuum-slot33-retired-by-validator-escape-fix.md
  - ../../raw/research/0108-2026-04-18-generated-o4z-rub-slot40-retired-by-tail-value-if-rewrite-guard.md
  - ../../raw/research/0109-2026-04-18-generated-o4z-optimize-instructions-slot44-retired-by-replay-verification.md
  - ../../raw/research/0130-2026-04-20-vacuum-binaryen-research.md
  - ../../raw/research/0268-2026-04-23-generated-o4z-precompute-slot43-retired-by-hot-lower-prefix-label-guard.md
  - ../../../../src/cli/cli.mbt
  - ../../../../src/cmd/cmd.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/passes/trace_golden_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
  - https://docs.rs/wasm-opt/latest/wasm_opt/
related:
  - ./index.md
  - ../no-dwarf-default-optimize-path.md
  - ../release-horizon-and-oracles.md
---

# Late `-O4z` Pipeline Dispatch

## Durable Conclusions

- `-O4z` still resolves to `optimize_level=4` and `shrink_level=4`; when no explicit pass flags are present, `shrink` owns the tail roster.
- The late tail is implemented in-tree. The current module-pass slice includes `memory-packing`, `once-reduction`, `global-refining`, and `global-struct-inference`.
- The current hot-pass slice includes `dead-code-elimination`, `vacuum`, `optimize-instructions`, `heap-store-optimization`, `pick-load-signs`, `precompute`, `heap2local`, and `simplify-locals`.
- Public `optimize` and `shrink` now append the accepted late-tail suffix `simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize`; broader widening earlier in the preset remains separate work.
- The broader preset still interleaves `ssa-nomerge`, `remove-unused-names`, and `remove-unused-brs` around that tail; this page keeps those supporting cleanup passes implicit to stay compact.
- `vacuum` is a registered hot pass in `src/passes/optimize.mbt` and runs through the hot-pass dispatcher in `src/passes/pass_manager.mbt`.
- The remaining work for these pages is documentation depth, not dispatcher reachability.

## Current Ordered Audit

- The 2026-04-18 generated `cmd.wasm` audit observed 56 top-level slots, 34 implemented Starshine slots, and 7 hard corruption slots.
- All 7 hard corruption slots are now retired on the current tree; there is no remaining open hard-failure cluster from that saved audit.
- The later rooted continuation chain under `.tmp/o4z-post-5d2fd48/current-chain/` is also green on the current tree: slot `43` was retired by the HOT-lower carried-prefix own-label guard in [`0268`](../../raw/research/0268-2026-04-23-generated-o4z-precompute-slot43-retired-by-hot-lower-prefix-label-guard.md), and downstream implemented slots `44`, `45`, `47`, `50`, and `53` all validate successfully from that same chain.
- The retired blockers are now explicitly tracked in the living wiki:
  - `remove-unused-brs` early slot `14` was fixed by the large non-reorder-safe plain-`br` condition guard in [`0102`](../../raw/research/0102-2026-04-18-generated-o4z-rub-slot14-if-br-large-condition-guard.md)
  - `optimize-instructions` early slot `16` was fixed by the paired HOT-lower carrier/parent-exit guards in [`0103`](../../raw/research/0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md) and [`0104`](../../raw/research/0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md)
  - `precompute` early slot `19` was retired by the writeback guards in [`0105`](../../raw/research/0105-2026-04-18-generated-o4z-precompute-slot19-retired-by-writeback-guards.md)
  - `vacuum` slot `23` was retired by the follow-up replay confirmation in [`0106`](../../raw/research/0106-2026-04-18-generated-o4z-vacuum-slot23-retired-by-carrier-wrapper-guard.md), which showed the old `Func 652` failure disappeared with the earlier HOT-lower carrier-wrapper guard from [`0103`](../../raw/research/0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md)
  - `vacuum` slot `33` was retired by the validator-escape and guarded-writeback follow-up in [`0107`](../../raw/research/0107-2026-04-18-generated-o4z-vacuum-slot33-retired-by-validator-escape-fix.md), which showed the saved predecessor now replays to a `wasm-tools`-valid module and canonically matches Binaryen even though the underlying repair lived in validation and pass-manager writeback hygiene rather than a new `vacuum`-local cleanup rewrite
  - `remove-unused-brs` later slot `40` was retired by the conservative tail value-`if` rewrite guard in [`0108`](../../raw/research/0108-2026-04-18-generated-o4z-rub-slot40-retired-by-tail-value-if-rewrite-guard.md)
  - `optimize-instructions` later slot `44` was retired by the current-tree replay verification in [`0109`](../../raw/research/0109-2026-04-18-generated-o4z-optimize-instructions-slot44-retired-by-replay-verification.md), which showed the exact saved predecessor from [`0100`](../../raw/research/0100-2026-04-18-generated-o4z-optimize-instructions-slot44-func1818-stack-underflow.md) now emits valid wasm and matches Binaryen at the normalized-WAT and canonical-function level without a new pass-local mutator change in this run
- The expensive-but-successful cluster is unchanged: `simplify-locals`, `dead-code-elimination`, `tuple-optimization`, `ssa-nomerge`, and `heap2local` still need runtime work, but they are not current corruption blockers.
- Slot-specific raw follow-ups are [`0094`](../../raw/research/0094-2026-04-18-generated-o4z-rub-slot14-missing-i32-result.md) through [`0100`](../../raw/research/0100-2026-04-18-generated-o4z-optimize-instructions-slot44-func1818-stack-underflow.md), with retirement confirmations in [`0105`](../../raw/research/0105-2026-04-18-generated-o4z-precompute-slot19-retired-by-writeback-guards.md), [`0106`](../../raw/research/0106-2026-04-18-generated-o4z-vacuum-slot23-retired-by-carrier-wrapper-guard.md), [`0107`](../../raw/research/0107-2026-04-18-generated-o4z-vacuum-slot33-retired-by-validator-escape-fix.md), [`0108`](../../raw/research/0108-2026-04-18-generated-o4z-rub-slot40-retired-by-tail-value-if-rewrite-guard.md), and [`0109`](../../raw/research/0109-2026-04-18-generated-o4z-optimize-instructions-slot44-retired-by-replay-verification.md); use those notes for the exact failing states or the later green replays when reducing one corruption slot at a time.

## Compact Roster

- Module-pass owners: `src/passes/pass_manager.mbt`
- Hot-pass owners: `src/passes/optimize.mbt` and `src/passes/pass_manager.mbt`
- Use `binaryen/passes/index.md` for navigation; use the per-pass pages for algorithmic detail as they are added.

## Current Binaryen Terminology Check

- A 2026-06-02 web recheck against official Binaryen sources plus package-derived corroboration still shows upstream-facing Binaryen surfaces exposing the same command-line names this wiki uses for `global-refining`, `heap-store-optimization`, `memory-packing`, `once-reduction`, `optimize-instructions`, `precompute`, `remove-unused-brs`, and `vacuum`.
- A 2026-06-02 recheck of the Debian experimental `wasm-opt` manpage for Binaryen `122` still lists `--global-refining`, `--heap-store-optimization`, `--memory-packing`, `--once-reduction`, `--optimize-instructions`, `--precompute`, `--precompute-propagate`, `--remove-unused-brs`, and `--vacuum`.
- That same Debian manpage is also a useful source-lag reminder, not just a terminology check: it already exposes some upstream-only passes outside Starshine's implemented subset, including `--minimize-rec-groups`, `--string-lowering`, and `--remove-unused-types`, but it still does not expose later additions like `--strip-toolchain-annotations` that show up in the newer Chromium-hosted release-note trail.
- The 2026-06-02 docs.rs recheck still shows the current `wasm_opt` Rust bindings remain non-exhaustive and lag even further on the upstream-only surface, and they are not even a complete mirror of the older implemented subset this repo cares about. The published enum page does make one useful naming rule explicit: the listed pass enums use the same names as the command line, but with Rust capitalization conventions. That makes entries it *does* expose such as `GlobalRefining`, `MemoryPacking`, `OnceReduction`, `OptimizeInstructions`, `Precompute`, `PrecomputePropagate`, `RemoveUnusedBrs`, `Vacuum`, and `RemoveUnusedTypes` decent positive spelling evidence, while the 2026-04-18 check still treats the absence of `HeapStoreOptimization`, `MinimizeRecGroups`, and `StringLowering` there as wrapper-surface lag rather than rename evidence. The 2026-06-02 crate-overview recheck makes the caution stronger, not weaker: the crate root now claims its `Pass` enum represents or exposes all Binaryen passes, but the linked enum page still omits those names, so treat docs.rs as self-contradictory package-surface evidence for completeness and only moderately useful spelling evidence for entries the enum actually lists. The same enum page describes `Dce` as `Removes unreachable code`, which still matches this repo's `dead-code-elimination` terminology at the behavioral level.
- A 2026-06-02 recheck of the bundled Binaryen README overview mirrored through `wasm-opt-sys` is also not a perfect spelling oracle: it still lists `RemoveUnsedBrs` in the optimization-pass overview instead of `RemoveUnusedBrs`. Treat that README overview as useful broad context, but prefer the Debian CLI manpage, the docs.rs enum, and Chromium-hosted changelog/release-note pages when the exact current pass spelling matters.
- A second 2026-04-18 check against the Chromium-hosted Binaryen mirror plus a 2026-04-20 direct source follow-up shows current trunk activity without renaming these late passes: `Precompute` had a substantial child-retention rewrite on 2025-08-27, a 2026-03-23 fix that keeps GC writes like `ArrayStore` in the effects model, a 2026-03-25 fix that stopped constant-folding GC `struct` / `array` atomic RMW and `cmpxchg` ops, and a later 2026-03-26 multibyte-array-access follow-up that makes `array.load` stay `NONCONSTANT_FLOW` for now instead of being folded like ordinary constant reads; `RemoveUnusedBrs` gained a `branch -> trap => trap` rewrite on 2026-02-27 in Chromium commit `9ee4a25...`; and the same-day explicit-`unreachable` preservation change in `Vacuum.cpp` belongs to Chromium commit `f284d54...`, which is already present in Binaryen `version_129` rather than being a newer post-`version_129` drift fact.
- Official Binaryen release pages for the tracked public horizon through `version_130` are directly reachable on GitHub. The 2026-06-04 recheck 0704 plus the official release page, `main` changelog, Chromium refs listing, and Chromium-hosted changelog show `version_130` as the newest release tag.
- The `version_130` release horizon aligns with the current `main` changelog's `v130` section after the 2026-06-04 revalidation, which is the live follow-up watch for anything beyond the latest tag.
- Those directly reachable changelog sections still show the older upstream-only pass additions visible in the public release trail: `--minimize-rec-groups` is already present by `version_119`, [`--string-lifting`](string-lifting/index.md) and `TypeRefiningGUFA` are present by `version_124`, and `ReorderTypes` is called out in `version_125`. The `v130` section also names `MarkJSCalled` and `RemoveExports`; treat those as release-horizon facts until a dedicated pass-tracker expansion does owner/test/source reads. The `string-lifting`, `remove-relaxed-simd`, `strip-toolchain-annotations`, and [`strip-target-features`](strip-target-features/index.md) entries now have dedicated dossiers, but the live `main` changelog is the drift watch for anything beyond the latest public tag.
- The newer reachable `version_119` / `version_124` / `version_125` / `version_130` tagged-release sections now cover the current public release horizon; earlier releases are still useful historical context, while the live `main` changelog remains the post-tag drift watch.
- That matters for source-of-truth hygiene: this folder map tracks Starshine's implemented Binaryen pass subset, not the full current upstream pass catalog. The Debian manpage, docs.rs enum, and bundled README overview are all useful lower-bound public surfaces, but they are incomplete in different directions, so none of them should be treated as authoritative evidence that a newer upstream-only pass was added, renamed, or removed. Use official GitHub tagged release pages as the primary public release-horizon baseline through `version_130`, use the Chromium mirror as corroborating release-note and refs evidence, and use the official GitHub `main` changelog as the stronger current-trunk drift watch, while still treating all of those surfaces as narrower than a full source audit of every Binaryen pass on `main`. Search snippets and mirrored summaries are discovery aids only; verify against the direct official URLs before changing the baseline.
- Some of those mirror commits are post-`version_129` trunk evidence relative to the repo's tagged source oracle for implemented-pass deep dives, so track them as behavior drift, not as proof that this repo's existing folder names are stale. The corrected `Vacuum` commit `f284d54...` is the important exception here: it is pre-`version_129` and already present in the tag, so treat explicit-`unreachable` preservation as part of the tagged `vacuum` oracle instead of as a newer trunk-only behavior.
- The safest source-of-truth rule remains: use official GitHub tagged release pages first to anchor the public release horizon, keep the Chromium refs page plus tagged mirror pages as corroboration, and use the current `main` changelog on GitHub or Chromium only as a narrow drift watch for obviously documented post-tag changes.

## Sources

- Archived audit: [`../../raw/research/0080-2026-04-11-late-pipeline-pass-dispatch-audit.md`](../../raw/research/0080-2026-04-11-late-pipeline-pass-dispatch-audit.md)
- Current ordered audit: [`../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`](../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md)
- Retired slot-19 follow-up: [`../../raw/research/0105-2026-04-18-generated-o4z-precompute-slot19-retired-by-writeback-guards.md`](../../raw/research/0105-2026-04-18-generated-o4z-precompute-slot19-retired-by-writeback-guards.md)
- Retired slot-23 follow-up: [`../../raw/research/0106-2026-04-18-generated-o4z-vacuum-slot23-retired-by-carrier-wrapper-guard.md`](../../raw/research/0106-2026-04-18-generated-o4z-vacuum-slot23-retired-by-carrier-wrapper-guard.md)
- Retired slot-33 follow-up: [`../../raw/research/0107-2026-04-18-generated-o4z-vacuum-slot33-retired-by-validator-escape-fix.md`](../../raw/research/0107-2026-04-18-generated-o4z-vacuum-slot33-retired-by-validator-escape-fix.md)
- Rooted continuation retirement: [`../../raw/research/0268-2026-04-23-generated-o4z-precompute-slot43-retired-by-hot-lower-prefix-label-guard.md`](../../raw/research/0268-2026-04-23-generated-o4z-precompute-slot43-retired-by-hot-lower-prefix-label-guard.md)
- [`../../../../src/cli/cli.mbt`](../../../../src/cli/cli.mbt)
- [`../../../../src/cmd/cmd.mbt`](../../../../src/cmd/cmd.mbt)
- [`../../../../src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt)
- [`../../../../src/passes/pass_manager.mbt`](../../../../src/passes/pass_manager.mbt)
- [`../../../../src/passes/optimize_test.mbt`](../../../../src/passes/optimize_test.mbt)
- [`../../../../src/passes/trace_golden_test.mbt`](../../../../src/passes/trace_golden_test.mbt)
- [`../../../../src/cmd/cmd_wbtest.mbt`](../../../../src/cmd/cmd_wbtest.mbt)
- Debian experimental manpage for `wasm-opt` `122`: <https://manpages.debian.org/experimental/binaryen/wasm-opt.1.en.html>
- Rust `wasm_opt::Pass` docs: <https://docs.rs/wasm-opt/latest/wasm_opt/enum.Pass.html>
  - Current direct checks for this maintenance pass: the enum page explicitly says the variants follow the command-line pass names with Rust capitalization conventions; `RemoveUnusedTypes` is present, while `HeapStoreOptimization`, `MinimizeRecGroups`, and `StringLowering` are absent from the published enum page.
- Rust `wasm_opt` crate overview: <https://docs.rs/wasm-opt/latest/wasm_opt/>
  - Current direct check for this maintenance pass: the crate root now says the crate exposes or represents all Binaryen optimization passes via `Pass`, which conflicts with the omissions still visible on the linked enum page. Treat that docs.rs overview as self-contradictory coverage guidance, not as authoritative completeness evidence.
- Bundled Binaryen README excerpt mirrored in `wasm-opt-sys`: <https://docs.rs/crate/wasm-opt-sys/latest/source/binaryen/README.md>
  - Current direct check for this maintenance pass: the optimization-pass overview still misspells `RemoveUnusedBrs` as `RemoveUnsedBrs`, so use it as context, not as the canonical spelling source.
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
- Binaryen Chromium mirror release notes for `version_130`: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/tags/version_130>
- Binaryen Chromium mirror refs listing: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+refs>
- Binaryen Chromium mirror `main` changelog: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/heads/main/CHANGELOG.md>
- Binaryen official GitHub `main` changelog: <https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md>
- Binaryen `version_130` release-horizon recheck: [`../../raw/research/0704-2026-06-04-binaryen-v130-release-horizon-recheck.md`](../../raw/research/0704-2026-06-04-binaryen-v130-release-horizon-recheck.md)
- Binaryen `version_130` source capture: [`../../raw/binaryen/2026-06-04-binaryen-v130-release-horizon-recheck.md`](../../raw/binaryen/2026-06-04-binaryen-v130-release-horizon-recheck.md)
- Superseded Binaryen `version_125` correction: [`../../raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md`](../../raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md)
- Binaryen late-pipeline package-surface recheck: [`../../raw/research/0699-2026-06-02-late-pipeline-dispatch-package-surface-recheck.md`](../../raw/research/0699-2026-06-02-late-pipeline-dispatch-package-surface-recheck.md)
- Immutable source bridge for the package-surface recheck: [`../../raw/binaryen/2026-06-02-late-pipeline-dispatch-package-surface-recheck.md`](../../raw/binaryen/2026-06-02-late-pipeline-dispatch-package-surface-recheck.md)
- Superseded 2026-06-01 bridge: [`../../raw/binaryen/2026-06-01-binaryen-v130-current-trunk-release-horizon.md`](../../raw/binaryen/2026-06-01-binaryen-v130-current-trunk-release-horizon.md)
- Superseded `version_125` release-horizon refresh: [`../../raw/binaryen/2026-06-02-binaryen-v125-current-trunk-release-horizon.md`](../../raw/binaryen/2026-06-02-binaryen-v125-current-trunk-release-horizon.md)
- Binaryen official GitHub release page for `version_119`: <https://github.com/WebAssembly/binaryen/releases/tag/version_119>
- Binaryen official GitHub release page for `version_124`: <https://github.com/WebAssembly/binaryen/releases/tag/version_124>
- Binaryen official GitHub release page for `version_125`: <https://github.com/WebAssembly/binaryen/releases/tag/version_125>
- Binaryen official GitHub release page for `version_130`: <https://github.com/WebAssembly/binaryen/releases/tag/version_130>
- Binaryen Chromium mirror release notes for `version_119`: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/tags/version_119>
- Binaryen Chromium mirror release notes for `version_124`: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/tags/version_124>
- Binaryen Chromium mirror release notes for `version_125`: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/tags/version_125>
