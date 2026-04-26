---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-remove-unused-types-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md
  - ../../../raw/research/0405-2026-04-26-remove-unused-types-port-readiness.md
  - ../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/module_wast_tests.mbt
  - ../../../../../src/validate/env.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./closed-world-visibility-and-rec-group-rewrite.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../type-merging/index.md
  - ../minimize-rec-groups/index.md
  - ../unsubtyping/index.md
  - ../type-refining/index.md
---

# Starshine Port Readiness And Validation For `remove-unused-types`

This page turns the existing source-correct `remove-unused-types` dossier into an implementation-readiness checklist. The current Starshine status is still **boundary-only and unimplemented**; this page says how to move safely from that state to a faithful module pass when the repo chooses to build shared closed-world type-graph infrastructure.

Use it with:

- [`./binaryen-strategy.md`](./binaryen-strategy.md) for the upstream strategy,
- [`./closed-world-visibility-and-rec-group-rewrite.md`](./closed-world-visibility-and-rec-group-rewrite.md) for the hard type-graph mechanics,
- [`./wat-shapes.md`](./wat-shapes.md) for concrete before/after module shapes,
- [`./starshine-strategy.md`](./starshine-strategy.md) for the exact current local code map.

## Why this needs a bridge page

The corrected Binaryen contract is deceptively small at the pass wrapper:

1. require GC,
2. reject explicit open-world execution,
3. call `GlobalTypeRewriter(*module).update()`.

The real transform is the helper-owned module rewrite: public rec groups anchor the boundary, unused private heap types disappear, surviving private heap types are dependency-sorted and rebuilt into fresh private grouping, and every affected type use in the module is remapped. A Starshine port that starts by walking HOT expressions would miss the pass's actual unit of correctness.

## Current local starting point

Starshine currently has only the boundary shell:

