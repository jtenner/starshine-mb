---
kind: concept
status: supported
last_reviewed: 2026-08-14
sources:
  - ../release-horizon-and-oracles.md
  - ../../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md
  - ./remove-exports/index.md
  - ./vacuum/index.md
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
- Public `optimize` and `shrink` are level-sensitive. Their O4z expansion includes the accepted late-tail suffix `simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize`; lower levels admit those owners only at the Binaryen-v131 thresholds.
- The broader preset still interleaves `ssa-nomerge`, `remove-unused-names`, and `remove-unused-brs` around that tail; this page keeps those supporting cleanup passes implicit to stay compact.
- `vacuum` is a registered hot pass in `src/passes/optimize.mbt` and runs through the hot-pass dispatcher in `src/passes/pass_manager.mbt`.
- The corrected O4z early GC neighborhood is `global-refining -> remove-unused-module-elements -> global-struct-inference -> ssa-nomerge`. Registry tests assert all three RUME occurrences and the downstream slot indices.
- Binaryen `version_131` leaves the 56-slot / 38-owner top-level scheduler unchanged. Starshine preserves those first 56 slots exactly, then appends nineteen documented extensions: `strip-debug`, two `simplify-locals-nostructure -> coalesce-locals-cfg -> reorder-locals -> vacuum` waves, and two bounded `ssa-nomerge -> simplify-locals-nostructure -> coalesce-locals-cfg -> reorder-locals -> vacuum` cleanup waves. The CFG spelling is intentionally late-only: using it in the earlier compatibility slots perturbs inlining/simplification shape and increased the BLAKE3 SIMD artifact, while the current post-strip suffix and its local cleanup owners reduce validated BLAKE3 SIMD from 44,017 to 41,109 bytes (`-2,908`). `remove-unused-brs` still appears exactly three times at zero-based indices `13`, `24`, and `39`. The complete O4z expansion is now 75 entries.

## Current Ordered Audit

- On 2026-08-02, preset expansion became level- and module-feature-aware without changing the locked O4z result. DAE, optimizing inlining, and SGO now derive nested touched-function cleanup from the same active-level function scheduler; SGO's artifact-specific reduced roster and broad 192-local/1,000-instruction suppression were removed.

- The registry contract compares the complete first 56 O4z entries against the Binaryen-v131 roster, asserts all three RUB indices, and separately asserts the nineteen-entry Starshine suffix. Optimize and shrink expose the same 75-entry expansion only when their resolved levels are both 4; lower O/size levels are intentionally different.
- The 2026-07-31 `code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks` audit closed both ordered cleanup witnesses at O4z levels `4/4`: after final `strip-debug`, the block-exit fixture was `41` bytes versus Binaryen's `43`, and the EH fixture was byte-identical at `74` bytes. The later direct review is separately reclosed: RUB runtime preserves same-target condition effects/traps, and merge-blocks preserves the source program's first trap with a green/fully classified four-lane matrix.
- The historical first-1,000 expanded RUB-profile probe remains `837` valid / `163` invalid and is not silently reclassified. The current startup-map production lane no longer reproduces its validating/runtime failures: large typed-loop modules retain the `flatten` and `merge-locals` slots but fail closed before those owner-local path-sensitive hazards. The saved 1,000-case corpus still requires a fresh ordered rerun under `[O4Z-PRESET]001`; this does not reopen isolated RUB placement.
- The 2026-04-18 generated `cmd.wasm` audit observed 56 top-level slots, 34 implemented Starshine slots, and 7 hard corruption slots.
- All 7 hard corruption slots are now retired on the current tree; there is no remaining open hard-failure cluster from that saved audit.
- The later rooted continuation chain under `.tmp/o4z-post-5d2fd48/current-chain/` is also green on the current tree: slot `43` was retired by the HOT-lower carried-prefix own-label guard in `0268`, and downstream implemented slots `44`, `45`, `47`, `50`, and `53` all validate successfully from that same chain.
- The retired blockers are now explicitly tracked in the living wiki:
  - `remove-unused-brs` early slot `14` was fixed by the large non-reorder-safe plain-`br` condition guard in `0102`
  - `optimize-instructions` early slot `16` was fixed by the paired HOT-lower carrier/parent-exit guards in `0103` and `0104`
  - `precompute` early slot `19` was retired by the writeback guards in `0105`
  - `vacuum` slot `23` was retired by the follow-up replay confirmation in `0106`, which showed the old `Func 652` failure disappeared with the earlier HOT-lower carrier-wrapper guard from `0103`
  - `vacuum` slot `33` was retired by the validator-escape and guarded-writeback follow-up in `0107`, which showed the saved predecessor now replays to a `wasm-tools`-valid module and canonically matches Binaryen even though the underlying repair lived in validation and pass-manager writeback hygiene rather than a new `vacuum`-local cleanup rewrite
  - `remove-unused-brs` later slot `40` was retired by the conservative tail value-`if` rewrite guard in `0108`
  - `optimize-instructions` later slot `44` was retired by the current-tree replay verification in `0109`, which showed the exact saved predecessor from `0100` now emits valid wasm and matches Binaryen at the normalized-WAT and canonical-function level without a new pass-local mutator change in this run
