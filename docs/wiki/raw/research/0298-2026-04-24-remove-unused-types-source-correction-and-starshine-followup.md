# 0298 - `remove-unused-types` source correction and Starshine follow-up

## Scope

- Continue the pass-wiki health campaign on 2026-04-24.
- Pick one pass whose coverage was incomplete, unclear, stale, or missing a direct Starshine strategy bridge.
- Chosen pass: `remove-unused-types`.

## Why this pass was chosen

`remove-unused-types` already had a living dossier from the 0149 research note, but it still had two important gaps:

1. no immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`,
2. no dedicated Starshine strategy/status page.

A fresh primary-source re-read also found a bigger problem: the old dossier over-described the pass file and taught a whole-old-rec-group retention rule that does not match the reviewed `version_129` source.
That made `remove-unused-types` a better target than a pass that only needed routine provenance links.

## Sources consulted

Primary online sources captured in:

- `docs/wiki/raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md`

Local Starshine sources consulted:

- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `src/lib/types.mbt`
- `src/wast/parser.mbt`
- `src/wast/lower_to_lib.mbt`
- `src/wast/module_wast_tests.mbt`
- `src/validate/env.mbt`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- neighboring pass dossiers for `remove-unused-module-elements`, `type-merging`, `minimize-rec-groups`, and `unsubtyping`

## Corrected Binaryen reading

The older 0149 note said `RemoveUnusedTypes.cpp` directly:

- checked `optimizeLevel >= 2`,
- collected public types,
- defined a used-type scanner,
- erased public types from used types,
- copied whole old private rec groups into a new builder,
- passed that builder to `GlobalTypeRewriter`.

That is now superseded.

The reviewed Binaryen `version_129` owner file instead does only this high-level work:

- return on no-GC modules,
- fatally reject open-world execution,
- call `GlobalTypeRewriter(*module).update()`.

The corrected algorithm lives mostly in `type-updating.h`:

- collect used IR heap types and visibility metadata,
- identify public groups,
- derive private predecessor constraints from private supertypes and described-type dependencies,
- sort private survivors deterministically,
- rebuild surviving private types into a fresh private type group,
- preserve public groups as anchors,
- rewrite module-wide type uses.

## Main teaching correction

The new durable teaching rule is:

- public groups are anchors,
- unused private heap types disappear,
- surviving private types are rebuilt around dependency constraints,
- old private rec groups are not automatically preserved whole.

This is materially different from the old whole-rec-group-retention story.
The old 0149 note remains a historical source but is no longer the algorithm authority.

## Starshine status found

Current Starshine status is boundary-only:

- `src/passes/optimize.mbt#L127-L140` includes `remove-unused-types` in `pass_registry_boundary_only_names()`.
- `src/passes/optimize.mbt#L266-L268` creates boundary-only registry entries.
- `src/passes/optimize.mbt#L453-L462` rejects active requests for boundary-only names.
- `src/passes/optimize.mbt#L240-L263` keeps active presets limited to implemented passes, and `src/passes/registry_test.mbt#L121-L158` asserts that preset entries are active `HotPass` or `ModulePass` entries.
- There is no `src/passes/remove_unused_types.mbt` owner file.
- `agent-todo.md` has no dedicated `remove-unused-types` implementation slice.

Reusable local infrastructure exists, but it is not the pass:

- `src/lib/types.mbt#L48-L136` has the heap-type / rec-group data model.
- `src/wast/parser.mbt#L3479-L3481` parses `(rec ...)` module fields.
- `src/wast/lower_to_lib.mbt#L376-L428` lowers WAT type definitions and rec groups.
- `src/wast/module_wast_tests.mbt#L377-L405` tests rec-group roundtrips.
- `src/validate/env.mbt#L134-L217` resolves type indices and rec groups in validation.
- `src/validate/env.mbt#L395-L443` covers descriptor-result helpers that a descriptor-aware type-graph rewrite must preserve.

## Pages created or updated

Created:

- `docs/wiki/raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md`
- `docs/wiki/raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md`
- `docs/wiki/binaryen/passes/remove-unused-types/starshine-strategy.md`

Substantially refreshed:

- `docs/wiki/binaryen/passes/remove-unused-types/index.md`
- `docs/wiki/binaryen/passes/remove-unused-types/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-types/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-unused-types/closed-world-visibility-and-rec-group-rewrite.md`
- `docs/wiki/binaryen/passes/remove-unused-types/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Health-check result

A focused link/provenance check was planned across the touched `remove-unused-types` area after the wiki-development update.
The main health fix folded into the same update was explicit supersession labeling for the older 0149 algorithm reading so readers do not keep following stale whole-old-rec-group or pass-local-scanner claims.

## Follow-up questions

- Should Starshine eventually build a shared closed-world type-graph rewriter for `remove-unused-types`, `type-merging`, `minimize-rec-groups`, and `unsubtyping` instead of landing one-off module passes?
- What API surface should represent closed-world mode locally before boundary-only type-graph passes become active?
- Should registry tests add direct assertions for every boundary-only GC/type name, including `remove-unused-types`, or keep relying on the pass registry list and preset exclusion tests?
