---
kind: concept
status: supported
last_reviewed: 2026-06-14
sources:
  - ../raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md
  - ../raw/binaryen/2026-06-13-ssa-nomerge-version-130-source-refresh.md
  - ../raw/research/0571-2026-05-19-late-tail-five-pass-neighborhood-baseline.md
  - ../raw/research/0572-2026-05-19-public-preset-late-tail-scheduling.md
  - ../raw/binaryen/2026-06-04-binaryen-v130-release-horizon-recheck.md
  - ../raw/research/0704-2026-06-04-binaryen-v130-release-horizon-recheck.md
  - ../raw/research/0714-2026-06-07-o4z-behavior-parity-inventory.md
related:
  - ../../../agent-todo.md
  - ../../../src/passes/optimize.mbt
  - ../../../src/passes/optimize_test.mbt
  - ../../../scripts/self-optimize-compare.ts
  - ../../../scripts/test/self-optimize-compare-command.ts
  - ./release-horizon-and-oracles.md
---

# Binaryen No-DWARF Default Optimize Path

## Durable Conclusions

- For Binaryen `version_129`, `-O` and `-Os` both mean `optimizeLevel=2` and `shrinkLevel=1`.
- The default optimizer is phase-structured, not a flat pass bag:
  - global pre-passes
  - function optimization passes
  - global post-passes
- The MoonBit debug artifact at `tests/node/dist/starshine-debug-wasi.wasm` has a `name` section but no `.debug_*` sections, so Binaryen takes the unrestricted no-DWARF path.
- Feature gates matter. The observed artifact enables the GC-, multivalue-, and string-gated passes that appear in the real pathway.
- A `2026-04-09` source review found the open-world no-DWARF `-O` / `-Os` path for this artifact unchanged between the archived `version_125` note and upstream `version_129`.
- The public Binaryen release horizon has since advanced to `version_130`; this page's detailed no-DWARF path audit still reflects the original `version_129` source set, so treat the older wording here as a historical baseline rather than newest-tag coverage.

## Canonical Top-Level Shape

- Pre-pass phase:
  `duplicate-function-elimination -> remove-unused-module-elements -> memory-packing -> once-reduction -> global-refining -> remove-unused-module-elements -> gsi`
- Function phase:
  `ssa-nomerge -> dce -> remove-unused-names -> remove-unused-brs -> remove-unused-names -> optimize-instructions -> heap-store-optimization -> pick-load-signs -> precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs -> heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals -> vacuum -> reorder-locals -> coalesce-locals -> reorder-locals -> vacuum -> code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks -> precompute -> optimize-instructions -> heap-store-optimization -> rse -> vacuum`
- Post-pass phase:
  `dae-optimizing -> inlining-optimizing -> duplicate-function-elimination -> duplicate-import-elimination -> simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize`

## 2026-06-14 `ssa-nomerge` scheduling anchors

`[SSANM-010a]` refreshed only the `ssa-nomerge` scheduling facts needed before the O4z no-op decision; it does not replace the whole historical `version_129` no-DWARF path audit above.

