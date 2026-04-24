---
kind: raw-source-capture
status: supported
last_reviewed: 2026-04-24
sources:
  - https://github.com/WebAssembly/binaryen/releases/tag/version_129
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderFunctions.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ReorderFunctions.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-functions-by-name.wast
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/reorder-functions-by-name.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderFunctions.cpp
related:
  - ../../binaryen/passes/reorder-functions-by-name/index.md
  - ../../binaryen/passes/reorder-functions-by-name/binaryen-strategy.md
  - ../../binaryen/passes/reorder-functions-by-name/starshine-strategy.md
  - ../../binaryen/passes/reorder-functions/index.md
  - ../research/0325-2026-04-24-reorder-functions-by-name-primary-sources-and-starshine-followup.md
---

# Binaryen `reorder-functions-by-name` primary sources

## Capture scope

This capture records the official upstream source set used by the living `reorder-functions-by-name` dossier on 2026-04-24.

The pass is tiny, so the durable source set is also tiny:

- official Binaryen `version_129` release page
- `src/passes/ReorderFunctions.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/reorder-functions-by-name.wast`
- current `main` `src/passes/ReorderFunctions.cpp` spot check

## Release anchor

- Binaryen `version_129` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>

Durable takeaway:

- This dossier uses `version_129` as its release oracle. Existing neighboring pass dossiers reviewed the same release page on 2026-04-23 / 2026-04-24 and recorded the GitHub publish date as 2026-04-01.

## Source manifest

### `src/passes/ReorderFunctions.cpp`

- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderFunctions.cpp>
- raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ReorderFunctions.cpp>
- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderFunctions.cpp>

Reviewed source locations:

- `ReorderFunctionsByName` lives at the top of the file.
- Its `run(Module* module)` method performs one module-function-list sort.
- The ordering key is ascending Binaryen internal function name.
- `requiresNonNullableLocalFixups()` returns false for this pass.
- The same file also owns the count-based `ReorderFunctions` sibling, which keeps the public sibling split source-confirmed.

Durable takeaway:

- `reorder-functions-by-name` is declaration-order-only. It does not scan bodies, calls, exports, start sections, element segments, or `ref.func` instructions.

### `src/passes/pass.cpp`

- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>

Reviewed source locations:

- The pass is registered as a separate public pass named `reorder-functions-by-name`.
- The registration text frames the pass as useful for debugging.
- The neighboring `reorder-functions` registration has a different description and calls the count-based sibling.

Durable takeaway:

- The by-name sibling is not an undocumented mode of `reorder-functions`; it is a public pass with its own CLI-visible contract.

### `test/lit/passes/reorder-functions-by-name.wast`

- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-functions-by-name.wast>
- raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/reorder-functions-by-name.wast>

Reviewed proof surface:

- The dedicated lit file invokes `--reorder-functions-by-name`.
- It checks four module declaration permutations of `$a`, `$b`, and `$c`.
- Every checked output normalizes to `$a`, then `$b`, then `$c`.
- Bodies remain simple constants, proving the pass's visible effect is function declaration order, not body rewriting.

Durable takeaway:

- The dedicated lit file directly proves the lexical sort contract. The module-shape examples in the living wiki should be treated as lit-backed for the `$a/$b/$c` families and source-derived for broader non-goal notes.

## Current-main freshness check

On 2026-04-24, the current `main` `src/passes/ReorderFunctions.cpp` was spot-checked against `version_129` for the documented surface.

Durable result:

- No teaching-relevant drift was observed for `ReorderFunctionsByName`: the public class, declaration-only fixup override, and ascending-name sort story remain the same on the reviewed surface.

Uncertainty:

- This was a narrow source spot check, not a full release-diff audit. If a future Binaryen release changes the registration text, writer behavior, or function-index remapping machinery outside this file, update the living dossier and record the new source set.

## Starshine-local source anchors

The local status and future-port map in the living dossier are grounded in these repository files:

- `src/passes/optimize.mbt`
  - `pass_registry_boundary_only_names()` includes `reorder-functions-by-name`.
  - `HotPassRegistryCache::new()` excludes boundary-only entries from public help entries.
  - `run_hot_pipeline_expand_passes(...)` rejects explicit boundary-only pass requests with a boundary-only-not-implemented error.
  - `optimize_preset_passes(...)` and `shrink_preset_passes(...)` do not include this pass.
- `src/lib/types.mbt`
  - `Module` stores `func_sec`, `code_sec`, `export_sec`, `start_sec`, `elem_sec`, `name_sec`, and `func_annotation_sec` separately, so a future function reorder must keep all index-bearing surfaces coherent.
  - `FuncSec`, `CodeSec`, `StartSec`, and `FuncIdx` define the core function-order/index data model.
- `src/passes/remove_unused_module_elements.mbt`
  - Existing `rume_rewrite_func_idx`, instruction rewriting, element rewriting, export/start rewriting, name-section rewriting, and function-annotation rewriting provide the closest in-tree remap examples for a future module-level reorder port.
- `src/binary/encode.mbt`
  - `Encode for Module` writes `func_sec` and later `code_sec`, export/start/elem/name data from the `Module` model; a future reorder must rewrite the model before encoding rather than expecting the encoder to invent a permutation.
- `src/wast/lower_to_lib.mbt`
  - WAT lowering resolves named function uses into numeric `FuncIdx` values for exports, start sections, element segments, calls, and `ref.func`, so future reordering must remap already-lowered indices.

## Durable conclusion

`reorder-functions-by-name` is one of the smallest Binaryen public passes, but it still deserves a complete dossier because it has:

- a real public pass name,
- a dedicated upstream lit file,
- a separate purpose from count-based `reorder-functions`,
- and a nontrivial local porting implication in Starshine: numeric function indices and metadata must be remapped if declaration order changes.
