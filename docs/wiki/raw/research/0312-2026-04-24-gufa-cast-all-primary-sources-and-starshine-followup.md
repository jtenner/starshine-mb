# `gufa-cast-all` primary sources and Starshine follow-up

Date: 2026-04-24
Pass: `gufa-cast-all`
Status: absorbed into living wiki pages

## Why this follow-up exists

The existing `docs/wiki/binaryen/passes/gufa-cast-all/` folder already explained the sibling's high-level contract, but it still relied on the older 2026-04-21 numbered research note and direct online links. It lacked:

1. an immutable raw Binaryen primary-source manifest,
2. a dedicated Starshine status / port-strategy page, and
3. refreshed catalog text that tells future agents the provenance gap is closed.

The immediately preceding `gufa-optimizing` run explicitly left this sibling as the next obvious GUFA-family provenance / Starshine-bridge target.

## Sources reviewed

Primary online sources:

- Binaryen release `version_129`: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- `GUFA.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
- current `main` `GUFA.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GUFA.cpp>
- `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `possible-contents.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
- dedicated lit files:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gufa-cast-all.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>

Local sources:

- `src/passes/optimize.mbt`
- `src/cmd/cmd.mbt`
- `src/passes/pass_manager.mbt`
- `src/lib/types.mbt`
- `src/ir/hot_core.mbt`
- `src/ir/hot_lift.mbt`
- `src/ir/hot_lower.mbt`
- `src/ir/hot_flags.mbt`
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

- Binaryen `gufa-cast-all` is the same shared `GUFA.cpp` engine as plain `gufa`, instantiated with `optimizing = false` and `castAll = true`.
- Its distinctive behavior is a post-refinalize `addNewCasts(func)` walk that inserts fresh `ref.cast` nodes when the oracle knows a narrower castable reference type.
- The cast-all walk is GC-gated, skips uncastable expression types, downgrades exact targets when custom descriptors are unavailable, requires a real subtype improvement, and refinalizes again after insertion.
- It still inherits plain GUFA's first-phase rewrite surface and EH nested-pop repair, but it does not run `gufa-optimizing`'s nested `dce` then `vacuum` cleanup.
- The dedicated `gufa-cast-all.wast` file is the main beginner teaching source because it proves fresh cast insertion, cases where an exact replacement makes a new cast unnecessary, unreachable preservation, and imported/exported tag conservatism.
- Starshine currently tracks the name only as boundary-only. There is no `src/passes/gufa*.mbt` owner file, no pass-manager dispatch case, no module dispatcher, no preset slot, and no active backlog slice.
- Starshine does have reusable cast plumbing (`RefCast`, `RefCastDescEq`, HOT lifting/lowering, typechecking, binary encode/decode, and descriptor-cast WAT parsing), but that is only lower-level infrastructure, not a GUFA-family whole-program oracle or cast-all implementation.

## Wiki updates made from this note

- Added raw source manifest: `docs/wiki/raw/binaryen/2026-04-24-gufa-cast-all-primary-sources.md`.
- Added Starshine status page: `docs/wiki/binaryen/passes/gufa-cast-all/starshine-strategy.md`.
- Refreshed the `gufa-cast-all` living dossier pages so they cite the raw manifest and local status bridge.
- Updated `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/index.md`, `docs/wiki/log.md`, and `CHANGELOG.md`.

## Open follow-up

The broader GUFA family now has raw-manifest and Starshine-status bridges for `gufa-optimizing` and `gufa-cast-all`. Plain `gufa` still has older source-backed coverage but may deserve the same immutable primary-source / Starshine status refresh if a future wiki-health run wants to finish the family uniformly.
