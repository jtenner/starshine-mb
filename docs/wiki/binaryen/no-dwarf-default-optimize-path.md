---
kind: concept
status: supported
last_reviewed: 2026-06-02
sources:
  - ../raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md
  - ../raw/research/0571-2026-05-19-late-tail-five-pass-neighborhood-baseline.md
  - ../raw/research/0572-2026-05-19-public-preset-late-tail-scheduling.md
  - ../raw/binaryen/2026-06-02-binaryen-v125-current-trunk-release-horizon.md
  - ../raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md
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
- The public Binaryen release horizon has since advanced to `version_125`; this page's detailed no-DWARF path audit still reflects the original `version_129` source set, so treat the older wording here as a historical baseline rather than newest-tag coverage.

## Canonical Top-Level Shape

- Pre-pass phase:
  `duplicate-function-elimination -> remove-unused-module-elements -> memory-packing -> once-reduction -> global-refining -> remove-unused-module-elements -> gsi`
- Function phase:
  `ssa-nomerge -> dce -> remove-unused-names -> remove-unused-brs -> remove-unused-names -> optimize-instructions -> heap-store-optimization -> pick-load-signs -> precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs -> heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals -> vacuum -> reorder-locals -> coalesce-locals -> reorder-locals -> vacuum -> code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks -> precompute -> optimize-instructions -> heap-store-optimization -> rse -> vacuum`
- Post-pass phase:
  `dae-optimizing -> inlining-optimizing -> duplicate-function-elimination -> duplicate-import-elimination -> simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize`

## Nested Rerun Rule

- Top-level order alone is not enough for parity.
- `dae-optimizing` and `inlining-optimizing` both trigger the same post-inlining cleanup helper on changed functions.
- `simplify-globals-optimizing` also reruns the default function pipeline on changed functions, but without prepending `precompute-propagate`.
- A Starshine scheduler that models only the top-level pass list will still miss real Binaryen behavior.

## Current Project Rule

- Keep this pathway as the main orientation page for Binaryen optimize parity.
- Use Binaryen `version_125` as the upstream release baseline for new pass research; the 2026-06-02 release-horizon correction note 0698 still points here and supersedes the earlier `version_130` bridge, and the older `version_129` path-reading notes remain historical until a dedicated `version_125` reread says otherwise.
- Treat repeated cleanup slots as intentional, not accidental duplication.
- Preserve the phase split, feature gates, and nested reruns before trying to tune performance or collapse preset shape.
- The archived `0066` note remains the historical line-anchored source for older work, but new conclusions should be checked against the current `version_125` release baseline and the release-horizon note first.
- The local workspace `wasm-opt` reports `version_129`, so command-based parity evidence on this page remains tied to that older local oracle until the workspace toolchain is refreshed.
- Earlier command-based evidence tied to `version_125` remains historical until rerun under `version_129`.
- The post-SGO late-tail neighborhood `simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize` is directly oracle-proven for v0.1.0 scheduling purposes: the 10k ordered-neighborhood fuzz lane is green, same-input RUME comparisons are canonical-green on both SGO-side artifact inputs, and the remaining debug-artifact first diff is inherited SGO representation/function-layout drift feeding RUME before the later string/reorder/directize tail changes anything. Public `optimize` and `shrink` now append this accepted suffix; see [`../raw/research/0571-2026-05-19-late-tail-five-pass-neighborhood-baseline.md`](../raw/research/0571-2026-05-19-late-tail-five-pass-neighborhood-baseline.md) and [`../raw/research/0572-2026-05-19-public-preset-late-tail-scheduling.md`](../raw/research/0572-2026-05-19-public-preset-late-tail-scheduling.md).
- `scripts/self-optimize-compare.ts` now runs `moon build --target native --release --package jtenner/starshine/cmd` and invokes the built `_build/native/release/build/cmd/cmd.exe` by default, so recorded Starshine command timings measure the native CLI rather than a `moon run` wrapper unless `--starshine-bin` overrides it.

## Sources

- Archived research doc: [`../raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`](../raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md)
- Binaryen `version_125` release-horizon correction: [`../raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md`](../raw/research/0698-2026-06-02-binaryen-v125-release-horizon-correction.md)
- Binaryen `version_125` release-horizon refresh: [`../raw/binaryen/2026-06-02-binaryen-v125-current-trunk-release-horizon.md`](../raw/binaryen/2026-06-02-binaryen-v125-current-trunk-release-horizon.md)
- Binaryen `version_125` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_125>
- Binaryen official GitHub `main` changelog: <https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md>
- Binaryen `version_129` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen `version_129` preset source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` DWARF gate: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-debug.cpp>
- Binaryen `version_129` nested rerun helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Scheduler surface: [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt)
- Preset coverage: [`../../../src/passes/optimize_test.mbt`](../../../src/passes/optimize_test.mbt)
