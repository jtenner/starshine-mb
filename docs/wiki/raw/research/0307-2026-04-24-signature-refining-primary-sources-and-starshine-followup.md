# 0307 - `signature-refining` primary sources and Starshine follow-up

## Scope

- Continue the pass-wiki health campaign after the 2026-04-24 `global-type-optimization` follow-up.
- Re-check `AGENTS.md`, `docs/README.md`, `docs/wiki/`, `docs/wiki/index.md`, `docs/wiki/log.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/raw/research/` before choosing new work.
- Improve one pass that already has useful living coverage but still lacks an immutable raw primary-source manifest and an exact Starshine status / port-strategy page.
- Keep the existing `signature-refining` dossier non-duplicative by refreshing it instead of creating another near-topic page.

## Candidate selection

I chose `signature-refining` because:

- it already had the required overview, Binaryen strategy, implementation/test map, focused boundary page, and WAT-shape catalog;
- it still lacked `docs/wiki/raw/binaryen/2026-04-24-signature-refining-primary-sources.md`;
- it still lacked a dedicated `starshine-strategy.md` page;
- it is already listed in `src/passes/optimize.mbt` as a boundary-only pass name, so a Starshine status bridge is useful even before implementation;
- it sits directly between the recently refreshed `signature-pruning` and `global-refining` dossiers in Binaryen's closed-world GC/type cluster;
- it has no active `agent-todo.md` implementation slice, so future readers need one clear page saying that honestly.

## Primary-source ingest

Added `docs/wiki/raw/binaryen/2026-04-24-signature-refining-primary-sources.md`.

The source manifest records the official Binaryen surfaces reviewed in this run:

- release page and releases index for `version_129` provenance;
- `src/passes/SignatureRefining.cpp`;
- `src/passes/pass.cpp`;
- `src/ir/lubs.h` and `src/ir/lubs.cpp`;
- `src/ir/module-utils.h` and `src/ir/module-utils.cpp`;
- `src/ir/type-updating.h` and `src/ir/type-updating.cpp`;
- `src/ir/subtypes.h`;
- `src/ir/intrinsics.h` and `src/ir/intrinsics.cpp`;
- `test/lit/passes/signature-refining.wast`;
- matching `main` URLs for the same surfaces used in the narrow drift check.

The durable upstream conclusion is unchanged from the older research note but is now captured in a committed raw manifest:

- Binaryen `signature-refining` is heap-type-level subtype tightening for nominal function signatures;
- it is gated on GC and bails out for any table;
- it aggregates direct calls, `call_ref`s, `call.without.effects` extra calls, and returned-value LUBs per function heap type;
- it excludes imported, public, tag-used, and subtype-linked families completely;
- it freezes params only for JS-called and continuation-used families;
- it refines params from actual argument LUBs and results from returned-value LUBs;
- it repairs local bodies through `TypeUpdating::updateParamTypes(...)` before rewriting nominal signatures;
- it repairs refined `call.without.effects` result signatures by cloning intrinsic imports;
- it finishes with `ReFinalize`.

The durable source-trust conclusion is intentionally narrow:

- use `version_129` as the normative algorithm oracle for the dossier;
- the 2026-04-24 current-`main` spot check did not find teaching-relevant drift in the reviewed source and test surfaces;
- future drift should be recorded explicitly instead of silently changing the `version_129` story.

## Starshine follow-up

Added `docs/wiki/binaryen/passes/signature-refining/starshine-strategy.md`.

Current Starshine status recorded there:

- `signature-refining` is unimplemented;
- no `src/passes/signature_refining.mbt`, `src/passes/signature-refining.mbt`, or equivalent owner file exists today;
- `src/passes/optimize.mbt` keeps `signature-refining` in `pass_registry_boundary_only_names()`;
- `run_hot_pipeline_expand_passes(...)` rejects boundary-only requests with an explicit not-implemented diagnostic;
- the active `optimize` / `shrink` presets contain only implemented module/HOT passes and do not include `signature-refining`;
- `src/passes/registry_test.mbt` locks that active-preset rule by requiring preset expansions to resolve only to active categories;
- `agent-todo.md` has no dedicated `signature-refining` slice today.

Future-port surfaces recorded there:

- `src/lib/types.mbt` owns `TypeIdx`, `FuncType`, `SubType`, `TagType`, `FuncSec`, `Call`, `CallRef`, and `ReturnCallRef` representation;
- `src/wast/parser.mbt` and `src/wast/lower_to_lib.mbt` currently expose text lowering for `return_call_ref` and type-use-bearing call forms, while direct `call_ref` text lowering still deserves confirmation before relying on text-only fixtures;
- `src/validate/env.mbt` resolves function types, function type indices, and tag function types;
- `src/validate/typecheck.mbt` validates direct calls, indirect calls, `call_ref`, and `return_call_ref` against resolved type surfaces;
- `src/binary/decode.mbt` and `src/binary/encode.mbt` round-trip `call_ref` / `return_call_ref` type immediates;
- no current module pass provides the shared helper that a faithful port would need for public-heap-type discovery, returned-value LUBs, parameter local repair, nominal signature rewriting, or `call.without.effects` import cloning.

## Dossier updates

Refreshed the existing `signature-refining` living pages so the dossier now points at the new raw manifest and Starshine status page:

- `docs/wiki/binaryen/passes/signature-refining/index.md`
- `docs/wiki/binaryen/passes/signature-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/signature-refining/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/signature-refining/params-results-publicity-and-intrinsics.md`
- `docs/wiki/binaryen/passes/signature-refining/wat-shapes.md`
- `docs/wiki/binaryen/passes/signature-refining/starshine-strategy.md`

## Health notes

- Updated `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/index.md`, and `docs/wiki/log.md` so the new manifest and Starshine page are discoverable from the pass catalog.
- Updated `CHANGELOG.md` with the docs entry required by repo commit policy.
- Health check while touching the folder fixed the main stale-reference issue in place: the dossier no longer relies only on the older 0152 research note for primary-source provenance and no longer leaves the Starshine side as a one-line boundary-only claim in the landing page.
- Remaining uncertainty: a future implementation still needs a design decision about the local owner shape for heap-type-wide param/result LUB analysis and nominal signature rewrites. The current docs intentionally describe this as module/type-graph work rather than pretending a HOT expression pass can own it.