- Runtime smoke on `tests/repros/o4z-debug-startup-map-init-repro.wasm` now passes separately for O1, O2, Os, Oz, and O4z. The 192,813-byte input produces 190,353, 192,610, 192,701, 192,704, and 192,785-byte Starshine outputs; verified Binaryen v131 produces 198,178 bytes at O4z, so the current Starshine O4z artifact is 5,393 bytes smaller on this fixture. This is a fixture-local measured win, not a substitute for the generated matrix.
- Production replay exposed path-sensitive runtime hazards that validation alone missed. Focused owner guards cover dynamic nonzero-offset stores, typed/untyped and parameter-initialized loop carriers, startup and post-inline SimplifyLocals shapes, SimplifyLocalsNoStructure ownership/effect lifetimes, TupleOptimization effect-bracketed multivalue spills, DCE call-result lifetimes, flattened CodePushing carriers, multiple typed-loop SSA forests, Precompute call/argument ordering, CodeFolding result-loop tails and large structured same-local call lifetimes, and large structured CoalesceLocals. TupleOptimization and OptimizeInstructions also validate changed-function writeback, with OptimizeInstructions batching validation and repair. On large typed-loop modules, DAE optimizing uses plain DAE at lower levels and results-only cleanup at O3+ or shrink level 2+, optimizing inlining falls back to plain inlining, SGO no-ops, and flatten/merge-locals preserve their scheduled slots as traced no-ops. These are explicit fail-closed boundaries pending smaller reductions and source-backed recovery.
- The 13,118,096-byte debug-WASI artifact with 11,999 functions is now green at O1: the rebuilt native release CLI completes in 88.171 seconds, writes 4,693,039 bytes, validates, and passes the repository Node/WASI `_start` smoke. A pass-by-pass replay from the repaired early prefix also validates and executes every remaining O1 intermediate through `strip-debug`.
- The O2 `code-pushing` and typed-loop DAE fallback blockers are repaired algorithmically rather than bypassed by module/function cardinality. CodePushing reuses one local-use inventory per mutation round, uses bitmap traversal, and preserves focused typed-loop/call-result lifetime hazards; its direct runtime-green prefix replay completes in 1.610 seconds. Plain DAE repeats its validated dropped-result batch to convergence and batches contiguous scalar discovery under one core setup; direct DAEOptimizing completes in 7.267 seconds instead of exceeding 360 seconds, writes 4,842,878 bytes, validates, and passes runtime. Typed-loop plain inlining now stops false-progress iterations when neither tracked bodies nor function count changes.
- By explicit user direction, non-O4z public presets are now wall-time-first instead of full Binaryen-shaped queues. O1/O2 run `duplicate-function-elimination -> strip-debug`; O3/O4/Os/Oz add only `vacuum -> reorder-locals`. Direct passes remain available, and O4z remains the exact full compatibility lane.
- The current 13,118,096-byte / 11,999-function debug-WASI matrix is external-validation and Node/WASI-runtime green: O1 1.944 seconds / 4,889,183 bytes, O2 1.962 / 4,889,183, O3 5.578 / 4,753,316, O4 5.729 / 4,753,316, literal `-Os` 5.611 / 4,753,316, literal `-Oz` 5.597 / 4,753,316, and full O4z 115.435 / 5,912,452 after the SimplifyLocals scan-cache, full-module breadth, and parameter-lifetime recovery. The August 4 reconstruction emits byte-identical O4z output and remains validation/runtime green. Compared with the previous 81.537-161.905-second non-O4z lanes, the new rosters are 24-59 times faster.
- Verified Binaryen v131 takes O1 1.742 seconds / 4,110,423 bytes, O2 5.103 / 3,983,181, O3 9.689 / 4,669,295, O4 15.199 / 4,581,026, Os 6.152 / 3,670,728, Oz 6.917 / 3,632,926, and combined `-O4 -Oz` 17.795 / 4,514,743. Starshine is now within 12% at O1 and faster at O2/O3/O4/Os/Oz, while retaining larger outputs. O4z remains both slower and larger and is the active compatibility-lane wall-time owner.
- The exact saved 1,000-input ordered O4z corpus is freshly green with the current native CLI: all Starshine and Binaryen outputs validate; `837` pairs are raw byte-identical; the remaining `163` Starshine artifacts are larger by `3,491` bytes total; and symmetric verified-v131 `-Oz --strip-debug` canonicalization makes all `1,000` pairs byte-identical. Those `163` residuals are classified as raw output-shape parity gaps with no measured Starshine benefit.
- Corrected direct size attribution uses the same 4,977,401-byte Starshine-canonical debug-free input for both tools, but computes savings against each tool's own no-op roundtrip: Starshine 4,977,401 bytes and verified Binaryen v131 5,300,041 bytes. This prevents Binaryen's 322,640-byte codec/re-encoding difference from being misattributed to each pass. All reported direct outputs validate; timing medians use one warmup plus three serial runs.
- Debug metadata is not the remaining production gap. The 13,118,096-byte source has only one custom section, `name`, occupying 7,841,984 bytes including framing, and it is absent from compared outputs. The remaining gap is code-section transformation breadth.
- The dominant direct families are now measured: CoalesceLocals saves 0 versus Binaryen's 517,553 bytes because Starshine returns the entire module when any large structured function trips its guard; full/no-structure SimplifyLocals save 0 / 17,941 versus 442,185 / 442,895 bytes; optimizing inlining expands Starshine by 1,249,559 while shrinking Binaryen by 1,119,242; and direct Starshine DAE/DAEO exceed 150 seconds while Binaryen DAEO takes 0.888 seconds and saves 102,216 bytes. The largest sampled Binaryen coalescing result reduces one function from 8,249 body locals to 18.
- Ordered combinations confirm overlap-aware priorities: locals-core has an 849,691-byte savings gap, broader function cleanup 1,092,117 bytes, and optimizing inlining plus locals cleanup 2,245,471 bytes. Secondary direct gaps are precompute-propagate 66,206 bytes, precompute 55,840, OptimizeInstructions 34,192, Vacuum 24,295, CodeFolding 23,564, RUB 21,805, SGO 7,885, ReorderLocals 5,901, and RSE 4,196. Use `.tmp/production-smoke/size-attribution-accurate/summary.md` as the current measurement manifest.
- Slot-specific raw follow-ups are `0094` through `0100`, with retirement confirmations in `0105`, `0106`, `0107`, `0108`, and `0109`; use those notes for the exact failing states or the later green replays when reducing one corruption slot at a time.