| Anchor | Current fact | Source / proof surface |
| --- | --- | --- |
| Binaryen `version_130` registration | `pass.cpp` still registers public `ssa-nomerge` through `createSSAifyNoMergePass`. | [`../raw/binaryen/2026-06-13-ssa-nomerge-version-130-source-refresh.md`](../raw/binaryen/2026-06-13-ssa-nomerge-version-130-source-refresh.md) confirms the registration did not drift from `version_129`; local `wasm-opt --version` reports `wasm-opt version 130 (version_130)`. |
| Binaryen early function-pipeline slot | `addDefaultFunctionOptimizationPasses()` still schedules `ssa-nomerge` when `optimizeLevel >= 3 || shrinkLevel >= 1`, subject to DWARF gating. For `-O4z`, that condition is true before the aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` prelude and before `dce -> remove-unused-names -> remove-unused-brs`. | Same source refresh; it records the official `version_130` `src/passes/pass.cpp` source URL and the local downloaded-file comparison. |
| Starshine public preset expansion | `optimize` and `shrink` both contain an early `ssa-nomerge` slot after `duplicate-function-elimination -> remove-unused-module-elements -> memory-packing -> once-reduction -> global-refining -> global-struct-inference`, then `dead-code-elimination -> remove-unused-names -> remove-unused-brs`. They do not currently add the Binaryen O4z-only `flatten` prelude. | [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt) `optimize_preset_passes` / `shrink_preset_passes`; [`../../../src/passes/registry_test.mbt`](../../../src/passes/registry_test.mbt) `preset expansion stays on implemented active pass names`. |
| Starshine O4z no-op guard | Even when the public preset queue contains `ssa-nomerge`, direct execution is skipped with trace reason `o4z-ssa-nomerge-noop` whenever `descriptor.name == "ssa-nomerge"`, `optimize_level >= 4`, and `shrink_level >= 1`. `-O4z` resolves to a shrink preset with both levels set, so the guard applies. | [`../../../src/passes/pass_manager.mbt`](../../../src/passes/pass_manager.mbt) raw dispatch guard; [`../../../src/passes/ssa_nomerge_test.mbt`](../../../src/passes/ssa_nomerge_test.mbt) `ssa-nomerge skips O4z raw pass until self-opt cli flag parsing is safe`; [`../../../src/cmd/cmd.mbt`](../../../src/cmd/cmd.mbt) `resolve_optimize_levels`. |
| Decision boundary | Removing, narrowing, or retaining the Starshine guard is still `[SSANM-010c]`, not decided by this source refresh. The next evidence slice is `[SSANM-010b]`, which should replay the early `ssa-nomerge -> dead-code-elimination -> remove-unused-names -> remove-unused-brs` neighborhood before asking the user for the top-level scheduling decision. | [`../../../agent-todo.md`](../../../agent-todo.md) `[SSANM-010b]` / `[SSANM-010c]`. |

## 2026-06-14 early-neighborhood replay

`[SSANM-010b]` replayed the Starshine side of the early neighborhood against the checked-in debug-WASI artifact with the prebuilt native `target/native/release/build/cmd/cmd.exe`. The replay is evidence for the local scheduling decision only; it is not a Binaryen semantic-equivalence classification because Starshine fails before a comparable full-neighborhood artifact is available.

| Prefix | Exit / output | Local classification |
| --- | --- | --- |
| `--ssa-nomerge` | Exit `0` in about `4s`; wrote `7,496,071` bytes. | Direct pass still completes on the artifact. |
| `--ssa-nomerge --dead-code-elimination` | Exit `0` in about `5s`; wrote `7,482,974` bytes. | First follow-on cleanup completes and shrinks the artifact by `13,097` bytes. |
| `--ssa-nomerge --dead-code-elimination --remove-unused-names` | Exit `1` in about `5s`; `error: final module validate: stack underflow`, offending `Func 254`. | Validation failure / scheduling blocker. |
| Full requested neighborhood through `--remove-unused-brs --remove-unused-names` | Aborts before producing a comparable artifact. | Keep the O4z no-op guard until `[SSANM-010c]` and a follow-on implementation plan decide otherwise. |

A matching Binaryen sanity pass with `wasm-opt --all-features` validates every prefix: `--ssa-nomerge` (`3,155,990` bytes), `--ssa-nomerge --dce` (`3,154,783` bytes), `--ssa-nomerge --dce --remove-unused-names` (`3,150,555` bytes), `--ssa-nomerge --dce --remove-unused-names --remove-unused-brs` (`3,131,051` bytes), and the repeated `--remove-unused-names` prefix (`3,124,589` bytes).

`[SSANM-010b1]` fixed the named Starshine `Func 254` / extracted `Func 25` stack-underflow blocker. Root cause: raw/HOT `remove-unused-names` demoted no-continue TypeIdx loops to blocks even when the type had entry params; the replacement block could then underflow during lowering. Starshine now preserves TypeIdx / entry-param loops in `remove-unused-names`. Rebuilt-native replay of the three-pass Starshine prefix now exits `0` in about `5s` and writes `7,482,266` bytes, and direct replay of the extracted `func254-before.wasm` validates with `wasm-tools`. This is still not the O4z scheduling decision: `[SSANM-010c]` must stop for user approval before changing the `o4z-ssa-nomerge-noop` policy.

## Nested Rerun Rule

- Top-level order alone is not enough for parity.
- `dae-optimizing` and `inlining-optimizing` both trigger the same post-inlining cleanup helper on changed functions.
- `simplify-globals-optimizing` also reruns the default function pipeline on changed functions, but without prepending `precompute-propagate`.
- A Starshine scheduler that models only the top-level pass list will still miss real Binaryen behavior.

## Current Project Rule

- Keep this pathway as the main orientation page for Binaryen optimize parity.
- Use Binaryen `version_130` as the upstream release baseline for new pass research; the 2026-06-04 release-horizon recheck 0704 supersedes both the temporary 2026-06-02 `version_125` correction and the earlier 2026-06-01 [`version_130` bridge](../raw/binaryen/2026-06-01-binaryen-v130-current-trunk-release-horizon.md), and the older `version_129` path-reading notes remain historical until a dedicated `version_130` reread says otherwise.
- Treat repeated cleanup slots as intentional, not accidental duplication.
- Preserve the phase split, feature gates, and nested reruns before trying to tune performance or collapse preset shape.
- The archived `0066` note remains the historical line-anchored source for older work, but new conclusions should be checked against the current `version_130` release baseline and the release-horizon note first.
- As of the 2026-06-07 behavior-parity inventory, the local workspace `wasm-opt --version` reports `version_130`; older command-based evidence on this page remains tied to the `version_129` or earlier local oracle that produced it until rerun under the refreshed toolchain.
- Earlier command-based evidence tied to `version_125` or `version_129` remains historical until rerun under the current local `version_130` oracle.
- The post-SGO late-tail neighborhood `simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize` is directly oracle-proven for v0.1.0 scheduling purposes: the 10k ordered-neighborhood fuzz lane is green, same-input RUME comparisons are canonical-green on both SGO-side artifact inputs, and the remaining debug-artifact first diff is inherited SGO representation/function-layout drift feeding RUME before the later string/reorder/directize tail changes anything. Public `optimize` and `shrink` now append this accepted suffix; see [`../raw/research/0571-2026-05-19-late-tail-five-pass-neighborhood-baseline.md`](../raw/research/0571-2026-05-19-late-tail-five-pass-neighborhood-baseline.md) and [`../raw/research/0572-2026-05-19-public-preset-late-tail-scheduling.md`](../raw/research/0572-2026-05-19-public-preset-late-tail-scheduling.md).
- `scripts/self-optimize-compare.ts` now runs `moon build --target native --release --package jtenner/starshine/cmd` and invokes the built `_build/native/release/build/cmd/cmd.exe` by default, so recorded Starshine command timings measure the native CLI rather than a `moon run` wrapper unless `--starshine-bin` overrides it.

## Sources

- Archived research doc: [`../raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`](../raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md)
- Superseded 2026-06-01 bridge: [`../raw/binaryen/2026-06-01-binaryen-v130-current-trunk-release-horizon.md`](../raw/binaryen/2026-06-01-binaryen-v130-current-trunk-release-horizon.md)
- Binaryen `version_130` release-horizon recheck: [`../raw/research/0704-2026-06-04-binaryen-v130-release-horizon-recheck.md`](../raw/research/0704-2026-06-04-binaryen-v130-release-horizon-recheck.md)
- Binaryen `version_130` source capture: [`../raw/binaryen/2026-06-04-binaryen-v130-release-horizon-recheck.md`](../raw/binaryen/2026-06-04-binaryen-v130-release-horizon-recheck.md)
- Superseded Binaryen `version_125` correction: [`../raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md`](../raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md)
- Binaryen `version_130` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_130>
- Binaryen official GitHub `main` changelog: <https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md>
- Binaryen `version_129` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen `version_129` preset source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` DWARF gate: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-debug.cpp>
- Binaryen `version_129` nested rerun helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Scheduler surface: [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt)
- Preset coverage: [`../../../src/passes/optimize_test.mbt`](../../../src/passes/optimize_test.mbt)
