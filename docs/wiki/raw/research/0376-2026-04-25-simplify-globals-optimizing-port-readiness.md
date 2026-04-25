# `simplify-globals-optimizing` port-readiness refresh

_Date:_ 2026-04-25  
_Status:_ absorbed into living wiki pages

## Question

The `simplify-globals-optimizing` dossier already had a landing page, Binaryen strategy, implementation/test map, WAT-shape guide, focused linear-trace guide, and Starshine status page. The remaining gap was practical port readiness: future implementers still had to infer a safe first Starshine slice, which code surfaces to reuse, and which validation ladder proves the optimizing-specific nested rerun without copying neighboring optimizing-pass behavior.

This run asked whether that was worth filing back into the wiki even though the folder already had a supported dossier.

## Sources reviewed

- New raw bridge: `docs/wiki/raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`
- Existing raw manifest: `docs/wiki/raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`
- Existing absorbed research:
  - `docs/wiki/raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md`
  - `docs/wiki/raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md`
- Official Binaryen current-main and `version_129` sources for:
  - `src/passes/SimplifyGlobals.cpp`
  - `src/passes/pass.cpp`
  - `src/pass.h`
- Local Starshine surfaces:
  - `src/passes/optimize.mbt`
  - `src/passes/registry_test.mbt`
  - `src/cmd/fuzz_harness_wbtest.mbt`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `agent-todo.md`
  - neighboring dossiers for `simplify-globals`, `propagate-globals-globally`, `dae-optimizing`, `inlining-optimizing`, `duplicate-import-elimination`, `remove-unused-module-elements`, `string-gathering`, `reorder-globals`, and `directize`

## Findings

- The focused current-main recheck found no teaching-relevant drift from the 2026-04-24 dossier contract.
- The pass remains a shared `SimplifyGlobals.cpp` engine plus the optimizing-specific changed-function rerun hook.
- The best Starshine minimum viable port slice is not “constant globals everywhere.” It should start with module/global fact collection and a small source-backed rewrite set that can maintain the exact touched-function set:
  - startup-only global/offset propagation,
  - dead or same-as-init `global.set` replacement with `drop(value)`,
  - immutable-copy canonicalization only where type equality is safe,
  - runtime constant replacement only along the cheap linear-trace window.
- The first local validation should separate shared global rewrites from the optimizing wrapper:
  - shape tests for the global algorithm,
  - scheduler tests for touched-function tracking and no `precompute-propagate` prefix,
  - oracle comparison for isolated `--simplify-globals-optimizing`,
  - late-tail replay only after neighboring skipped passes no longer hide the result.
- The Starshine strategy page had enough status material but lacked a compact read-along bridge for implementers. A new `starshine-port-readiness-and-validation.md` page is the least duplicative way to capture that bridge.

## Durable wiki updates made

- Added `docs/wiki/raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`.
- Added `docs/wiki/raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md`.
- Added `docs/wiki/binaryen/passes/simplify-globals-optimizing/starshine-port-readiness-and-validation.md`.
- Refreshed the `simplify-globals-optimizing` landing, Binaryen strategy, implementation/test-map, WAT-shape, linear-trace, and Starshine strategy pages so the dossier links the new port-readiness page without duplicating the existing strategy material.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/log.md`, and `CHANGELOG.md`.

## Health-check notes

- Promoted the tracker classification for `simplify-globals-optimizing` from `dossier` to `deep` because the folder now has the same source/shape/status/implementation-readiness depth as neighboring late-pass folders.
- Refreshed the Starshine status page's local line anchors while touching the file; the public name still lives in `pass_registry_boundary_only_names()`, the active request guard still rejects boundary-only names, and the active presets still stop before the late Binaryen post-pass tail.
- Left the pass explicitly unimplemented. The new page is a future-port and validation bridge, not an implementation claim.

## Uncertainties and non-claims

- The final local architecture is still open. The wiki now recommends a safe slice order, but it does not decide whether the implementation lands as a shared plain/optimizing module-pass family first or as a narrower startup/global subset first.
- The current-main source bridge was focused on teaching drift and port-readiness. It did not re-audit every helper header or benchmark the pass.
- No tests were run because this was documentation/source-ingest work only and no MoonBit implementation changed.
