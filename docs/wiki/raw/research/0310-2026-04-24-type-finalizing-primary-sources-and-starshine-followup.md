# `type-finalizing` primary sources and Starshine follow-up

- Date: 2026-04-24
- Pass: `type-finalizing`
- Status: follow-up research note feeding the refreshed living dossier

## Question

Does the existing `type-finalizing` dossier have enough primary-source provenance and a concrete Starshine status/port map for beginner through advanced readers?

## Short answer

No. The 2026-04-21 dossier already explained the main Binaryen contract, but it still relied on an archived research note plus direct online links. It lacked an immutable raw primary-source manifest and a dedicated Starshine strategy page.

This follow-up adds both. It keeps the upstream mechanics unchanged: Binaryen `type-finalizing` is a tiny GC-only module rewrite that finalizes private leaf heap types through `GlobalTypeRewriter`, sharing the same `TypeFinalizing.cpp` engine with upstream `type-unfinalizing` / local `type-un-finalizing`.

## Sources consulted

- Raw manifest: `docs/wiki/raw/binaryen/2026-04-24-type-finalizing-primary-sources.md`
- Official Binaryen `version_129` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Official Binaryen `TypeFinalizing.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeFinalizing.cpp>
- Official Binaryen `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Official Binaryen `type-finalizing.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-finalizing.wast>
- Starshine local registry and request guard: `src/passes/optimize.mbt`
- Starshine registry/preset tests: `src/passes/registry_test.mbt`
- Starshine type-section surfaces: `src/lib/types.mbt`, `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, `src/wast/module_wast_tests.mbt`, `src/validate/env.mbt`, `src/validate/typecheck.mbt`, `src/binary/encode.mbt`, `src/binary/decode.mbt`
- Local pass-port map: `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- Current backlog: `agent-todo.md`

## Upstream conclusions preserved

The reviewed Binaryen source still supports the existing core story:

- `type-finalizing` and `type-unfinalizing` are public registered Binaryen pass names.
- Both names share one implementation class in `TypeFinalizing.cpp`.
- The hard pass gate is GC support, not closed-world mode.
- The candidate set begins from `ModuleUtils::getPrivateHeapTypes(...)`.
- Finalizing mode constructs `SubTypes` and only modifies private types with no immediate subtypes.
- Unfinalizing mode reopens private types without the leaf proof.
- The only pass-local mutation is `TypeBuilder::setOpen(!finalize)` inside a `GlobalTypeRewriter` subclass.
- The dedicated lit file proves the public/private split, private leaf finalization, private reopening, non-leaf parent preservation, function heap-type participation, and coherent local/global type-use repair.

## Starshine status

Current Starshine status is boundary-only:

- `src/passes/optimize.mbt` includes `type-finalizing` in `pass_registry_boundary_only_names()`.
- `run_hot_pipeline_expand_passes(...)` rejects boundary-only names before dispatch with the standard boundary-only error.
- `optimize_preset_passes(...)` and `shrink_preset_passes(...)` do not include `type-finalizing`.
- `src/passes/registry_test.mbt` locks the active preset list to implemented hot/module pass names, but it does not prove a hidden `type-finalizing` implementation.
- No `src/passes/type_finalizing.mbt` or equivalent owner file exists today.
- `agent-todo.md` has no dedicated `type-finalizing` backlog slice.

## Future-port notes

A faithful Starshine port should be planned as module/type-section work rather than as a HOT peephole.

Likely reusable local surfaces include:

- `src/lib/types.mbt` for `TypeIdx`, `SubType`, `CompType`, reference types, and type constructors.
- `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, and `src/wast/module_wast_tests.mbt` for text fixtures involving recursive types, `sub`, `final`, function heap types, globals, locals, and exports.
- `src/validate/env.mbt` and `src/validate/typecheck.mbt` for post-rewrite validation of heap-type references.
- `src/binary/encode.mbt` and `src/binary/decode.mbt` for binary roundtrip of any future open/final type remap.
- Existing module-pass patterns such as `src/passes/duplicate_function_elimination.mbt`, `src/passes/remove_unused_module_elements.mbt`, and `src/passes/reorder_locals.mbt` for registry/dispatcher/testing shape, not for the semantics of type finalization.

## Durable conclusion

The living dossier now has the required chain:

1. immutable primary-source manifest,
2. pass overview,
3. transformed-shape catalog,
4. Binaryen strategy page,
5. Starshine status/port-strategy page with exact local code locations.

Future threads should not treat `type-finalizing` as missing a primary-source capture or Starshine follow-along page. The sibling `type-un-finalizing` still shares the same upstream owner file and can cite this manifest when it receives a similar provenance refresh.
