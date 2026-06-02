---
kind: concept
status: supported
last_reviewed: 2026-06-02
sources:
  - ../../../raw/binaryen/2026-06-02-remove-unused-version-130-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-06-remove-unused-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-remove-unused-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md
  - ../../../raw/research/0494-2026-05-06-remove-unused-shape-catalog-and-current-main-recheck.md
  - ../../../raw/research/0420-2026-04-27-remove-unused-port-readiness.md
  - ../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md
  - ./index.md
  - ./binaryen-strategy.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/remove_unused_module_elements.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./historical-lineage-and-modern-supersession.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ../remove-unused-module-elements/index.md
  - ../remove-unused-non-function-elements/index.md
  - ../tracker.md
---

# Starshine port readiness and validation for `remove-unused`

## Why this page exists

`remove-unused` is not a normal future-port target. It is a local boundary-only name whose best source-backed meaning is historical upstream `remove-unused-functions`, while modern Binaryen exposes `remove-unused-module-elements` instead.

That makes the first implementation question a naming and migration decision, not code generation.

Use this page when deciding whether to:

1. keep `remove-unused` boundary-only and reject active requests;
2. remove or rename the local alias;
3. implement the old function-only pass literally under a clearer spelling; or
4. intentionally route users to modern [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md).

## Current local status

| Surface | Current state |
| --- | --- |
| Registry | `src/passes/optimize.mbt:127`-`139` lists `remove-unused` in `pass_registry_boundary_only_names()`. |
| Active module entries | `src/passes/optimize.mbt:243`-`249` registers modern `remove-unused-module-elements` and `remove-unused-nonfunction-module-elements`, not `remove-unused`. |
| Dispatcher | `src/passes/pass_manager.mbt:8655`-`8685` has RUME/RUNE cases and no `remove-unused` case. |
| Modern implementation | `src/passes/remove_unused_module_elements.mbt:1`-`8` summarizes the implemented RUME/RUNE module passes. |
| Tests | `src/passes/registry_test.mbt:78`-`82` asserts active RUME category; no active `remove-unused` category exists. |
| Presets | No default preset contains `remove-unused`. |

## Decision tree

### Option A: keep rejecting the alias

This is the safest status quo.

Required validation:

- registry tests should continue proving `remove-unused` is not an active hot or module pass;
- CLI or pipeline tests should produce a clear boundary-only error if a user requests the name;
- docs should point users to modern RUME when they meant current Binaryen cleanup.

This option fits current sources because current Binaryen `main` and `version_130`, including the 2026-06-02 recheck, do not expose the short spelling.

### Option B: remove or rename the alias

This is the cleanest registry-hygiene option if maintainers decide that ambiguous historical aliases should not remain public.

Required validation:

- remove the name from `pass_registry_boundary_only_names()`;
- update any registry tests that enumerate known boundary-only names;
- update `../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md` if it still lists the old Batch 4 name;
- keep this dossier as the migration record, and route current behavior to `remove-unused-module-elements`.

### Option C: implement the historical function-only pass literally

This is only appropriate if the project wants old Binaryen `remove-unused-functions` compatibility.

The pass should be a module pass, not a HOT pass.

First slice should be analyzer-only:

1. root the start function if present;
2. root exported functions;
3. root every function referenced by active table/element initialization;
4. walk direct calls from those roots;
5. report the dead defined-function set without mutation.

Mutation slice should then:

1. delete unreachable defined functions;
2. remap function indices in code, exports, start, element segments, tables, names, and any local function-index metadata; use [`../../../binary/function-import-export-and-code-sections.md`](../../../binary/function-import-export-and-code-sections.md) as the shared `FuncIdx` / `FuncSec` / `CodeSec` checklist;
3. preserve imports or choose a separate imported-function policy explicitly;
4. validate the module after mutation.

Do **not** silently reuse full RUME for this option. Full RUME deletes many non-function declaration kinds and has a broader contract than the old pass.

### Option D: alias to modern RUME intentionally

This should be a deliberate compatibility choice, not an accident.

If maintainers choose this route, document that `remove-unused` is a Starshine-only compatibility spelling for modern `remove-unused-module-elements`, not an upstream Binaryen spelling. Validation should prove the alias and canonical spelling produce the same output on representative RUME fixtures.

## Shape-to-validation checklist

Use [`./module-shapes.md`](./module-shapes.md) for examples. A literal historical implementation needs at least these lanes:

| Shape | Expected result | Why it matters |
| --- | --- | --- |
| Dead private helper with no callers | delete helper | Basic direct-call DCE. |
| Helper reachable from start | keep helper | Start root. |
| Exported helper with no callers | keep helper | Export root. |
| Function named in active element/table segment | keep helper | Conservative indirect-call root. |
| Direct call chain from an exported root | keep whole chain | Reachability closure. |
| Uncalled function type only | no type pruning in this pass | Avoid conflating with `remove-unused-types` or RUME. |
| Dead global/table/memory/data only | no deletion in literal old pass | Avoid conflating with modern RUME. |

## Correctness constraints

A faithful historical implementation must preserve these constraints:

- root every indirectly-callable function that appears in table/element initialization;
- only follow direct call edges after rooting the conservative indirect-call set;
- do not delete non-function module elements;
- do not rewrite function signatures or types as part of this pass;
- keep imported-function behavior explicit rather than inheriting RUME policy by accident;
- run final module validation after any index remap.

## Binaryen oracle lanes

Because current Binaryen no longer exposes `remove-unused-functions`, there is no direct current `wasm-opt --remove-unused` oracle.

Use these instead:

- historical source review for the algorithmic contract;
- current `wasm-opt --remove-unused-module-elements` only as a **negative** comparison showing that modern RUME is broader;
- Starshine local differential tests against hand-written WAT/module fixtures for the literal old function-only behavior;
- if a compatibility alias to RUME is chosen, compare the alias output against local `remove-unused-module-elements`, not against a nonexistent upstream short spelling.

## Open questions

- Should the local registry keep the ambiguous short name at all?
- If retained, should user-facing docs prefer `remove-unused-functions` for a literal historical port?
- Should active requests to `remove-unused` suggest `remove-unused-module-elements` in the error text?
- If a RUME alias is chosen, should the tracker keep this folder under historical lineage or move it to a compatibility-alias page?

## Sources

- [`../../../raw/binaryen/2026-06-02-remove-unused-version-130-current-main-recheck.md`](../../../raw/binaryen/2026-06-02-remove-unused-version-130-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-27-remove-unused-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-remove-unused-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md`](../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md)
- [`../../../raw/research/0420-2026-04-27-remove-unused-port-readiness.md`](../../../raw/research/0420-2026-04-27-remove-unused-port-readiness.md)
- [`../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md`](../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt)
