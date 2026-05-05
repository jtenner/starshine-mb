# 0464 - `local-cse` Starshine port-readiness and validation bridge

Date: 2026-05-05  
Status: completed research ingest  
Pass: `local-cse`  
Local registry status: `removed` in `src/passes/optimize.mbt`  
Related living dossier: `docs/wiki/binaryen/passes/local-cse/`

## Why this follow-up exists

`local-cse` already has the standard upstream strategy, implementation map, and shape catalog pages.
What it still lacked was a dedicated bridge page that turns those sources into a practical Starshine readiness checklist: which local files are the nearest landing zone, what the validation ladder should prove first, and which honest boundaries should stay visible until a real port exists.

## Primary online sources reviewed

- Binaryen GitHub source files on `main` and `version_129`:
  - `src/passes/LocalCSE.cpp`
  - `src/passes/pass.cpp`
  - `src/passes/opt-utils.h`
  - `test/lit/passes/local-cse.wast`
- Existing living dossier pages for `local-cse`
- Current Starshine local sources around the pass registry, local cleanup helpers, local-index rewriting, and replay tests

## Source-backed conclusions

- Upstream `local-cse` is still the same function-parallel, DWARF-invalidating, whole-tree reuse pass on the reviewed surfaces.
- The local status remains removed-registry only; there is still no Starshine implementation file or dispatcher case.
- The nearest local implementation surfaces are not the pass itself but the surrounding cleanup and rewrite machinery:
  - `simplify_locals.mbt` for effect/conflict and local-traffic handling
  - `reorder_locals.mbt` for local-index rewrite and module-pass mechanics
  - `pass_manager_wbtest.mbt` and `cmd_wbtest.mbt` for replay and parity lanes
- The validation ladder should start with reduced shape tests, then move to registry / CLI proof, then pass-targeted fuzz parity, and only then to no-DWARF neighborhood replay once the missing neighbors exist locally.

## Living page updates from this follow-up

Planned or added:

- `docs/wiki/binaryen/passes/local-cse/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/local-cse/index.md`
- `docs/wiki/binaryen/passes/local-cse/starshine-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Supersession note

This note does not change the upstream contract story.
It only adds a practical Starshine port-readiness bridge so the living dossier has a clear next-step validation path.
