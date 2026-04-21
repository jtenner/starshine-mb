# Binaryen / Starshine `ssa-nomerge` follow-up: local strategy map, raw-source capture, and touched-area alignment

_Date:_ 2026-04-21  
_Status:_ absorbed into the living `docs/wiki/binaryen/passes/ssa-nomerge/` dossier in this same change  
_Related living pages:_
- `docs/wiki/binaryen/passes/ssa-nomerge/index.md`
- `docs/wiki/binaryen/passes/ssa-nomerge/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/ssa-nomerge/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/ssa-nomerge/merge-shapes-and-canonical-slots.md`
- `docs/wiki/binaryen/passes/ssa-nomerge/wat-shapes.md`
- `docs/wiki/binaryen/passes/ssa-nomerge/parity.md`
- `docs/wiki/raw/binaryen/2026-04-21-ssa-nomerge-primary-sources.md`

## Why this follow-up existed

The `ssa-nomerge` folder already had the upstream side covered well enough for Binaryen readers:

- the landing page explained the pass purpose and scheduler role,
- the Binaryen strategy page covered `SSAify.cpp`,
- the merge-policy page covered the core no-merge rule,
- the WAT-shape page covered the main transformed families,
- and the parity page tracked local signoff evidence.

But one practical gap remained for Starshine contributors:

- the folder still lacked the dedicated Starshine strategy/code-map page that the surrounding implemented-pass dossiers now treat as standard.

That omission mattered here more than for some other passes because local `ssa-nomerge` is **not** a close structural port of upstream Binaryen's no-merge mode.
The current MoonBit implementation intentionally leans on in-repo HOT SSA construction/destruction and on a separate raw fallback path, so readers needed one explicit place that said:

- which exact files own the local pass,
- where predecessor-copy insertion really lives,
- how the raw straight-line and structured fallbacks work,
- and which parts differ materially from Binaryen's LocalGraph-only no-merge strategy.

## Process followed

I re-read:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- the existing `docs/wiki/binaryen/passes/ssa-nomerge/` folder
- `src/passes/ssa_nomerge.mbt`
- `src/passes/ssa_nomerge_test.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/ir/ssa_destroy.mbt`
- `src/cmd/cmd_wbtest.mbt`
- `CHANGELOG.md`

I also checked `git status` first.
The worktree was clean aside from branch metadata, so there was no unrelated-local-change blockage.

## Primary online sources reviewed in this follow-up

Official Binaryen sources reviewed or re-verified for this follow-up:

