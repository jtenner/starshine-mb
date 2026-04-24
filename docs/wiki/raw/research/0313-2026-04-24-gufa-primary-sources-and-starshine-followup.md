# `gufa` primary sources and Starshine follow-up

Date: 2026-04-24
Pass: `gufa`
Status: absorbed into living wiki pages

## Why this follow-up exists

The existing `docs/wiki/binaryen/passes/gufa/` folder already explained the plain pass and the wider GUFA family, but it still relied on the older 2026-04-21 numbered research note and direct online links. The two public siblings, `gufa-optimizing` and `gufa-cast-all`, had already been refreshed with raw primary-source manifests and dedicated Starshine status pages. Plain `gufa` was therefore the remaining family member with a provenance and local-follow-along gap.

This follow-up closes that gap without creating a duplicate pass dossier.

## Sources reviewed

Primary online sources:

- Binaryen release `version_129`: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- `GUFA.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
- current `main` `GUFA.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GUFA.cpp>
- `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `possible-contents.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
- dedicated lit files:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>

Local sources:

- `src/passes/optimize.mbt`
- `src/cmd/cmd.mbt`
- `src/passes/pass_manager.mbt`
- `src/lib/types.mbt`
- `src/ir/hot_core.mbt`
- `src/ir/hot_lift.mbt`
- `src/ir/hot_lower.mbt`
- `src/ir/hot_flags.mbt`
- `src/ir/effects.mbt`
- `src/validate/typecheck.mbt`
- `src/binary/encode.mbt`
- `src/binary/decode.mbt`
- `src/wast/parser.mbt`
- `src/wast/lower_to_lib.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `agent-todo.md`

## Durable findings

- Binaryen plain `gufa` is the shared `GUFA.cpp` engine instantiated with `optimizing = false` and `castAll = false`.
- Its distinctive contract is not “be less aggressive than the siblings” in the abstract; it is the base whole-program `ContentOracle` rewrite pass without the sibling post-rewrite obligations.
- Plain GUFA builds the module-wide oracle, rewrites materializable single-value and impossible sites, simplifies `ref.eq` / `ref.test`, narrows existing `ref.cast`, refinalizes changed functions, and repairs EH nested pops.
- Plain GUFA intentionally does not run the changed-function `dce` + `vacuum` cleanup owned by `gufa-optimizing` and does not insert fresh casts owned by `gufa-cast-all`.
- The raw source review confirms the main local planning point: Starshine currently tracks the name only as boundary-only. There is no `src/passes/gufa*.mbt` owner file, no pass-manager dispatch case, no module dispatcher, no preset slot, and no active backlog slice.
- Starshine has reusable low-level instruction and type infrastructure (`RefEq`, `RefTest`, `RefCast`, `RefFunc`, `GlobalGet`, `Unreachable`, HOT lifting/lowering, typechecking, binary encode/decode, and WAT parsing), but it does not yet have a whole-program contents oracle or a GUFA family rewrite owner.

## Wiki updates made from this note

- Added raw source manifest: `docs/wiki/raw/binaryen/2026-04-24-gufa-primary-sources.md`.
- Added Starshine status page: `docs/wiki/binaryen/passes/gufa/starshine-strategy.md`.
- Refreshed the `gufa` living dossier pages so they cite the raw manifest and local status bridge.
- Updated `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/index.md`, `docs/wiki/log.md`, and `CHANGELOG.md`.

## Open follow-up

The GUFA family now has provenance and Starshine-status bridges for plain `gufa`, `gufa-optimizing`, and `gufa-cast-all`. The next useful health pass should be a family-level link/terminology check rather than another duplicate source ingest unless upstream Binaryen changes the shared `GUFA.cpp` or `possible-contents.h` contract.
