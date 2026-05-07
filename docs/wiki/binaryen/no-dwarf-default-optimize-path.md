---
kind: concept
status: supported
last_reviewed: 2026-04-11
sources:
  - ../raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md
related:
  - ../../../agent-todo.md
  - ../../../src/passes/optimize.mbt
  - ../../../src/passes/optimize_test.mbt
  - ../../../scripts/self-optimize-compare.ts
  - ../../../scripts/test/self-optimize-compare-command.ts
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
- Use Binaryen `version_129` as the upstream source oracle for new pass research.
- Treat repeated cleanup slots as intentional, not accidental duplication.
- Preserve the phase split, feature gates, and nested reruns before trying to tune performance or collapse preset shape.
- The archived `0066` note remains the historical line-anchored source for older work, but new conclusions should be checked against `version_129` source first.
- The local workspace `wasm-opt` now reports `version_129`, so command-based parity evidence can be rerun under the same upstream oracle.
- Earlier command-based evidence tied to `version_125` remains historical until rerun under `version_129`.
- `scripts/self-optimize-compare.ts` now runs `moon build --target native --release --package jtenner/starshine/cmd` and invokes the built `_build/native/release/build/cmd/cmd.exe` by default, so recorded Starshine command timings measure the native CLI rather than a `moon run` wrapper unless `--starshine-bin` overrides it.

## Sources

- Archived research doc: [`../raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`](../raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md)
- Binaryen `version_129` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen `version_129` preset source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` DWARF gate: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-debug.cpp>
- Binaryen `version_129` nested rerun helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Scheduler surface: [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt)
- Preset coverage: [`../../../src/passes/optimize_test.mbt`](../../../src/passes/optimize_test.mbt)