- Binaryen GitHub release page `version_129`
- Binaryen GitHub releases index
- Binaryen `version_129` `src/passes/SSAify.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `src/passes/passes.h`
- Binaryen `version_129` `src/ir/local-graph.h`
- Binaryen `version_129` `src/ir/LocalGraph.cpp`
- Binaryen `version_129` `src/ir/ReFinalize.cpp`
- Binaryen `version_129` `test/passes/ssa-nomerge_enable-simd.wast`
- Binaryen `version_129` `test/passes/ssa-nomerge_enable-simd.txt`
- Binaryen `version_129` `test/lit/passes/ssa.wast`
- Binaryen current `main` versions of the reviewed `SSAify.cpp`, `local-graph.h`, `LocalGraph.cpp`, `ReFinalize.cpp`, and dedicated `ssa-nomerge` test pair

Those exact URLs are now captured in:

- `docs/wiki/raw/binaryen/2026-04-21-ssa-nomerge-primary-sources.md`

### Important uncertainty preserved

The official GitHub releases index visible on **2026-04-21** showed both:

- `version_129` on **2026-01-23**, and
- a newer-by-date page entry for `version_125` on **2026-04-08**.

So this follow-up does **not** claim `version_129` is Binaryen's latest global release.
Instead, the living dossier now keeps the narrower claim:

- `version_129` remains the tagged release surface already used by the existing `ssa-nomerge` dossier, and the exact `ssa-nomerge`-relevant source/test files reviewed from `main` still match it.

That distinction is important because “latest release” and “released oracle tag we actually compared” are not the same statement here.

## Main local code locations captured in the new living page

The new Starshine strategy page now points readers directly to the in-tree owner sites:

- `src/passes/ssa_nomerge.mbt:2`
  - `ssa_nomerge_descriptor()` defines the public pass name and broad invalidation set
- `src/passes/ssa_nomerge.mbt:15`
  - `ssa_nomerge_summary()` owns the registry/help text and already signals the local predecessor-copy story
- `src/passes/ssa_nomerge.mbt:20`
  - `ssa_nomerge_has_local_writes(...)` is the cheap local-write gate
- `src/passes/ssa_nomerge.mbt:34`
  - `ssa_nomerge_needs_rewrite(...)` treats both overlay phis and concrete local-write defs as rewrite-worthy
- `src/passes/ssa_nomerge.mbt:49`
  - `ssa_nomerge_run(...)` requires CFG and local SSA, then calls `@ir.ssa_destroy_into_hot(...)`
- `src/ir/ssa_destroy.mbt:33`
  - `HotSsaDestroyPolicy` currently exposes only `ReusePhiLocals`
- `src/ir/ssa_destroy.mbt:157`
  - `ssa_destroy_build_predecessor_copy_nodes(...)` materializes predecessor `local.get` -> `local.set` copy chains
- `src/ir/ssa_destroy.mbt:455`
  - `ssa_insert_predecessor_copies(...)` inserts those scheduled copies at predecessor-block boundaries
- `src/ir/ssa_destroy.mbt:527`
  - `ssa_destroy_into_hot(...)` is the real local phi-destruction bridge used by the pass
- `src/passes/pass_manager.mbt:6788`
  - `run_hot_pipeline_raw_ssa_nomerge_structured(...)` owns the structured raw fallback
- `src/passes/pass_manager.mbt:6826`
  - `run_hot_pipeline_raw_ssa_nomerge_straight_line(...)` owns the cheap linear raw rewrite path
- `src/passes/pass_manager.mbt:6937`
  - `run_hot_pipeline_raw_ssa_nomerge(...)` chooses between skip, structured rewrite, and straight-line rewrite
- `src/passes/pass_manager.mbt:5768`
  - `run_hot_pipeline_raw_append_local_read(...)` is the raw helper that materializes default local reads and alias rewrites
- `src/passes/pass_manager.mbt:5915`
  - `run_hot_pipeline_raw_initialized_locals(...)` seeds raw default-value knowledge from params plus zero-init locals
- `src/passes/optimize.mbt:158`
  - registry entry wiring for the public pass name
- `src/passes/optimize.mbt:246`
  - optimize preset placement
- `src/passes/optimize.mbt:258`
  - shrink preset placement
- `src/passes/optimize.mbt:379`
  - public optimize preset helper
- `src/passes/optimize.mbt:394`
  - public shrink preset helper
- `src/passes/ssa_nomerge_test.mbt:189`
  - predecessor-copy branch-join coverage
- `src/passes/ssa_nomerge_test.mbt:243`
  - loop-carried local lowering coverage
- `src/passes/ssa_nomerge_test.mbt:304`
  - root-loop-header no-synthetic-entry-copy coverage
- `src/passes/ssa_nomerge_test.mbt:526`
  - result-typed-`if` branch-merge coverage
- `src/cmd/cmd_wbtest.mbt:2394`
  - debug-artifact CLI replay coverage
- `src/cmd/cmd_wbtest.mbt:2434`
  - focused extracted-`Func 523` writeback-type-mismatch retirement check

## Main findings

### 1. The local pass is strategically different from Binaryen's no-merge mode

The most important durable local headline is:

- **Starshine does not implement `ssa-nomerge` by copying Binaryen's LocalGraph no-merge rewrite rules directly.**
- Instead, the main HOT path builds full local SSA, decides whether any rewrite is needed, and then destroys that SSA back into HOT form through predecessor-copy insertion and local-slot assignment.

That means the local pass is best taught as:

- a HOT-SSA roundtrip plus destruction pass,
- with a separate raw fallback when lift/writeback can be skipped,
- not as a direct AST port of Binaryen `SSAify(false)`.

### 2. The local summary string already hints at the true local contract

`ssa_nomerge_summary()` says:

- `Untangle hot locals into semi-SSA form and lower overlay phis through predecessor copies.`

That summary is a much better description of Starshine than of Binaryen.
It matches the real MoonBit implementation:

- overlay phis are part of the local rewrite trigger,
- predecessor copies are inserted explicitly,
- and the pass is willing to materialize merge traffic rather than always leaving merge reads on canonical original slots.

So the wiki now needs to keep a stronger local-vs-upstream split explicit than it did before this follow-up.

### 3. The HOT path is effectively closer to upstream full `ssa` destruction than to upstream `ssa-nomerge`

Because `ssa_nomerge_run(...)` calls `@ir.ssa_destroy_into_hot(...)`, and because `ssa_destroy_into_hot(...)` schedules phi-input copies per predecessor block, the local HOT path can produce the kinds of predecessor-copy rewrites that upstream Binaryen reserves for full `--ssa`.

That is why local tests intentionally cover:

- branch joins through predecessor copies,
- loop-carried copies before the backedge,
- result-typed `if` branch merges,
- and root-loop-header cases where synthetic entry copies must stay suppressed.

So the right teaching is not:

- “Starshine already matches Binaryen's no-merge policy.”

It is:

- “Starshine currently implements a HOT-SSA roundtrip whose destruction step can re-externalize phi traffic through predecessor copies, while the raw fallback tries to preserve a cheaper local alias model on easier shapes.”

### 4. The raw fallback is a second implementation, not just a fast path wrapper

The pass-manager raw path is not merely a gate around the main HOT path.
It has its own behavior split:

- a structured recursive rewrite,
- a straight-line alias rewrite,
- default-local-read materialization,
- local initialization tracking,
- and heuristic caps for branchy structured functions.

That matters for maintenance because Starshine `ssa-nomerge` currently has **two** local strategies that readers need to know about:

1. HOT lift -> local SSA -> SSA destroy back into HOT form
2. raw structural / straight-line rewriting when the pipeline stays below the HOT lift boundary

### 5. The touched parity wording had gone stale

The focused CLI coverage now includes a test named:

- `run_cmd_with_adapter ssa-nomerge extracted func 523 avoids writeback type-mismatch skips`

So the older parity wording that still singled out a surviving `Func 523` `writeback-validate:type mismatch` skip was stale in the touched area.
This follow-up therefore naturally led to a small touched-area health cleanup after the main dossier-completion work.

## Durable conclusions filed back into the living wiki

- `ssa-nomerge` now has the same implemented-pass dossier shape used by the surrounding hot-pass folders, including a dedicated Starshine strategy/code-map page.
- The correct local teaching headline is: **Binaryen `ssa-nomerge` is a LocalGraph no-merge pass, but Starshine `ssa-nomerge` is currently a HOT-SSA roundtrip plus raw-fallback family that may materialize predecessor copies.**
- The local summary string was already closer to the truth than the old dossier shape was.
- The primary-source capture is now explicit and reusable under `docs/wiki/raw/binaryen/`, instead of living only as inline links scattered through the pass folder.
- The touched area should stop claiming that `version_129` is necessarily the latest global Binaryen release; the safer claim is only that it remains the reviewed tagged oracle for the exact `ssa-nomerge` surfaces covered here.

## Files updated in the main dossier-completion change

- `CHANGELOG.md`
- `docs/wiki/raw/binaryen/2026-04-21-ssa-nomerge-primary-sources.md`
- `docs/wiki/raw/research/0240-2026-04-21-ssa-nomerge-starshine-strategy-followup.md`
- `docs/wiki/binaryen/passes/ssa-nomerge/index.md`
- `docs/wiki/binaryen/passes/ssa-nomerge/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Source links

- Binaryen releases index: <https://github.com/WebAssembly/binaryen/releases>
- Binaryen release `version_129`: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen `version_129` `SSAify.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- Binaryen `version_129` `local-graph.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- Binaryen `version_129` `LocalGraph.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/LocalGraph.cpp>
- Binaryen `version_129` `ReFinalize.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp>
- Binaryen `version_129` `ssa-nomerge_enable-simd.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/ssa-nomerge_enable-simd.wast>
- Binaryen `version_129` `ssa-nomerge_enable-simd.txt`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/ssa-nomerge_enable-simd.txt>
- Binaryen `version_129` `ssa.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/ssa.wast>
- Binaryen current `main` `SSAify.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SSAify.cpp>
- Binaryen current `main` `local-graph.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h>
- Binaryen current `main` `LocalGraph.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/LocalGraph.cpp>
- Binaryen current `main` `ReFinalize.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/ReFinalize.cpp>
- Binaryen current `main` `ssa-nomerge_enable-simd.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/ssa-nomerge_enable-simd.wast>
- Binaryen current `main` `ssa-nomerge_enable-simd.txt`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/ssa-nomerge_enable-simd.txt>