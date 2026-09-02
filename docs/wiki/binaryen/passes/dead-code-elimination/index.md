---
kind: entity
status: supported
last_reviewed: 2026-09-02
sources:
  - ../../../raw/research/1648-2026-07-17-dce-batch-writeback-and-shrink-vacuum-attribution.md
  - ../../../../../src/passes/dead_code_elimination.mbt
  - ../../../../../src/passes/dead_code_elimination_test.mbt
  - ../../../../../src/passes/dead_code_elimination_wbtest.mbt
  - ../../../../../src/passes/dead_code_elimination_live_repro_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
  - ../late-pipeline-dispatch.md
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/DeadCodeElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce_vacuum_remove-unused-names.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-eh-legacy.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-stack-switching.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadCodeElimination.cpp
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./typed-control-voidification-and-eh.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../vacuum/index.md
  - ../remove-unused-brs/index.md
  - ../remove-unused-names/index.md
---

# `dead-code-elimination`

## Role

- `dead-code-elimination` is an active implemented **hot pass** in Starshine.
- In upstream Binaryen `version_130`, the public pass name is `dce`.
- `pass.cpp` describes it tersely as:
  - `removes unreachable code`

After a direct source-confirmation follow-up, that short description turns out to be much closer to the truth than the older local dossier was.

## Biggest correction from the follow-up

The older local pages overstated this pass.
They described a much broader engine with helper walkers, effect-driven dead-result analysis, general typed-control voidification, flattening, and refinalization.

A direct reread of `src/passes/DeadCodeElimination.cpp` in Binaryen `version_129` shows the real pass is smaller:

- one function-parallel postwalk,
- centered on `TypeUpdater`,
- trimming dead suffixes after the first unreachable child,
- preserving earlier still-executing children by turning them into `drop`s when needed,
- changing some control nodes' type to `unreachable`,
- and doing one narrow end-of-function EH pop fixup when DCE introduced blocks into a function that contains `pop`.

So the safe beginner summary is now:

- **Binaryen `dce` is an early unreachable-shape cleanup pass, not a generic dead-result optimizer.**

## Why this pass matters

- In the canonical no-DWARF `-O` / `-Os` function pipeline, Binaryen runs it immediately after `ssa-nomerge`:
  - `ssa-nomerge -> dce -> remove-unused-names -> remove-unused-brs -> ...`
- The saved generated-artifact `-O4z` audit observed the same top-level slot at slot `12`.
- The full saved Binaryen debug log contains many `running pass: dce` lines because nested cleanup reruns reach it too.
- `agent-todo.md` still has dedicated `DCE` slices, so this pass remains directly relevant to Starshine work rather than being purely archival.

## What the pass really does

The `version_130` source refresh confirms the previously documented contract:

- if a **non-control** expression becomes unreachable because one child is unreachable,
  - keep the first unreachable child,
  - keep earlier children as `drop`s,
  - remove later children,
  - and materialize a `block` if multiple preserved pieces remain;
- if a `block` contains an unreachable child,
  - trim the dead suffix after that child,
  - maybe collapse the block to the lone `unreachable`,
  - and maybe change the block type to `unreachable` if no `break`s target it;
- if an `if` has an unreachable condition,
  - replace the `if` with the condition;
- if an `if` has both arms unreachable,
  - change its type to `unreachable`;
- if a `loop` body is literally unreachable,
  - replace the loop with the body;
- if `try` or `try_table` can no longer finish normally,
  - change their type to `unreachable`;
- if DCE added blocks in a function containing `pop`,
  - run `EHUtils::handleBlockNestedPops(...)`.

## What the pass does **not** do here

The follow-up matters because the real file does **not** contain:

- `BranchSeeker` / `UnneededBlockSeeker`
- `EffectAnalyzer`
- `canRemove(...)`
- a dedicated `visitDrop(...)` dead-result engine
- a general control-voidification pipeline
- `Flatten::flatten(...)`
- `ReFinalize`
- `TypeUpdater::handleNonDefaultableLocals(...)`

Those older claims were the main documentation gap this follow-up closes.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Source-confirmed algorithm overview for the real `version_129` pass, centered on `TypeUpdater`, control-vs-non-control handling, and narrow EH repair.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Exact owner-file and lit-test map for the pass, including the direct correction of the older over-broad local description.
- [`./typed-control-voidification-and-eh.md`](./typed-control-voidification-and-eh.md)
  - Focused guide to the actual control-type and EH rules the source does implement: type-to-`unreachable` changes, not a generic voidification engine.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog for the real `version_129` rewrite surface.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current Starshine strategy overview and the exact code-map entry point for the HOT rewrite family.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Exact MoonBit code map, raw-skip/writeback guard story, and remaining parity/perf work.

## Freshness note

A 2026-06-28 source/lit refresh confirmed that Binaryen `version_130` retains the previously documented small, `TypeUpdater`-centered DCE shape. The current release-oracle source and dedicated lit roster are cited above; current-main remains a separate drift watch.
A 2026-05-08 refreshed-harness direct revalidation reported `9975 / 10000` compared cases, `0` semantic mismatches, and `25` known Binaryen/tool command failures at seed `0x5eed` in `.tmp/pass-fuzz-dce-refresh-10k`. The ordered prefix through `duplicate-function-elimination -> remove-unused-module-elements -> memory-packing -> once-reduction -> global-refining -> remove-unused-module-elements -> global-struct-inference -> ssa-nomerge -> dead-code-elimination` also stayed green with `9972 / 10000` compared cases, `0` semantic mismatches, and `28` command failures in `.tmp/pass-fuzz-dce-prefix-10k`.