## Absorbed historical witnesses and preset experiment

The initial slot-16 witness failed final validation at `Func 652` after early `optimize-instructions`. Later reduction proved this was a HOT-lower carrier-wrapper stackification bug, not a generally invalid predecessor; the carrier guard retired `Func 652`, exposed an independent `Func 1818` family, and the subsequent parent-exit guard plus full replay retired the slot. Keep the origin failure and retirement chain together when diagnosing similar ordered-pipeline underflows.

A separate JSON-AS preset experiment measured `duplicate-function-elimination -> remove-unused-module-elements -> code-folding -> redundant-set-elimination -> remove-unused-module-elements` after Starshine O4. All three analyzed artifacts validated and passed Node runtime smoke. The suffix saved `16,510`, `1,963`, and `21,214` bytes versus Starshine O4, while the incremental code-folding/RSE portion saved `396`, `399`, and `1,017` bytes after DFE/RUME. This is evidence for a safe incremental size suffix, not Binaryen O4 parity: function/type/code counts remained substantially larger, DFE's incidental name-section stripping is not a substitute for explicit `strip-debug`, and any scheduling change still needs preset-order tests plus fresh artifact/runtime validation.

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
- Binaryen `version_131` is the current public release horizon. The 2026-07-18 audit confirms that `pass.cpp` adds public `constraint-analysis` and hidden `remove-start` without changing the default optimization order.
- The live `main` changelog is now the drift watch for anything beyond `version_131`; current-main changes already captured before July 15 should be treated as released behavior when they are present in the tag.
- Those directly reachable changelog sections still show the older upstream-only pass additions visible in the public release trail: `--minimize-rec-groups` is already present by `version_119`, [`--string-lifting`](string-lifting/index.md) and `TypeRefiningGUFA` are present by `version_124`, and `ReorderTypes` is called out in `version_125`. The `v130` section also names [`mark-js-called`](mark-js-called/index.md) and [`remove-exports`](remove-exports/index.md); the 2026-06-04 source reads establish their owner/test and behavior contracts, and the 2026-07-11 owner/fixture/registration recheck found no behavior-bearing current-main drift: `mark-js-called` remains configureAll-driven `js.called` annotation synthesis and `remove-exports` remains parameterized wildcard export filtering. The `string-lifting`, `remove-relaxed-simd`, `strip-toolchain-annotations`, [`strip-target-features`](strip-target-features/index.md), `mark-js-called`, and `remove-exports` entries now have dedicated routing, but the live `main` changelog is the drift watch for anything beyond the latest public tag.
- The reachable `version_119` / `version_124` / `version_125` / `version_130` / `version_131` tagged-release sections cover the current public release horizon; earlier releases remain historical context.
- That matters for source-of-truth hygiene: this folder map tracks Starshine's implemented Binaryen pass subset, not the full current upstream pass catalog. The Debian manpage, docs.rs enum, and bundled README overview are all useful lower-bound public surfaces, but they are incomplete in different directions, so none of them should be treated as authoritative evidence that a newer upstream-only pass was added, renamed, or removed. Use official GitHub tagged release pages as the primary public release-horizon baseline through `version_131`, use the Chromium mirror as corroborating release-note and refs evidence, and use the official GitHub `main` changelog as the stronger current-trunk drift watch, while still treating all of those surfaces as narrower than a full source audit of every Binaryen pass on `main`. Search snippets and mirrored summaries are discovery aids only; verify against the direct official URLs before changing the baseline.
- Some of those mirror commits are post-`version_129` trunk evidence relative to the repo's tagged source oracle for implemented-pass deep dives, so track them as behavior drift, not as proof that this repo's existing folder names are stale. The corrected `Vacuum` commit `f284d54...` is the important exception here: it is pre-`version_129` and already present in the tag, so treat explicit-`unreachable` preservation as part of the tagged `vacuum` oracle instead of as a newer trunk-only behavior.
- The safest source-of-truth rule remains: use official GitHub tagged release pages first to anchor the public release horizon, keep the Chromium refs page plus tagged mirror pages as corroboration, and use the current `main` changelog on GitHub or Chromium only as a narrow drift watch for obviously documented post-tag changes.

