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

- A 2026-04-18 web check against non-GitHub primary-ish sources still shows upstream-facing Binaryen surfaces exposing the same command-line names this wiki uses for `global-refining`, `memory-packing`, `once-reduction`, `optimize-instructions`, `precompute`, and `vacuum`.
- The Debian experimental `wasm-opt` manpage for Binaryen `122` still lists `--once-reduction`, `--optimize-instructions`, `--precompute`, `--precompute-propagate`, and `--vacuum`, and describes `--global-refining` as a supported pass as well.
- The current `wasm_opt` Rust bindings remain non-exhaustive and still include `GlobalRefining`, `MemoryPacking`, `OnceReduction`, `OptimizeInstructions`, `Precompute`, `PrecomputePropagate`, and `Vacuum`; they also describe `Dce` as `Removes unreachable code`, which matches this repo's `dead-code-elimination` terminology at the behavioral level.
- Because this maintenance run avoids GitHub by policy, this terminology check should be treated as strongly suggestive rather than a direct source-code audit of Binaryen `main`.

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
