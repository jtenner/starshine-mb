---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md
  - ../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./historical-lineage-and-modern-supersession.md
  - ./module-shapes.md
  - ../remove-unused-module-elements/index.md
  - ../remove-unused-non-function-elements/index.md
  - ../remove-unused-types/index.md
  - ../tracker.md
---

# Starshine strategy for `remove-unused`

## Current status

`remove-unused` is a **boundary-only registry name** in Starshine, not an active pass implementation.

The current local strategy is documentation and request hygiene:

- keep the name known so old plans and user requests produce an intentional diagnostic;
- reject active execution before dispatch;
- point current Binaryen-parity work at [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md), not at the ambiguous short alias;
- preserve the historical explanation that the local name most likely points at upstream's old function-only `remove-unused-functions` lineage.

## Exact code locations

### Registry classification

[`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) is the source of truth for local pass classification.

The relevant surfaces are:

- `pass_registry_boundary_only_names()` includes `"remove-unused"` beside `"remove-unused-types"` and `"remove-unused-non-function-elements"`.
- `pass_registry_entries()` appends each boundary-only name as `pass_registry_entry_boundary_only(name)`.
- `run_hot_pipeline_expand_passes(...)` rejects a requested boundary-only name with the error shape:
  - `pass flag <name> is boundary-only and is not implemented in the hot pipeline`

That means a request such as `--remove-unused` is recognized but intentionally not run.

### Dispatcher absence

[`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) contains the active module-pass dispatcher.

Its `run_hot_pipeline_apply_module_pass(...)` cases include the modern implemented replacement-family pass:

- `"remove-unused-module-elements" => rume_run_module_pass(mod_)`

There is no `"remove-unused"` case. Because `remove-unused` is boundary-only, the dispatcher should not be reached for it.

### Modern Starshine implementation to read instead

[`../../../../../src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt) is the implemented modern module-element cleanup pass.

It owns Starshine's current `remove-unused-module-elements` behavior, including multi-kind module liveness and rewrite helpers. That file is the correct local implementation to study for current Binaryen parity. It is **not** evidence that the short historical alias is implemented.

### Tests and planning docs

- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) keeps registry and preset category behavior honest for active, boundary-only, removed, module, and preset names. Future tests should add a focused `remove-unused` boundary-only assertion if this alias becomes easy to regress.
- [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md) still lists `remove-unused` in the Batch 4 boundary-cleanup grouping, which is why the alias remains a documentation concern.
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md) currently has no dedicated `remove-unused` implementation slice. That absence supports the current non-implementation status.

## What Starshine should do for each user intent

| User intent | Correct Starshine answer today |
| --- | --- |
| Run modern Binaryen-equivalent module cleanup | Use active `remove-unused-module-elements`. |
| Understand local `remove-unused` | Read this folder as a legacy-alias and supersession dossier. |
| Port historical upstream function-only behavior literally | First create a new backlog slice and decide whether the public local spelling should be `remove-unused-functions` instead of the ambiguous short name. |
| Remove private GC heap types | Use the separate [`../remove-unused-types/index.md`](../remove-unused-types/index.md) dossier. |
| Keep all defined functions but prune non-function module elements | Use the separate [`../remove-unused-non-function-elements/index.md`](../remove-unused-non-function-elements/index.md) dossier. |

## Future implementation choices

A future Starshine maintainer has three reasonable options. They should choose explicitly rather than letting the short name drift.

### Option 1: keep `remove-unused` as boundary-only

This is the current safest state.

Pros:

- preserves old-name diagnostics;
- avoids pretending the alias is a current Binaryen pass;
- avoids duplicate implementation beside modern RUME.

Cons:

- users must learn that `remove-unused` is historical, not actionable.

### Option 2: remove or rename the alias

If the registry eventually drops old boundary-only names, this dossier should become the migration note.

The replacement guidance should be:

- use `remove-unused-module-elements` for current module-element cleanup;
- use `remove-unused-types` for GC type cleanup;
- do not silently alias `remove-unused` to RUME without documenting the historical mismatch.

### Option 3: implement a literal historical function-only pass

This would be a deliberate compatibility feature, not current Binaryen parity.

A faithful local port would need to:

1. choose an unambiguous public spelling, preferably `remove-unused-functions`;
2. root start, exports, and table-segment functions;
3. follow direct calls only;
4. delete unreachable defined functions;
5. repair all local function-index users and metadata surfaces;
6. validate against modern Starshine module encoding and text/binary roundtrip behavior.

Because Starshine already implements broader RUME, this option should justify why a narrower compatibility pass is useful.

## Invariants and validation for any future port

If Starshine ever implements a literal historical pass, the minimum validation matrix should cover:

- exported function roots;
- start-function roots;
- table / element conservative roots;
- direct-call reachability from rooted functions;
- unreachable private function deletion;
- function-index repair across code, exports, starts, elements, names, and annotations;
- no deletion of globals, memories, tables, tags, data segments, or types except where another explicitly requested pass owns that cleanup;
- no accidental aliasing to current RUME behavior.

The easiest parity oracle for current Binaryen is **not** `version_129`, because the old pass no longer exists there. A compatibility port would need to compare against the historical `remove-unused-functions` source horizon captured in [`../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md`](../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md).

## Main caveat

The local alias relation is an inference, not a proved rename record. No reviewed local source says “`remove-unused` intentionally means historical Binaryen `remove-unused-functions`.” The evidence-backed claim is narrower:

- local Starshine still reserves the short boundary-only name;
- old upstream Binaryen had a similar but more precise function-only pass name;
- modern upstream Binaryen removed that spelling and uses `remove-unused-module-elements` instead;
- therefore this local name should be taught as a legacy-alias / supersession problem until the registry is clarified.

## Sources

- [`../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md`](../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md)
- [`../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md`](../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
