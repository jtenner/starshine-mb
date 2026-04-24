# `gufa-optimizing` primary sources and Starshine follow-up

Date: 2026-04-24
Pass: `gufa-optimizing`
Status: absorbed into living wiki pages

## Why this follow-up exists

The existing `docs/wiki/binaryen/passes/gufa-optimizing/` folder already explained the sibling's high-level contract, but it still relied on the older 2026-04-21 numbered research note and direct online links. It lacked:

1. an immutable raw Binaryen primary-source manifest,
2. a dedicated Starshine status / port-strategy page, and
3. refreshed catalog text that tells future agents the provenance gap is closed.

## Sources reviewed

Primary online sources:

- Binaryen release `version_129`: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- `GUFA.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
- current `main` `GUFA.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GUFA.cpp>
- `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `possible-contents.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
- dedicated lit files:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>

Local sources:

- `src/passes/optimize.mbt`
- `src/cmd/cmd.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/dead_code_elimination.mbt`
- `src/ir/effects.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `agent-todo.md`

## Durable findings

- Binaryen `gufa-optimizing` is the same `GUFA.cpp` engine as plain `gufa`, instantiated with `optimizing = true` and `castAll = false`.
- Its distinctive behavior is a changed-function nested cleanup list: `dce` then `vacuum`, after refinalization and EH nested-pop repair.
- It does not add the fresh `ref.cast` insertion behavior owned by `gufa-cast-all` and it does not rerun cleanup on unchanged functions.
- The dedicated `gufa-optimizing.wast` file is the main beginner teaching source because it contrasts plain `gufa` residue with the cleaned `gufa-optimizing` output.
- Starshine currently tracks the name only as boundary-only. There is no `src/passes/gufa*.mbt` owner file, no pass-manager dispatch case, no module dispatcher, no preset slot, and no active backlog slice.
- Starshine does have active local `dead-code-elimination` and `vacuum` implementations, but those are not wired as a nested cleanup runner for any GUFA-family pass today.

## Wiki updates made from this note

- Added raw source manifest: `docs/wiki/raw/binaryen/2026-04-24-gufa-optimizing-primary-sources.md`.
- Added Starshine status page: `docs/wiki/binaryen/passes/gufa-optimizing/starshine-strategy.md`.
- Refreshed the `gufa-optimizing` living dossier pages so they cite the raw manifest and local status bridge.
- Updated `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/index.md`, `docs/wiki/log.md`, and `CHANGELOG.md`.

## Open follow-up

The sibling `gufa-cast-all` still has the same kind of provenance / Starshine-status gap that `gufa-optimizing` had before this run. A future wiki-health run should prefer that pass if it remains untouched.