- [`src/passes/optimize.mbt#L127-L140`](../../../../../src/passes/optimize.mbt#L127-L140)
  - `pass_registry_boundary_only_names()` lists `remove-unused-types`.
- [`src/passes/optimize.mbt#L266-L269`](../../../../../src/passes/optimize.mbt#L266-L269)
  - the registry materializes boundary-only entries.
- [`src/passes/optimize.mbt#L453-L464`](../../../../../src/passes/optimize.mbt#L453-L464)
  - active requests fail with the boundary-only diagnostic.
- [`src/passes/optimize.mbt#L240-L263`](../../../../../src/passes/optimize.mbt#L240-L263)
  - the default `optimize` / `shrink` presets omit the pass.

Reusable local surfaces already exist, but no owner file ties them together:

- [`src/lib/types.mbt#L48-L136`](../../../../../src/lib/types.mbt#L48-L136)
  - heap types, reference types, `TypeIdx`, `SubType`, `RecType`, and `DefType` representation.
- [`src/wast/parser.mbt#L3479-L3481`](../../../../../src/wast/parser.mbt#L3479-L3481)
  - WAT `(rec ...)` parser entry point.
- [`src/wast/lower_to_lib.mbt#L376-L428`](../../../../../src/wast/lower_to_lib.mbt#L376-L428)
  - WAT type and rec-group lowering.
- [`src/wast/module_wast_tests.mbt#L377-L405`](../../../../../src/wast/module_wast_tests.mbt#L377-L405)
  - existing rec-group roundtrip proof surface.
- [`src/validate/env.mbt#L134-L217`](../../../../../src/validate/env.mbt#L134-L217)
  - type-index and rec-group validation environment setup.
- [`src/validate/env.mbt#L395-L443`](../../../../../src/validate/env.mbt#L395-L443)
  - descriptor-target and descriptor-result helpers that future descriptor-sensitive tests should keep green.

## Recommended implementation slices

### Slice 0: keep the boundary honest

Before any mutation lands:

- keep `remove-unused-types` boundary-only,
- keep explicit requests rejected,
- keep presets from expanding to it,
- keep the dossier saying there is no owner file.

Exit criteria:

- registry tests still prove boundary-only names are not active preset passes,
- `--pass remove-unused-types` still reports the boundary-only diagnostic,
- this page remains a plan, not an implementation claim.

### Slice 1: no-rewrite analyzer scaffold

Add a module-pass owner only when it can do a no-rewrite analysis pass first. The first scaffold should compute and expose, in tests or debug-only helper assertions:

- whether GC/type-section features are present,
- whether the caller is in an explicitly closed-world mode,
- which rec groups are public anchors,
- which private heap types are used by declarations and code,
- which private dependency edges come from private supertypes,
- which private dependency edges come from descriptor/described links,
- the planned old-to-new mapping if rewriting were enabled.

It should not remove anything yet.

Exit criteria:

- no-GC modules are unchanged,
- open-world invocations are rejected or unscheduled consistently with the chosen Starshine closed-world policy,
- the analyzer output classifies the fixture families from [`./wat-shapes.md`](./wat-shapes.md),
- no WAT/binary output changes occur in this slice.

### Slice 2: one private singleton deletion

The first mutating slice should be intentionally boring:

- closed-world GC module only,
- one unused private singleton rec group,
- no public type group,
- no descriptor/described link,
- no private subtype chain,
- no live use in functions, globals, tables, tags, or elements.

Expected shape:

```wat
;; before
(rec (type $Dead (struct)))
(rec (type $Live (struct)))
(func (result (ref null $Live)) (ref.null $Live))
```

```wat
;; after
(rec (type $Live (struct)))
(func (result (ref null $Live)) (ref.null $Live))
```

Exit criteria:

- the dead private type disappears,
- all surviving `TypeIdx` / heap-type references are remapped,
- validation passes after the rewrite,
- Binaryen oracle comparison uses `wasm-opt --closed-world --remove-unused-types` for the same fixture.

### Slice 3: old-rec-group member removal

This is the slice that protects the 2026-04-24 source correction. Do not preserve whole old private rec groups just because one member is live.

Expected shape:

```wat
;; before
(rec
  (type $Dead (struct))
  (type $Live (struct (field (ref null $Live)))))
(func (result (ref null $Live)) (ref.null $Live))
```

```wat
;; after, schematically
(rec
  (type $Live (struct (field (ref null $Live)))))
(func (result (ref null $Live)) (ref.null $Live))
```

Exit criteria:

- `$Dead` is removed even though it shared an old rec group with `$Live`,
- recursive self-references on `$Live` still resolve,
- names/indices either update correctly or are intentionally dropped with docs and tests,
- the wiki keeps the older whole-old-rec-group explanation marked superseded.

### Slice 4: dependency-retention cases

After singleton and old-group removals work, add dependency-sensitive positives and negatives:

- used private subtype keeps its private supertype dependency,
- used private described type keeps its descriptor dependency,
- descriptor type stays when the described type is live,
- dead private sibling below the same public anchor can still disappear,
- public groups remain anchored even when their current direct code uses are sparse.

Exit criteria:

- private topological constraints are stable and deterministic,
- descriptor/described validation helpers stay green,
- output grouping matches Binaryen closely enough for oracle comparison or records a deliberate, validated representation difference.

### Slice 5: full type-use rewrite surface

Only after the graph rewrite is reliable should the port widen use repair to every module surface:

- function type declarations,
- local and result ref types,
- global/table/tag/element types,
- allocation and cast immediates,
- expression result types cached in IR,
- custom-descriptor typed surfaces,
- binary encoder/decoder roundtrip expectations.

Exit criteria:

- targeted fixtures cover each surface independently,
- mixed fixtures validate after combined remapping,
- pass comparison can run against Binaryen on a closed-world lane,
- no open-world no-DWARF preset starts scheduling the pass accidentally.

## Validation ladder

Use this order when the pass moves from boundary-only to active:

1. `moon info`
2. `moon fmt`
3. focused registry / pass tests for `remove-unused-types`
4. WAT parser/lowering/roundtrip tests for rec groups and type-use remapping
5. validator tests for public/private, subtype, and descriptor constraints
6. `moon test`
7. targeted Binaryen oracle fixtures with `wasm-opt --closed-world --remove-unused-types`
8. only after stable targeted parity, combined closed-world GC/type cluster tests

Do **not** use the current open-world no-DWARF `optimize` / `shrink` presets as the signoff lane. This pass belongs to a closed-world GC/type cluster in Binaryen and is outside the current open-world no-DWARF Starshine route.

## Cross-pass infrastructure warning

A faithful implementation should avoid a one-pass-only rewrite helper. The same core abstractions will also matter for:

- [`../type-merging/index.md`](../type-merging/index.md) - private heap-type identity merging,
- [`../minimize-rec-groups/index.md`](../minimize-rec-groups/index.md) - rec-group repartitioning and ordering,
- [`../unsubtyping/index.md`](../unsubtyping/index.md) - relation removal plus allocation repair,
- [`../type-refining/index.md`](../type-refining/index.md) - declaration and instruction type repair,
- [`../global-type-optimization/index.md`](../global-type-optimization/index.md) - struct layout updates and trap-preserving field rewrites.

The likely reusable pieces are:

- module-wide heap-type use scanning,
- public/private heap-type visibility queries,
- descriptor/described dependency extraction,
- old-to-new `TypeIdx` / `HeapType` mapping,
- rec-group rebuild helpers,
- whole-module type-use rewrite and refinalization hooks,
- oracle fixture normalization for expected Binaryen group/name differences.

## Open questions

- Starshine currently has no explicit closed-world mode flag documented for pass scheduling. The port must choose whether the first active implementation requires a new option, a dedicated closed-world command lane, or a narrower internal test-only hook.
- The local type representation and validator surfaces are present, but there is no `GlobalTypeRewriter`-equivalent owner. That architecture should be decided before Slice 2, not patched in ad hoc.
- The wiki does not yet commit to preserving Binaryen's exact private-group ordering when multiple topological orders are valid. A future port should either match Binaryen or document a validated, deterministic difference.
