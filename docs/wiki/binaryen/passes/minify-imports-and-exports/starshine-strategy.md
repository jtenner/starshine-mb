---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-minify-imports-and-exports-primary-sources.md
  - ../../../raw/research/0342-2026-04-25-minify-imports-and-exports-source-dossier.md
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
  - ../duplicate-import-elimination/index.md
  - ../tracker.md
---

# Starshine strategy for `minify-imports-and-exports`

## Current local status

Starshine currently has **no `minify-imports-and-exports` implementation**.
This page is a status and future-port map, not a shipped transform description.

Exact local status:

- `src/passes/optimize.mbt` has no `minify-imports-and-exports` or `minify-imports-and-exports-and-modules` entry in the active registry.
- `src/passes/optimize.mbt` has no boundary-only or removed compatibility entry for either name.
- `run_hot_pipeline_expand_passes(...)` reports absent names as `unknown pass flag ...`.
- `src/passes/pass_manager.mbt` has no module-dispatcher case for either name.
- There is no `src/passes/minify_imports_and_exports.mbt` owner file.
- `agent-todo.md` has no active slice for this pass family.

So Starshine's present strategy is **non-adoption plus documentation**.
The folder tracks Binaryen's public pass because the upstream source is compact, ABI-visible, and easy to confuse with harmless internal minification.

## Exact local code locations to read first

- `src/passes/optimize.mbt:96-126`
  - boundary-only registry names; both minify pass names are absent.
- `src/passes/optimize.mbt:129-141`
  - removed registry names; both minify pass names are absent.
- `src/passes/optimize.mbt:144-267`
  - active hot/module/preset registry construction; no minify pass entry exists.
- `src/passes/optimize.mbt:446-489`
  - request expansion and unknown-name rejection.
- `src/passes/pass_manager.mbt:8628-8649`
  - active module-pass dispatcher; no minify case exists.
- `src/lib/types.mbt:218-227`
  - `Import(Name, Name, ExternType)` and `Export(Name, ExternIdx)` hold the strings this pass would rewrite.
- `src/lib/types.mbt:350-424`
  - `Module` owns optional `import_sec` and `export_sec` fields.
- `src/lib/types.mbt:8084-8118`
  - `ImportSec::new(...)` and `ExportSec::new(...)` constructors.
- `src/lib/types.mbt:8380-8392`
  - `Import::new(...)` and `Export::new(...)` constructors.
- `src/binary/decode.mbt:1899-1906`
  - binary import decoding reads module name, base name, then external type.
- `src/binary/decode.mbt:2109-2112`
  - import section decode wraps imports in `ImportSec`.
- `src/binary/encode.mbt:1151-1165`
  - import section and import encoding write module name, base name, then external type.
- `src/binary/encode.mbt:1351-1361`
  - export section and export encoding write export name then target index.
- `src/binary/encode.mbt:1653-1743`
  - module encoding writes import and export sections in the canonical section sequence.
- `src/wast/lower_to_lib.mbt:2924-3004`
  - WAT imports lower into `@lib.Import::new(module_name, field_name, ...)`.
- `src/wast/lower_to_lib.mbt:3316`
  - WAT exports lower into `@lib.Export::new(...)`.
- `src/wast/lower_to_lib.mbt:3498-3521`
  - lowered modules attach `ImportSec` and `ExportSec` when present.

## Why this is a module pass, not HOT work

The transform changes module declarations:

- import section names;
- export section names;
- optionally import module names.

HOT IR function bodies are not enough because the strings live outside lifted function regions.
A faithful Starshine port should therefore be a module pass that rewrites `ImportSec` and `ExportSec` after computing a Binaryen-compatible name map.

## Future-port shape

A faithful local port would need three layers:

1. **Registry/status layer**
   - decide whether to add active module passes, boundary-only names, removed names, or keep unknown-pass behavior;
   - add registry tests for both the plain and sibling names.
2. **Name-map layer**
   - reproduce Binaryen-compatible short-name allocation from `WasmBinaryBuilder::getSymbolMap(...)`;
   - preserve collision and validity behavior;
   - decide how to expose or debug the map, if at all.
3. **Rewrite layer**
   - rebuild `ImportSec` with changed module/base names as appropriate;
   - rebuild `ExportSec` with changed export names;
   - preserve all `ExternType` and `ExternIdx` values exactly;
   - leave code bodies, type declarations, and internal indices untouched.

## Non-goals today

- Do not mark this pass implemented just because Starshine can parse and encode import/export names.
- Do not fold it into [`duplicate-import-elimination`](../duplicate-import-elimination/index.md); that pass merges duplicate function imports, while this pass renames external strings.
- Do not add it silently to `optimize` or `shrink`; changing import/export strings is an ABI choice.
- Do not implement only the sibling and call the plain pass done; the module-name split is part of the public contract.
- Do not promise Binaryen parity without source-reading `WasmBinaryBuilder::getSymbolMap(...)` in the target upstream revision.
