# `reorder-types` primary sources and Starshine follow-up

- Date: 2026-04-24
- Pass: `reorder-types`
- Status: provenance and local-status follow-up for an existing dossier

## Question

Does the existing `reorder-types` dossier have enough primary-source provenance and a concrete Starshine follow-along map for future implementers?

## Short answer

Not quite before this run. The existing dossier already had the required Binaryen strategy, transformed-shape, implementation/test-map, and cost-model pages, but it still lacked an immutable raw primary-source manifest and a dedicated Starshine status/port-strategy page. That made the dossier harder to audit and left readers to infer the local truth from scattered registry and type-section surfaces.

This follow-up adds the missing source capture and the local status bridge. The core upstream contract remains the one already source-confirmed on 2026-04-21: `reorder-types` is a GC-only, hard-closed-world, private-type layout pass that optimizes encoded type-index size using private-supertype and private-described-type predecessor edges, 21 successor-weight factors, and `GlobalTypeRewriter`'s module-wide remap.

## Sources consulted

- Raw manifest: `docs/wiki/raw/binaryen/2026-04-24-reorder-types-primary-sources.md`
- Official Binaryen `version_129` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Official Binaryen `ReorderTypes.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderTypes.cpp>
- Official Binaryen `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Official Binaryen `type-updating.h` / `type-updating.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>, <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.cpp>
- Official Binaryen `module-utils.h` / `module-utils.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>, <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp>
- Official Binaryen `reorder-types.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-types.wast>
- Starshine registry and dispatch surfaces: `src/passes/optimize.mbt`, `src/passes/pass_manager.mbt`, `src/passes/registry_test.mbt`
- Starshine type-section and type-use surfaces: `src/lib/types.mbt`, `src/wast/lower_to_lib.mbt`, `src/validate/env.mbt`, `src/validate/typecheck.mbt`, `src/binary/encode.mbt`, `src/binary/decode.mbt`
- Starshine pass-port planning surface: `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- Active backlog: `agent-todo.md`

## Upstream source-backed contract to preserve

- Public pass name: `reorder-types`.
- Hidden test pass name: `reorder-types-for-testing`.
- Hard gates: GC feature present and `--closed-world` enabled.
- Candidate pool: private heap types discovered through used-IR heap-type information and visibility analysis.
- Legality edges: private declared supertype before subtype; private described type before descriptor.
- Cost model: 21 successor-weight propagation factors, each topologically sorted and then scored by cumulative encoded type-index byte cost.
- Rewrite engine: `GlobalTypeRewriter` rebuilds reordered private types into one fresh private rec group and remaps the full module type surface.
- Proof surface: `test/lit/passes/reorder-types.wast`, with source files needed for the full public/private, rebuild, and remap contract.

## Starshine status

Current Starshine has no active `reorder-types` implementation:

- `src/passes/optimize.mbt:127-139` lists `reorder-types` in `pass_registry_boundary_only_names()`.
- `src/passes/optimize.mbt:448-466` rejects boundary-only names before execution with the standard boundary-only error.
- `src/passes/pass_manager.mbt:8641-8647` dispatches implemented module passes and has no `reorder-types` case.
- `src/passes/registry_test.mbt:1-90` proves active categories and active preset contents, but does not prove any hidden partial `reorder-types` behavior.
- `src/passes/` contains `reorder_locals.mbt` and `reorder_locals_test.mbt`, but no `reorder_types.mbt` owner file.
- `agent-todo.md` has no dedicated `reorder-types` slice.

## Future-port landing zones

A faithful future port should be planned as a module/type-section pass, not a HOT peephole:

- `src/lib/types.mbt:98-155` already models `TypeIdx`, `RecType`, `SubType`, `TypeMetadata`, and descriptor/describes relationships.
- `src/wast/lower_to_lib.mbt:385-428` lowers subtyping and rec-group source shapes into the local library representation.
- `src/wast/lower_to_lib.mbt:2413-2478` lowers type-indexed struct and descriptor instructions that a type-remap pass would need to update.
- `src/validate/env.mbt:129-285` resolves type indices, rec-stack entries, function types, tags, locals, globals, and tables for validation.
- `src/binary/encode.mbt:607-610` and `src/binary/decode.mbt:186-191` show the binary type-index encoding/decoding surfaces that layout changes ultimately affect.
- `src/cli/cli.mbt:1072-1077` and `src/cmd/cmd.mbt:1667-1705` already carry the `--closed-world` option plumbing that an upstream-faithful implementation would need to honor.

## Durable conclusion

The dossier should now be read as complete for pass-wiki purposes: it has overview, transformed shapes, Binaryen strategy, implementation/test map, cost-model boundary guide, raw primary-source manifest, and Starshine status/port map. The remaining gap is implementation, not documentation: Starshine preserves the public name as boundary-only and lacks the module-wide private-type remap infrastructure needed for a faithful port.