The same date's direct debug-artifact compare first exposed type-index-only canonical-function drift at `defined=201 abs=218`; the compare-tool canonical-function fallback now ignores pretty-printer `type_idx` and local declaration lines regardless of indentation, moving the first real body-shape drift to `defined=208 abs=225` in `.tmp/dce-artifact-direct-typeidx-canon`. That remaining drift is representation-level typed-control printing (`if I32` versus `if (Void)`) on the debug artifact, not a semantic fuzz mismatch. Direct pass-local timing on that run was Starshine `111.752ms` versus Binaryen `114.480ms`; aggregate whole-command timing remains owned by `[WALL]001`.

So the tagged source remains a strong current oracle for this folder, and the active Starshine direct pass plus the ordered DCE prefix are re-proven under the refreshed mixed-generator compare lane.

Research note [`1648`](../../../raw/research/1648-2026-07-17-dce-batch-writeback-and-shrink-vacuum-attribution.md) added current-artifact execution evidence without reopening the behavior audit: DCE now batches changed-function writeback validation, restores internally invalid candidates independently, and falls back to the original per-function path. External validation exposed additional GC/multivalue failures that the internal validator missed, so depth-aware self-target branch fallthrough, a multivalue local-carrier boundary, and unchanged-function writeback preservation were added red-first. The fresh direct artifact was valid and deterministic in `2.847s` / `2.471s`, reached fixed point on the third application, and kept the regular and dedicated count-10000 corpora at their established classifications. Public shrink then advanced past DCE and stalled in the same vacuum raw-preclean owner as public optimize.

## 2026-09-02 artifact-scale performance closure

The 2026-08-28 checkpoint had already removed two superlinear owners: speculative detached-node allocation while searching a shared DAG for unreachable children, and recursive raw fallthrough rescans. That checkpoint moved the canonical command from `11,580.004ms` to `1,915.570ms`, but its `2.583x` ratio against Binaryen v131 left `[P0-WALL-DCE]` open.

The closing slice extends the shared `run_hot_pipeline_instr_scan(...)` traversal with conservative DCE candidate and bounded call-result lifetime facts. The same recursive scan now computes candidate presence, structured-control, branch, drop, nonfallthrough-tail, exact control-target, and lifetime facts. Active target tokens distinguish a loop self-backedge from a branch that escapes the loop: self-backedges may remain candidate-free, while escaping branches still enter HOT. Lifetime analysis is attempted only when a call result is immediately stored and stops after the first proven multi-call hazard. `run_hot_pipeline_dce_can_skip_raw_with_facts(...)` consumes the precomputed structural facts instead of repeating that traversal. Multivalue carriers, result-control tails, stack-polymorphic shapes, load/call/set ownership, call-result lifetimes, loop escapes, typed-control cases, and GC-builder boundaries remain conservatively admitted or fail closed.

On the canonical artifact, `5,901` functions report `no-dce-candidates`, `1,922` report `call-result-multi-call-lifetime-dce-noop`, and `2,265` enter HOT, with `409` changed and `1,856` unchanged. The remaining exact raw reasons include `428` load/call/set guards, `295` loop-outer-branch guards, `256` result-control-tail guards, `8` multivalue-carrier guards, and `904` stack-polymorphic raw cleanups. Final one-warmup/three-pair medians improve:

- no-trace command: `1,915.570ms -> 1,376.976ms` (`1.391x`, `-28.117%`)
- raw admission: `245.478ms -> 81.387ms` (`3.016x`, `-66.846%`)
- HOT lift: `208.253ms -> 151.308ms` (`1.376x`, `-27.344%`)
- pass-local: `188.440ms -> 141.693ms` (`1.330x`, `-24.807%`)
- aggregate function overhead: `407.880ms -> 335.427ms` (`1.216x`, `-17.763%`)
- main pipeline: `930.500ms`

The September 2 paired Binaryen-v131 medians are `681.536ms` command and `189.977ms` pass-local. Starshine therefore measures `2.020x` command time in that host-local set, 13.904ms outside a ratio recomputed from the unusually fast contemporaneous Binaryen median, while remaining 37.024ms below the campaign's declared fixed `<=1.414s` release target. The admitted Starshine pass body runs at `0.746x` Binaryen. All final warmup and measured outputs are byte-identical at 4,968,057 bytes, SHA-256 `933cf8431540576e01b6344e037b8092eb2bd85b6b454883f25723f579d73954`. The final minimal-diff native binary SHA-256 is `925e2f72645efcfe48887635888b1b170d21f213ecc568283b4b106fb3436d7f`.

A reusable native-release benchmark in `src/passes_perf_long/dead_code_elimination_perf_test.mbt` fail-closes by requiring 2,000 branch-free scalar-drop functions to emit 2,000 `no-dce-candidates` traces before measuring the registry path; it reports `1.42ms +/- 8.12us` on x86_64 AMD Ryzen 7 8845HS with MoonBit `0.1.20260713`. Final explicit-Binaryen-v131 comparison is `10000/10000` canonical-equal in the regular lane under `local-cleanup-debris`; `dead-code-elimination-all` reports `8,355` normalized matches plus `1,645` established canonically smaller Starshine-win output shapes, with zero validation, property, generator, or command failures. `[P0-WALL-DCE]` is closed against the fixed target; reopen if the target is redefined from a new oracle median or repeated Starshine medians exceed `1.414s`.

## Current maintenance rule

Keep this folder honest about the main correction:

- Binaryen `dce` is broader than only deleting code after `return`,
- but **much narrower** than the older local story of general effect-based dead-result cleanup.

If future work mentions DCE as a reason for dead `drop` or broad typed-control simplification, re-check the source before attributing that behavior to this pass.
