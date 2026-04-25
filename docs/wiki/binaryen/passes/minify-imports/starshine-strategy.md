---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-minify-imports-family-source-correction.md
  - ../../../raw/research/0343-2026-04-25-minify-imports-source-correction.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../minify-imports-and-exports/starshine-strategy.md
  - ../tracker.md
---

# Starshine strategy for `minify-imports`

## Current local status

Starshine currently has **no `minify-imports` implementation**.
This page is a status and future-port map, not a shipped transform description.

Exact local status:

- `src/passes/optimize.mbt` has no `minify-imports` entry in the active registry.
- `src/passes/optimize.mbt` has no boundary-only or removed compatibility entry for `minify-imports`.
- `run_hot_pipeline_expand_passes(...)` reports absent names as `unknown pass flag ...`.
- `src/passes/pass_manager.mbt` has no module-dispatcher case for `minify-imports`.
- There is no `src/passes/minify_imports.mbt` owner file.
- `agent-todo.md` has no active slice for this pass.

The current strategy is **non-adoption plus explicit documentation**.
The pass is tracked because Binaryen exposes it publicly and because its non-mutating map-emission contract is easy to confuse with the mutating import/export minification family.

## Exact local code locations to read first

- `src/passes/optimize.mbt:115-126`
  - boundary-only registry names; `minify-imports` is absent.
- `src/passes/optimize.mbt:129-141`
  - removed registry names; `minify-imports` is absent.
- `src/passes/optimize.mbt:144-267`
  - active hot/module/preset registry construction; no minify pass entry exists.
- `src/passes/optimize.mbt:446-489`
  - request expansion and unknown-name rejection.
- `src/passes/pass_manager.mbt:8628-8649`
  - active module-pass dispatcher; no minify case exists.
- `src/lib/types.mbt:218-227`
  - `Import(Name, Name, ExternType)` holds module/base strings that a related mutating pass would inspect, while `Export(Name, ExternIdx)` is out of scope for `minify-imports`.
- `src/lib/types.mbt:350-424`
  - `Module` owns optional `import_sec` and `export_sec` fields.
- `src/binary/decode.mbt:1899-1906`
  - binary import decoding reads module name, base name, then external type.
- `src/binary/encode.mbt:1151-1165`
  - import section and import encoding write module name, base name, then external type.
- `src/wast/lower_to_lib.mbt:2924-3004`
  - WAT imports lower into `@lib.Import::new(module_name, field_name, ...)` across function/table/memory/global/tag imports.

## Why this is not a normal module rewrite

A tempting Starshine port would rebuild `ImportSec` with shorter names.
That would implement part of [`minify-imports-and-exports`](../minify-imports-and-exports/index.md), not `minify-imports`.

For `minify-imports`, the faithful behavior is:

- scan imported functions;
- generate short names;
- emit a map;
- leave the module unchanged.

That shape does not fit the current module-pass API cleanly because `run_hot_pipeline_apply_module_pass(...)` expects a transformed `@lib.Module`, not an auxiliary stdout/report value.

## Future-port shape

A faithful local port would need three layers:

1. **Registry and API layer**
   - decide whether `minify-imports` remains unknown, becomes boundary-only, or becomes an active reporting pass;
   - decide how a reporting pass exposes stdout without corrupting normal optimized wasm output.
2. **Traversal and name generation layer**
   - walk only imported functions;
   - reproduce Binaryen-compatible `Names::MinifiedNameGenerator` behavior;
   - preserve Binaryen output order.
3. **Testing and UX layer**
   - assert no module mutation;
   - assert function-only mapping output;
   - document how users should apply the map to host glue or downstream packaging.

## Non-goals today

- Do not mark `minify-imports` implemented because Starshine can parse import names.
- Do not implement declaration mutation under this pass name.
- Do not include export names or import module names.
- Do not fold the pass into [`duplicate-import-elimination`](../duplicate-import-elimination/index.md); that pass rewrites duplicate imported functions, while `minify-imports` emits a name map.
- Do not promise Binaryen parity without checking stdout order and `Names::MinifiedNameGenerator` in the targeted Binaryen revision.
