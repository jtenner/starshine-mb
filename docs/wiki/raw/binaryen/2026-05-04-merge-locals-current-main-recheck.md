# Binaryen `merge-locals` current-main recheck

_Capture date:_ 2026-05-04  
_Status:_ immutable source-correction manifest for `docs/wiki/binaryen/passes/merge-locals/`

## Scope

This manifest rechecks the official Binaryen `merge-locals` sources after the living dossier drifted into a stale one-set-local story.
The reviewed `version_129` and current-`main` implementation is the older **copy-shape local.set/local.get balancing** pass, not the later living-page overread that framed it as a generic one-set local-merging / fresh-temp rewrite.

Use the living dossier pages for the maintained explanation:

- `docs/wiki/binaryen/passes/merge-locals/index.md`
- `docs/wiki/binaryen/passes/merge-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/merge-locals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/merge-locals/local-graph-and-copy-influences.md`
- `docs/wiki/binaryen/passes/merge-locals/wat-shapes.md`
- `docs/wiki/binaryen/passes/merge-locals/starshine-strategy.md`

## Official sources consulted

### Release / source anchors

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Re-checked on 2026-05-04.
- `MergeLocals.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeLocals.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- `local-graph.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h>

### Official lit tests

- `merge-locals.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-locals.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-locals.wast>

## Durable source-backed corrections

- The pass still operates on copy-shaped local traffic. In the reviewed current-main source, `visitLocalSet` turns a `local.set` fed by a `local.get` into a recorded candidate plus a synthetic `local.tee` at the source side, so the rewrite starts from a copy edge, not from a one-set-local summary.
- The implementation uses an eager `LocalGraph` snapshot and computes set influences. The reviewed source does **not** use the older living-page story of `computeInfluences()` plus a one-set/local-simple-value merge proof.
- Candidate selection is oriented around the copy pair itself: the pass decides whether influenced gets should be retargeted toward the destination local or the source local, then rechecks that choice against a post-rewrite graph snapshot.
- `invalidatesDWARF() == true` remains part of the reviewed implementation, so local identity changes are explicitly debugger-visible.
- The reviewed `merge-locals.wast` surface is narrow in the current source capture; the visible regression anchor is the conservative `between-unreachable` family rather than the broad source-local / fresh-temp catalog taught by the stale dossier.
- The current-main recheck found no teaching-relevant drift from the `version_129` implementation on the reviewed surfaces.

## Contradictions and supersession

This manifest supersedes the earlier living-dossier overread that framed `merge-locals` as one-set-local merging with optional fresh-temp materialization.
The older raw and research notes remain useful for provenance, but the maintained explanation should follow this copy-shape local-traffic contract instead.

## Consumability rule

Future `merge-locals` updates should cite this manifest together with the living dossier and should not reintroduce the one-set/fresh-temp story unless a future Binaryen source change actually adds that machinery to `MergeLocals.cpp`.
