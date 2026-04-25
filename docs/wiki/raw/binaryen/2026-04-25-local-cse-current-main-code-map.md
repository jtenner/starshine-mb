# Binaryen `local-cse` current-main source and code-map refresh

_Capture date:_ 2026-04-25  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/local-cse/` dossier

## Scope

This file records the primary online sources and repo-local code-map surfaces consulted while refreshing the `local-cse` dossier on 2026-04-25. It does not replace the older tagged-source manifest at `docs/wiki/raw/binaryen/2026-04-22-local-cse-primary-sources.md`; use that file as the tagged `version_129` provenance anchor and use this file as the current-main freshness bridge plus local follow-along map.

## Official Binaryen sources consulted

### Tagged oracle

- Binaryen `version_129` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- `LocalCSE.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalCSE.cpp>
- `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `opt-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `linear-execution.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- `effects.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `properties.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.cpp>
- `intrinsics.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>
- `cost.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
- Dedicated lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-cse.wast>

### Current-main spot-check sources

- `LocalCSE.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LocalCSE.cpp>
- `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `opt-utils.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- `linear-execution.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/linear-execution.h>
- `effects.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>
- `properties.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/properties.h>
- `properties.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/properties.cpp>
- Dedicated lit test: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/local-cse.wast>

## Durable observations

- The checked current-main sources did not show a teaching-relevant drift from the `version_129` `local-cse` contract already documented in the living dossier.
- `LocalCSE.cpp` remains the owner file for the pass's scan/check/apply structure: candidate whole-tree hashing, equality checks, first-original request tracking, parent-over-child cancellation, effect validation, and final temp-local materialization.
- `pass.cpp` remains the owner for public registration and scheduler placement, including the ordinary late local-cleanup slot and the aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` prelude.
- `opt-utils.h` remains relevant because optimizing passes can rerun the default function-optimization helper, so `local-cse` can appear as a nested cleanup pass rather than only as a top-level pass.
- The helper files remain important for source interpretation: `linear-execution.h` defines the limited window model; `effects.h` defines invalidation and trap reasoning; `properties.*` defines shallow generativity; `intrinsics.h` exposes the idempotent-call carveout; and `cost.h` helps explain profitability thresholds.
- The dedicated `local-cse.wast` file remains the test oracle for the common visible families: arithmetic and load positives, local-set and after-`if` barriers, nested-call negatives, switch-child ordering, and tiny-root no-ops.

## Current Starshine code locations checked

These are repo-local status and future-port surfaces, not an implementation of `local-cse`:

- `src/passes/optimize.mbt:144-151` keeps `local-cse` in `pass_registry_removed_names()`.
- `src/passes/optimize.mbt:455-473` rejects removed pass flags before dispatch.
- `src/passes/pass_manager.mbt:8629-8648` contains the module-pass dispatcher surface and no `local-cse` case.
- `src/passes/simplify_locals.mbt:70` creates sinkable-local state; `src/passes/simplify_locals.mbt:176` checks sinkable/effect conflicts; `src/passes/simplify_locals.mbt:4132` is the active full `simplify-locals` entry surface.
- `src/passes/reorder_locals.mbt:118`, `src/passes/reorder_locals.mbt:183`, and `src/passes/reorder_locals.mbt:544` cover local-use scanning, local-index rewrite, and module-pass entry logic in the nearest local-index rewrite neighbor.
- `agent-todo.md:403-415` keeps the `LCSE` backlog slice and validation expectations.
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:33` keeps the canonical local-cleanup cluster including `local-cse`.

## Contradictions and uncertainty

- No contradiction was found between the checked current-main sources and the `version_129` teaching model. The current dossier should therefore say “no teaching-relevant drift found,” not “the pass changed.”
- The current Starshine code-map remains a port map only. There is no `src/passes/local_cse.mbt`, no dispatcher entry, and no dedicated local transform test today.
- Some source-derived families, especially idempotent-call reuse and GC-generative allocation rejection, are still better supported by owner-file/helper reading than by a dedicated standalone `local-cse.wast` fixture. Keep that evidence-strength distinction visible on the living shape pages.

## Consumability rule

Use this raw source bridge together with:

- `docs/wiki/raw/binaryen/2026-04-22-local-cse-primary-sources.md`
- `docs/wiki/binaryen/passes/local-cse/index.md`
- `docs/wiki/binaryen/passes/local-cse/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/local-cse/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/local-cse/starshine-strategy.md`

Do not treat this file as the narrative destination; it is provenance and freshness metadata for the living pages.
