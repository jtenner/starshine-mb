# 0304 - `signature-pruning` primary sources and Starshine follow-up

## Scope

- Continue the pass-wiki health campaign after the 2026-04-24 `type-refining` follow-up.
- Re-check `AGENTS.md`, `docs/README.md`, `docs/wiki/`, `docs/wiki/index.md`, `docs/wiki/log.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/raw/research/` before choosing new work.
- Improve one pass that already has useful living coverage but still lacks an immutable raw primary-source manifest and an exact Starshine status / port-strategy page.
- Keep the existing `signature-pruning` dossier non-duplicative by refreshing it instead of creating another near-topic page.

## Candidate selection

I chose `signature-pruning` because:

- it already had the required overview, Binaryen strategy, implementation/test map, focused boundary page, and WAT-shape catalog;
- it still lacked `docs/wiki/raw/binaryen/2026-04-24-signature-pruning-primary-sources.md`;
- it still lacked a dedicated `starshine-strategy.md` page;
- it is already listed in `src/passes/optimize.mbt` as a boundary-only pass name, so a Starshine status bridge is useful even before implementation;
- it sits in the same closed-world GC/type cluster as the recently refreshed `type-refining`, `signature-refining`, and `global-refining` pages;
- it has no active `agent-todo.md` implementation slice, so future readers need one clear page saying that honestly.

## Primary-source ingest

Added `docs/wiki/raw/binaryen/2026-04-24-signature-pruning-primary-sources.md`.

The source manifest records the official Binaryen surfaces reviewed in this run:

- release page and releases index for `version_129` provenance;
- `src/passes/SignaturePruning.cpp`;
- `src/passes/pass.cpp`;
- `src/passes/param-utils.h` and `src/passes/param-utils.cpp`;
- `src/ir/module-utils.h` and `src/ir/module-utils.cpp`;
- `src/ir/type-updating.h`;
- `src/ir/subtypes.h`;
- `src/ir/intrinsics.h` and `src/ir/intrinsics.cpp`;
- `src/ir/possible-constant.h`;
- `src/ir/localize.h`;
- `src/ir/eh-utils.h`;
- `src/cfg/liveness-traversal.h`;
- `test/lit/passes/signature-pruning.wast`;
- matching `main` URLs for the same surfaces used in the narrow drift check.

The durable upstream conclusion is unchanged from the older research note but is now captured in a committed raw manifest:

- Binaryen `signature-pruning` is heap-type-level dead-argument elimination for nominal function signatures;
- it is gated on GC and `--closed-world` and bails out for any table;
- it aggregates direct calls, `call_ref`s, and entry-liveness per function heap type;
- it excludes imported, public, tag-used, continuation-used, JS-called, `call.without.effects`, and subtype-linked families;
- it first applies constant actuals where possible;
- it removes parameters across all functions and users of a heap type;
- it rewrites nominal signatures through `GlobalTypeRewriter::updateSignatures(...)`;
- it can localize blocked call operands and run one extra cycle, but it is not an unbounded fixed point.

The durable source-trust conclusion is intentionally narrow:

- use `version_129` as the normative algorithm oracle for the dossier;
- the 2026-04-24 current-`main` spot check did not find teaching-relevant drift in the reviewed source and test surfaces;
- future drift should be recorded explicitly instead of silently changing the `version_129` story.

## Starshine follow-up

Added `docs/wiki/binaryen/passes/signature-pruning/starshine-strategy.md`.

Current Starshine status recorded there:

- `signature-pruning` is unimplemented;
- no `src/passes/signature_pruning.mbt`, `src/passes/signature-pruning.mbt`, or equivalent owner file exists today;
- `src/passes/optimize.mbt` keeps `signature-pruning` in `pass_registry_boundary_only_names()`;
- `run_hot_pipeline_expand_passes(...)` rejects boundary-only requests with an explicit not-implemented diagnostic;
- the active `optimize` / `shrink` presets contain only implemented module/HOT passes and do not include `signature-pruning`;
- `src/passes/registry_test.mbt` locks that active-preset rule by requiring preset expansions to resolve only to active categories;
- `agent-todo.md` has no dedicated `signature-pruning` slice today.

Future-port surfaces recorded there:

- `src/lib/types.mbt` owns `TypeIdx`, `FuncIdx`, `FuncType`, `TypeSec`, `FuncSec`, `Call`, `CallRef`, `ReturnCallRef`, and `RefFunc` representation;
- `src/wast/parser.mbt` and `src/wast/lower_to_lib.mbt` own text fixtures for type uses and return-call-ref, while direct `call_ref` WAST lowering still deserves confirmation before relying on text-only fixtures;
- `src/validate/env.mbt` resolves function types and function type indices;
- `src/validate/typecheck.mbt` validates direct calls, indirect calls, `call_ref`, and return-call-ref against the resolved type surface;
- `src/binary/decode.mbt` and `src/binary/encode.mbt` round-trip `call_ref` / `return_call_ref` type immediates;
- the existing module passes are useful ownership examples, but no current module pass provides a reusable heap-type-level signature rewrite engine.

## Dossier updates

Refreshed the existing `signature-pruning` living pages so the dossier now points at the new raw manifest and Starshine status page:

- `docs/wiki/binaryen/passes/signature-pruning/index.md`
- `docs/wiki/binaryen/passes/signature-pruning/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/signature-pruning/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/signature-pruning/constant-actuals-localization-and-boundaries.md`
- `docs/wiki/binaryen/passes/signature-pruning/wat-shapes.md`
- `docs/wiki/binaryen/passes/signature-pruning/starshine-strategy.md`

## Health notes

- Updated `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/index.md`, and `docs/wiki/log.md` so the new manifest and Starshine page are discoverable from the pass catalog.
- Updated `CHANGELOG.md` with the docs entry required by repo commit policy.
- Health check while touching the folder fixed the main stale-reference issue in place: the dossier no longer relies only on the older 0151 research note for primary-source provenance and no longer leaves the Starshine side as a one-line boundary-only claim in the landing page.
- Remaining uncertainty: a future implementation still needs a design decision about the local owner shape for heap-type-level signature rewrites. The current docs intentionally describe this as module/type-graph work rather than pretending a HOT expression pass can own it.
