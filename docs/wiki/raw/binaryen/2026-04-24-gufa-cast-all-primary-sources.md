---
kind: source-capture
status: supported
last_reviewed: 2026-04-24
sources:
  - https://github.com/WebAssembly/binaryen/releases/tag/version_129
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/GUFA.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gufa-cast-all.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast
related:
  - ../research/0190-2026-04-21-gufa-cast-all-binaryen-research.md
  - ../research/0312-2026-04-24-gufa-cast-all-primary-sources-and-starshine-followup.md
  - ../../binaryen/passes/gufa-cast-all/index.md
---

# Binaryen `gufa-cast-all` primary-source capture

Captured: 2026-04-24

## Source set

- Official Binaryen `version_129` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Reviewed release page reports `version_129` as released on **2026-04-01 14:31** and points at commit `d0e2be9`.
- `src/passes/GUFA.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GUFA.cpp>
  - Key reviewed locations: shared GUFA visitor, `visitFunction`, `ReFinalize`, `castAll && addNewCasts(func)`, `EHUtils::handleBlockNestedPops`, the `optimizing` gate, nested `dce` / `vacuum` runner, `addNewCasts`, the GC gate, `isCastable`, `withInexactIfNoCustomDescs`, subtype check, `Builder::makeRefCast`, the second `ReFinalize`, and public factories including `createGUFACastAllPass()`.
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - Key reviewed location: public registration of `gufa`, `gufa-cast-all`, and `gufa-optimizing`; the `gufa-cast-all` description frames it as GUFA plus casts for all inferences.
- `src/ir/possible-contents.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
  - Key reviewed location: `ContentOracle` / `PossibleContents`, the shared whole-program value/type oracle used by all GUFA siblings.
- `test/lit/passes/gufa-cast-all.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gufa-cast-all.wast>
  - Key reviewed locations: `--gufa-cast-all` RUN line, exact-`$B` cast insertion for a struct local, exact function-type cast insertion for a funcref local, value-replacement cases where no extra cast is needed, unreachable-preservation cases, and imported/exported tag cases that keep EH content conservative.
- Neighboring comparison lit files:
  - Plain `gufa`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
  - `gufa-optimizing`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>

## Durable facts captured

- `gufa-cast-all` is a public Binaryen pass name, not a hidden tuning flag.
- It is implemented by the same `GUFA.cpp` engine as plain `gufa`, instantiated as `optimizing = false` and `castAll = true`.
- The shared engine builds a module-wide `ContentOracle` and performs the same first-phase GUFA rewrites as plain `gufa`: impossible-site `unreachable`, materializable single-value replacement, `ref.eq` simplification, `ref.test` simplification, and existing-`ref.cast` refinement.
- The sibling-specific phase runs after the first-phase rewrite and refinalization: `addNewCasts(func)` walks expressions and inserts a fresh `ref.cast` only when the expression type is castable, the oracle type is a reference type, the oracle type differs from the current static type, and the oracle type is a subtype of the current type.
- `addNewCasts` is GC-gated. It also downgrades exact targets through `withInexactIfNoCustomDescs(...)` when custom descriptors are not available.
- If `addNewCasts` changes a function, Binaryen refinalizes that function again, then the outer `visitFunction` repair path runs EH nested-pop handling.
- Because `optimizing = false`, this sibling deliberately does **not** run the nested changed-function `dce` then `vacuum` cleanup that `gufa-optimizing` owns.
- The dedicated lit file proves cast-materialization cases and no-op boundaries; it also preserves imported/exported tag conservatism from the shared `ContentOracle` / EH surface.

## Current-`main` drift note

A 2026-04-24 spot check of `main` on the reviewed owner-file and dedicated `gufa-cast-all.wast` surfaces did not surface teaching-relevant drift from the `version_129` contract captured here. The wiki should continue using `version_129` as the stable source oracle until a later source review finds a material change in one of these surfaces.

## Uncertainty and contradiction notes

- This capture closes a provenance gap in the existing living dossier rather than superseding its core 2026-04-21 mechanics.
- The current-main check was a narrow teaching-surface spot check, not a full semantic diff of every helper in `possible-contents.h`.
- The local Starshine type surface can represent ordinary and descriptor casts, but it does not yet expose a GUFA-style whole-program content oracle or a feature-sensitive exact-cast insertion pass. The Starshine page records that as a future-port prerequisite, not a partial implementation claim.

## Local Starshine status captured with this ingest

- `src/passes/optimize.mbt` lists `gufa-cast-all` in `pass_registry_boundary_only_names()` beside `gufa` and `gufa-optimizing`.
- `src/cmd/cmd.mbt` admits only active hot/module/preset pass flags as command pipeline steps, so a command-line `--gufa-cast-all` request is rejected as an unknown pass flag today.
- `run_hot_pipeline_expand_passes` in `src/passes/optimize.mbt` also rejects boundary-only names with a not-implemented message if a lower-level caller tries to expand them.
- `src/passes/pass_manager.mbt` has no GUFA-family dispatch case and no cast-all phase.
- Starshine does have reusable cast representation and validation surfaces: `src/lib/types.mbt`, `src/ir/hot_core.mbt`, `src/ir/hot_lift.mbt`, `src/ir/hot_lower.mbt`, `src/ir/hot_flags.mbt`, `src/validate/typecheck.mbt`, `src/binary/encode.mbt`, `src/binary/decode.mbt`, and `src/wast/parser.mbt` / `src/wast/lower_to_lib.mbt` for descriptor-cast text forms.
- No dedicated `src/passes/gufa*.mbt` owner file, module dispatcher, active preset slot, or `agent-todo.md` backlog slice was found in the 2026-04-24 local recheck.