## Sources

- Durable audit summary: research note 0080
- Current ordered audit: research note 0093
- Retired slot-19 follow-up: research note 0105
- Retired slot-23 follow-up: research note 0106
- Retired slot-33 follow-up: research note 0107
- Rooted continuation retirement: research note 0268
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
- Binaryen `version_131` release-impact audit: [research note 1573](../release-horizon-and-oracles.md)
- Historical Binaryen `version_130` release-horizon recheck: [research note 0704](../release-horizon-and-oracles.md)
- Binaryen `mark-js-called` / `remove-exports` current-main recheck: [`../../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md`](../../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md)
- Retained `mark-js-called` / `remove-exports` tracker expansion: [research note 0706](./remove-exports/index.md)
- Superseded Binaryen `version_125` correction: [research note 0698](../release-horizon-and-oracles.md)
- Binaryen late-pipeline package-surface recheck: research note 0699
- Superseded 2026-06-01 bridge: ingested and removed; use the retained 2026-06-04 release-horizon sources above.
- Superseded `version_125` release-horizon correction: [research note 0698](../release-horizon-and-oracles.md)
- Binaryen official GitHub release page for `version_119`: <https://github.com/WebAssembly/binaryen/releases/tag/version_119>
- Binaryen official GitHub release page for `version_124`: <https://github.com/WebAssembly/binaryen/releases/tag/version_124>
- Binaryen official GitHub release page for `version_125`: <https://github.com/WebAssembly/binaryen/releases/tag/version_125>
- Binaryen official GitHub release page for `version_131`: <https://github.com/WebAssembly/binaryen/releases/tag/version_131>
- Binaryen official GitHub v130-to-v131 compare: <https://github.com/WebAssembly/binaryen/compare/version_130...version_131>
- Historical Binaryen official GitHub release page for `version_130`: <https://github.com/WebAssembly/binaryen/releases/tag/version_130>
- Binaryen Chromium mirror release notes for `version_119`: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/tags/version_119>
- Binaryen Chromium mirror release notes for `version_124`: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/tags/version_124>
- Binaryen Chromium mirror release notes for `version_125`: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/tags/version_125>
