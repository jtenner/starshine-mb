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
- The current `wasm_opt` Rust bindings remain non-exhaustive and still include `GlobalRefining`, `HeapStoreOptimization`, `MemoryPacking`, `OnceReduction`, `OptimizeInstructions`, `Precompute`, `PrecomputePropagate`, `RemoveUnusedBrs`, and `Vacuum`; they also describe `Dce` as `Removes unreachable code`, which matches this repo's `dead-code-elimination` terminology at the behavioral level.
- A second 2026-04-18 check against the Chromium-hosted Binaryen mirror shows current trunk activity without renaming these late passes: `Precompute` had a substantial child-retention rewrite on 2025-08-27, a 2026-03-23 fix that keeps GC writes like `ArrayStore` in the effects model, a 2026-03-25 fix that stopped constant-folding GC `struct` / `array` atomic RMW and `cmpxchg` ops, and a later 2026-03-26 multibyte-array-access follow-up that makes `array.load` stay `NONCONSTANT_FLOW` for now instead of being folded like ordinary constant reads; `RemoveUnusedBrs` gained a `branch -> trap => trap` rewrite on 2026-02-27; and `Vacuum` stopped turning explicit `unreachable` into `nop` on 2026-02-27 so unreachability can propagate to callers.
- The Chromium-hosted release notes visible to this maintenance run show additional upstream-only pass additions outside this repo's current implementation set: `--minimize-rec-groups` is already present by `version_119`, `--string-lifting` and `TypeRefiningGUFA` are present by `version_124`, and `--remove-relaxed-simd` plus `--strip-toolchain-annotations` are present by `version_126`.
- That matters for source-of-truth hygiene: this folder map tracks Starshine's implemented Binaryen pass subset, not the full current upstream pass catalog, and the older Debian `122` manpage should be treated as a lagging public surface rather than evidence that those newer upstream-only passes were removed. Because this run avoids GitHub by policy, treat this release-note list as a conservative lower bound from the currently reachable non-GitHub sources, not a full historical audit of every Binaryen pass addition.
- Those mirror commits and release notes are newer than the repo's older `version_129` Binaryen source oracle for implemented-pass deep dives, so they should be treated as upstream behavior/addition drift to track explicitly, not as proof that this repo's existing folder names are stale.
- Because this maintenance run avoids GitHub by policy, this terminology check should be treated as a current naming sanity check plus a lightweight trunk-activity watch, not as a full source audit of every Binaryen pass on `main`.

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
- Bundled Binaryen README excerpt mirrored in `wasm-opt-sys`: <https://docs.rs/crate/wasm-opt-sys/latest/source/binaryen/README.md>
- Binaryen Chromium mirror commit `9de4aca15b3125d54aabaf2913a0988ff500bdba` (`2025-08-27`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/9de4aca15b3125d54aabaf2913a0988ff500bdba>
- Binaryen Chromium mirror commit `8f85446ee05b32726979a38284a48b1c3719208a` (`2026-03-23`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/8f85446ee05b32726979a38284a48b1c3719208a>
- Binaryen Chromium mirror commit `10c876d4d246a2e697a166879bcb6df0d7b7bbca` (`2026-03-25`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/10c876d4d246a2e697a166879bcb6df0d7b7bbca%5E%21/>
- Binaryen Chromium mirror commit `86f0d65bcf87c2491698b7cfd526f2f0614a75dd` (`2026-03-26`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/86f0d65bcf87c2491698b7cfd526f2f0614a75dd%5E%21/>
- Binaryen Chromium mirror commit `9ee4a25ee15ab53e796cb0b3f320cafa2622c407` (`2026-02-27`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/9ee4a25ee15ab53e796cb0b3f320cafa2622c407%5E%21/>
- Binaryen Chromium mirror commit `f284d54ef60a5b6e6c33b4c1f4d4b423f7a6b1c3` (`2026-02-27`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/f284d54ef60a5b6e6c33b4c1f4d4b423f7a6b1c3%5E%21/>
- Binaryen Chromium mirror release notes for `version_119`: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/tags/version_119>
- Binaryen Chromium mirror release notes for `version_124`: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/tags/version_124>
- Binaryen Chromium mirror release notes for `version_126`: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/tags/version_126>
