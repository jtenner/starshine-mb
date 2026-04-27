---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-minify-imports-port-readiness-primary-sources.md
  - ../../../raw/research/0424-2026-04-27-minify-imports-port-readiness.md
  - ../../../raw/binaryen/2026-04-26-minify-imports-current-main-source-correction.md
  - ../../../raw/research/0387-2026-04-26-minify-imports-source-correction.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./env-wasi-json-map-and-module-merge.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../minify-imports-and-exports/starshine-strategy.md
  - ../tracker.md
---

# Starshine strategy for `minify-imports`

## Current local status

Starshine currently has **no `minify-imports` implementation**. This page is a status and future-port map, not a shipped transform description.

Exact local status:

- `src/passes/optimize.mbt:120-137` lists boundary-only names; `minify-imports` is absent.
- `src/passes/optimize.mbt:141-148` lists removed names; `minify-imports` is absent.
- `src/passes/optimize.mbt:479-491` reports absent names as `unknown pass flag ...` and boundary-only names with a distinct error.
- `src/passes/pass_manager.mbt:8661-8685` starts the active module-pass dispatcher; no minification case exists.
- There is no `src/passes/minify_imports.mbt` or shared `minify_imports_and_exports.mbt` owner file.
- `agent-todo.md` has no active slice for this pass.

The current strategy is **non-adoption plus explicit documentation**. The pass is tracked because Binaryen exposes it publicly and because the corrected contract is easy to misread: even plain `minify-imports` mutates import declarations. [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) records the registry/reporting decision and first safe mutating slice if this status changes.

## Exact local code locations to read first

- `src/lib/types.mbt:218`
  - `Import(Name, Name, ExternType)` carries module and base strings.
- `src/lib/types.mbt:227`
  - `Export(Name, ExternIdx)` is out of scope for plain `minify-imports` but needed by the `-and-exports` siblings.
- `src/lib/types.mbt:430`
  - `ImportSec(Array[Import])` is the declaration section a future plain pass would rewrite.
- `src/lib/types.mbt:460`
  - `ExportSec(Array[Export])` is the sibling pass's declaration section.
- `src/binary/decode.mbt:1899-1906`
  - binary import decoding reads module name, base name, then external type.
- `src/binary/encode.mbt:1151-1165`
  - import section and import encoding write module name, base name, then external type.
- `src/wast/lower_to_lib.mbt:2924-3004`
  - WAT imports lower into `@lib.Import::new(module_name, field_name, ...)` across function/table/memory/global/tag imports.
- `src/passes/optimize.mbt:120-148`
  - current compatibility registries omit all minification names.
- `src/passes/optimize.mbt:479-491`
  - unknown-pass and boundary-only error paths today.
- `src/passes/pass_manager.mbt:8661-8685`
  - current module-pass dispatcher landing zone if the pass becomes active.

## Future-port shape

A faithful local port should be treated as a module-declaration rewrite plus reporting pass:

1. **Registry/API decision**
   - decide whether all three minification names remain unknown, become boundary-only, or become active;
   - define how JSON map output is surfaced without mixing it with optimized wasm bytes;
   - use [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) as the detailed validation ladder.
2. **Plain import rewrite**
   - walk `ImportSec` records;
   - select only module `env` and module names beginning `wasi_`;
   - rewrite import base names for all import kinds;
   - preserve module names and export names;
   - rebuild any affected lookup maps.
3. **Name generator parity**
   - port or emulate Binaryen's `Names::MinifiedNameGenerator` for the target revision;
   - preserve Binaryen-compatible collision and ordering behavior.
4. **Sibling expansion**
   - add export-name mutation for `minify-imports-and-exports`;
   - add all-module import-base eligibility and singleton module rewrite for `minify-imports-and-exports-and-modules`.
5. **Validation**
   - compare WAT/binary changes and JSON output against Binaryen on reduced modules;
   - include custom-module negatives, `wasi_` positives, non-function imports, and sibling surfaces.

## Non-goals today

- Do not mark `minify-imports` implemented because Starshine can parse import names.
- Do not preserve the stale non-mutating/imported-function-only contract.
- Do not implement export-name mutation under the plain pass name.
- Do not implement module-name merging under the plain pass name.
- Do not fold this into [`duplicate-import-elimination`](../duplicate-import-elimination/index.md); duplicate import elimination merges equivalent imported functions, while minification changes ABI strings.
- Do not promise Binaryen parity without checking JSON output order and `Names::MinifiedNameGenerator` in the targeted Binaryen revision.
