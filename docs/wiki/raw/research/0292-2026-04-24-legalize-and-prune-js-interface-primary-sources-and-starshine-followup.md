# `legalize-and-prune-js-interface` primary sources and Starshine follow-up

- Date: 2026-04-24
- Researcher: OpenAI Codex
- Scope: refresh the existing upstream-only `legalize-and-prune-js-interface` dossier with an immutable raw primary-source manifest and add the missing Starshine status/port-strategy page.

## Why this pass, why now

The folder already had the required overview, Binaryen strategy, transformed-shape catalog, prune matrix, and implementation/test map from the 2026-04-21 tracker expansion.
The remaining durable gaps were:

- no dedicated raw primary-source manifest under `docs/wiki/raw/binaryen/`
- no Starshine status or future-port page for readers trying to follow the local implementation state
- stale `last_reviewed` and source lists that still pointed mostly at the older research note instead of the committed raw-source system

`legalize-and-prune-js-interface` is still worth refreshing because the adjacent `legalize-js-interface` dossier now has a complete primary-source / Starshine bridge, and the prune sibling must stay distinct from both plain JS-boundary `i64` legalization and whole-module `i64-to-i32-lowering`.

## Primary sources consulted

Official Binaryen `version_129` sources:

- `src/passes/LegalizeJSInterface.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/legalize-and-prune-js-interface.wast`
- neighboring plain-family fixtures used only to confirm the inherited first phase:
  - `test/lit/passes/legalize-js-interface-exported-helpers.wast`
  - `test/lit/passes/legalize-js-interface_all-features.wast`

Official current-`main` spot-check sources:

- `src/passes/LegalizeJSInterface.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/legalize-and-prune-js-interface.wast`

Committed manifest created by this run:

- `docs/wiki/raw/binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md`

Local repo context:

- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `src/lib/types.mbt`
- `src/binary/encode.mbt`
- `src/binary/decode.mbt`
- `src/binary/tests.mbt`
- `src/wast/keywords.mbt`
- `src/wast/module_wast.mbt`
- `src/wast/lower_to_lib.mbt`
- `src/wast/module_wast_tests.mbt`
- `agent-todo.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/starshine-strategy.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/index.md`

## Source-backed conclusions

- `legalize-and-prune-js-interface` is a real public Binaryen pass name registered separately from `legalize-js-interface`.
- The implementation is not a separate large pass file. It is the `LegalizeAndPruneJSInterface` subclass inside `LegalizeJSInterface.cpp`.
- The run order is two-phase: first run ordinary `LegalizeJSInterface::run(module)`, then run the prune phase.
- The prune phase is boundary-scoped. It scans imported/exported functions and exported globals, not private internal code.
- The prune legality predicate is broader than plain `i64` legalization: SIMD, multivalue results, exception handling, and stack switching are illegal on the JS boundary after the inherited pass finishes.
- Function imports and exports have different fallbacks: imports become trivial defined functions; exports are removed.
- The trivial import body is result-sensitive: `nop` for no result, zero/default literals for defaultable results, and `unreachable` for nondefaultable results.
- Function pruning is followed by refinalization before global-export pruning because import-to-definition changes can affect `ref.func`-visible exact type facts.
- Global pruning removes only illegal global exports; it does not stub or delete globals.
- A narrow current-`main` spot check did not surface teaching-relevant drift in the owner file, registration surface, or dedicated prune lit file.

## Starshine status conclusion

Current Starshine has no pass-level implementation or registry promise for this sibling:

- `src/passes/optimize.mbt` does not list `legalize-and-prune-js-interface` in active, module, boundary-only, removed, or preset entries.
- The sibling therefore follows the unknown-pass path rather than an explicit boundary-only or removed rejection path.
- There is no `src/passes/legalize_and_prune_js_interface.mbt` owner file.
- `agent-todo.md` has no dedicated slice for this pass.
- Starshine already has the lower-level module/import/export/global/function/type and WAT/binary surfaces a future module pass would mutate, but it has no prune-specific wrapper/stub/export-removal/refinalization algorithm today.

This is stronger than saying merely “not implemented”: the public pass name is currently unknown to the local registry.

## Documentation changes made

- Added `docs/wiki/raw/binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/legalize-and-prune-js-interface/starshine-strategy.md`.
- Refreshed the existing folder pages to cite the new raw manifest and Starshine page.
- Updated the pass folder index, tracker, global wiki index, log, and changelog so the source-to-local-status bridge is discoverable.

## Follow-up risks and open questions

- The current-main check is narrow. It covers the owner file, registration surface, and dedicated lit file only; it is not a whole-Binaryen drift proof.
- A future local implementation must choose whether to add the pass names as boundary-only registry entries before implementing them, or leave them unknown until a real module pass exists.
- A future prune implementation must not be hidden inside whole-module `i64-to-i32-lowering` unless the registry and docs intentionally describe that divergence from Binaryen.
- The hardest local design question is not the import/export data model, which already exists; it is the validation/refinalization analogue after import-to-definition conversion and reference repair.

## Sources

- [`../binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md`](../binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md)
- [`../../binaryen/passes/legalize-and-prune-js-interface/index.md`](../../binaryen/passes/legalize-and-prune-js-interface/index.md)
- [`../../binaryen/passes/legalize-and-prune-js-interface/starshine-strategy.md`](../../binaryen/passes/legalize-and-prune-js-interface/starshine-strategy.md)
- [`../../binaryen/passes/legalize-js-interface/starshine-strategy.md`](../../binaryen/passes/legalize-js-interface/starshine-strategy.md)
- [`../../binaryen/passes/i64-to-i32-lowering/index.md`](../../binaryen/passes/i64-to-i32-lowering/index.md)
- [`../../../../src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt)
- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt)
- [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt)
- [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt)
- [`../../../../src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt)
- [`../../../../agent-todo.md`](../../../../agent-todo.md)
- Binaryen `version_129`:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LegalizeJSInterface.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-and-prune-js-interface.wast>
- Binaryen current `main` spot checks:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LegalizeJSInterface.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/legalize-and-prune-js-interface.wast>
