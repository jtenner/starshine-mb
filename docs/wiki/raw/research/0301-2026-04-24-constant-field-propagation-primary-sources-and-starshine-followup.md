# 0301 - `constant-field-propagation` primary sources and Starshine follow-up

## Scope

- Continue the pass-wiki health campaign on 2026-04-24.
- Pick one pass whose coverage was incomplete, unclear, stale, or missing a direct Starshine strategy bridge.
- Chosen pass: `constant-field-propagation` / upstream `cfp`.

## Why this pass was chosen

`constant-field-propagation` already had a living dossier from the 0158 research note, but it still had three important gaps:

1. no immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`,
2. no dedicated Starshine strategy/status page,
3. one stale touched-area claim in the parent implementation page saying no dedicated `cfp-reftest` lit file had been reviewed, while the sibling `constant-field-null-test-folding` dossier already documents the official `cfp-reftest.wast` file.

That made it a better target than a pass that only needed routine provenance links.
The pass is also a useful local bridge because Starshine preserves both local descriptive pass names as boundary-only registry entries:

- `constant-field-propagation` for upstream `cfp`,
- `constant-field-null-test-folding` for upstream `cfp-reftest`.

## Sources consulted

Primary online sources captured in:

- `docs/wiki/raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md`

Local Starshine sources consulted:

- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `src/lib/types.mbt`
- `src/wast/parser.mbt`
- `src/wast/lower_to_lib.mbt`
- `src/validate/env.mbt`
- `src/validate/typecheck.mbt`
- `src/binary/encode.mbt`
- `src/binary/decode.mbt`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- neighboring dossiers for `constant-field-null-test-folding`, `global-type-optimization`, `global-struct-inference`, and `type-refining`

## Binaryen reading retained

The older 0158 note remains broadly correct for the parent pass:

- `ConstantFieldPropagation.cpp` is the shared engine for upstream `cfp` and `cfp-reftest`.
- The pass returns on no-GC modules and fatally rejects open-world execution.
- The engine scans struct field writes/defaults/copies/RMW unknowns, combines per-function facts, propagates through exact/inexact type views and subtype hierarchy, solves copy edges to a fixed point, and rewrites reads.
- The tracked value lattice remains deliberately tiny: none, one literal constant, one immutable global, or unknown.
- Rewrites target reads and must preserve side effects, null traps, packed-field semantics, subtype validity, descriptor result types, and atomic synchronization boundaries.

## Main health correction

The parent `implementation-structure-and-tests.md` previously said there was no reviewed dedicated `cfp-reftest.wast` file.
That is now stale because the sibling `constant-field-null-test-folding` dossier and the 2026-04-24 raw manifest both confirm the official file:

- `test/lit/passes/cfp-reftest.wast`

The corrected teaching rule is:

- use `cfp.wast` as the parent CFP contract surface,
- use `cfp-reftest.wast` as the dedicated sibling-variant proof surface,
- use `gto_and_cfp_in_O.wast` as the compact scheduler-neighborhood proof.

## Starshine status found

Current Starshine status is boundary-only:

- `src/passes/optimize.mbt#L127-L140` includes `constant-field-propagation` and `constant-field-null-test-folding` in `pass_registry_boundary_only_names()`.
- `src/passes/optimize.mbt#L266-L268` creates boundary-only registry entries.
- `src/passes/optimize.mbt#L446-L463` rejects active requests for boundary-only names.
- `src/passes/optimize.mbt#L240-L263` keeps active presets limited to implemented passes, and `src/passes/registry_test.mbt#L121-L158` asserts that preset entries are active `HotPass` or `ModulePass` entries.
- There is no `src/passes/constant_field_propagation.mbt` owner file.
- `agent-todo.md` has no dedicated `constant-field-propagation`, `cfp`, `constant-field-null-test-folding`, or `cfp-reftest` implementation slice.

Reusable local infrastructure exists, but it is not the pass:

- `src/lib/types.mbt#L31-L57` has the heap/ref/value type model.
- `src/lib/types.mbt#L136-L159` has `TypeMetadata`, `SubType`, `RecType`, and `DefType`.
- `src/lib/types.mbt#L733-L761` represents struct creation, struct field reads/writes, descriptor reads, and descriptor tests/casts.
- `src/wast/parser.mbt#L410-L437` parses the WAT-side struct/descriptor instruction variants.
- `src/wast/lower_to_lib.mbt#L2418-L2453` lowers WAT type immediates for those instructions to library instructions.
- `src/validate/env.mbt#L150-L181` resolves type/heap/subtype facts.
- `src/validate/env.mbt#L246-L272` populates validation environments from rec groups.
- `src/validate/env.mbt#L395-L435` encodes descriptor-result rules.
- `src/validate/typecheck.mbt#L1868-L1930` validates `ref.get_desc`, `ref.test`, casts, and descriptor compatibility.
- `src/validate/typecheck.mbt#L2115-L2178` validates struct field reads/writes and packed-field read forms.
- `src/validate/typecheck.mbt#L3277-L3290` dispatches those instruction validators.
- `src/binary/encode.mbt#L2629-L2659` encodes the GC struct-field read family.

## Pages created or updated

Created:

- `docs/wiki/raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md`
- `docs/wiki/raw/research/0301-2026-04-24-constant-field-propagation-primary-sources-and-starshine-followup.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/starshine-strategy.md`

Substantially refreshed:

- `docs/wiki/binaryen/passes/constant-field-propagation/index.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/copies-subtypes-ref-tests-and-atomics.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/wat-shapes.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Health-check result

The main touched-area health fix folded into this update was the stale parent-CFP test-surface note.
The corrected pages now cite the committed raw manifest and sibling strategy/status page instead of relying only on older numbered research notes.

## Follow-up questions

- Should Starshine eventually build a shared closed-world struct-field fact engine for `constant-field-propagation`, `constant-field-null-test-folding`, `type-refining`, `global-type-optimization`, and `global-struct-inference` instead of landing one-off module passes?
- What API surface should represent closed-world mode locally before boundary-only GC/type passes become active?
- Should registry tests add direct assertions for every boundary-only GC/type name, including both CFP-family local names, or keep relying on the pass registry list and preset exclusion tests?
