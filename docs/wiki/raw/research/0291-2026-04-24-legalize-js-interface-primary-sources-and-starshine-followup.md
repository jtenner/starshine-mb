# `legalize-js-interface` primary sources and Starshine follow-up

- Date: 2026-04-24
- Researcher: OpenAI Codex
- Scope: refresh the existing Binaryen `legalize-js-interface` dossier with an immutable primary-source manifest and add the missing Starshine status / port-strategy bridge.

## Why this follow-up was worthwhile

The existing `legalize-js-interface` folder already had beginner-friendly coverage for the pass overview, Binaryen algorithm, implementation/test map, temp-ret helper details, and WAT shapes.
It still had two durable wiki-health gaps:

1. it cited live GitHub URLs and the older research note directly, but had no committed raw primary-source manifest under `docs/wiki/raw/binaryen/`; and
2. it did not have a dedicated Starshine strategy page explaining the exact current local status and code surfaces future work would need to read.

That made the folder less usable for a reader trying to follow the chain from Binaryen source to local Starshine behavior.

## Primary source capture added

Added:

- `docs/wiki/raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md`

The manifest records the official sources reviewed in this run:

- Binaryen `version_129` release page and releases index
- `src/passes/LegalizeJSInterface.cpp`
- `src/passes/pass.cpp`
- helper surfaces: `src/passes/i64.h`, `src/ir/import-utils.h`, `src/ir/literal-utils.h`, `src/wasm/shared-constants.h`
- dedicated lit files:
  - `legalize-js-interface_all-features.wast`
  - `legalize-js-interface-exported-helpers.wast`
  - `legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast`
  - `legalize-and-prune-js-interface.wast`

The release page observed on 2026-04-24 showed `version_129` dated **2026-04-01 14:31**.
A narrow current-`main` spot check on the owner file, registration surface, helper headers, and dedicated lit files did not expose teaching-relevant drift from the refreshed dossier story.

## Source-backed Binaryen facts preserved

The refreshed pages keep these points explicit:

- `legalize-js-interface` is a JS-boundary pass, not a whole-module integer lowering pass.
- The plain pass rewrites only function imports/exports whose boundary signatures contain `i64`.
- Export wrappers are JS-facing `legalstub$...` functions that rebuild inbound `i64` values and use temp-ret helpers for high result halves.
- Import handling creates JS-facing `legalimport$...` imports plus wasm-facing `legalfunc$...` wrappers.
- Imported-use repair covers both ordinary `call` and `ref.func` targets.
- `legalize-js-interface-export-originals` and `legalize-js-interface-exported-helpers` are pass arguments, not separate passes.
- `legalize-and-prune-js-interface` is a separate public sibling that runs the plain pass first and then stubs or hides still-JS-hostile boundary features.

## Starshine status found

Current Starshine has no local implementation or even compatibility registry entry for `legalize-js-interface`:

- `src/passes/optimize.mbt` does **not** list `legalize-js-interface` in `pass_registry_boundary_only_names()`.
- `src/passes/optimize.mbt` does **not** list `legalize-js-interface` in `pass_registry_removed_names()`.
- `src/passes/optimize.mbt` therefore reports the name as an unknown pass request through `run_hot_pipeline_expand_passes(...)`.
- `src/passes/registry_test.mbt` exercises active / module / removed registry classes but has no positive or negative `legalize-js-interface` case today.
- `agent-todo.md` has no dedicated `legalize-js-interface` slice.

That status is intentionally stronger than ordinary “unimplemented”: the pass is upstream-only in the current local registry.

## Local code surfaces a future port would need

The new Starshine page points readers to the closest existing code surfaces:

- registry and request behavior:
  - `src/passes/optimize.mbt`
  - `src/passes/registry_test.mbt`
- module ABI data structures:
  - `src/lib/types.mbt`
- binary section roundtrip support:
  - `src/binary/encode.mbt`
  - `src/binary/decode.mbt`
  - `src/binary/tests.mbt`
- textual WAT import/export/ref.func surfaces:
  - `src/wast/keywords.mbt`
  - `src/wast/module_wast.mbt`
  - `src/wast/lower_to_lib.mbt`
  - `src/wast/module_wast_tests.mbt`
- neighboring docs:
  - `docs/wiki/binaryen/passes/i64-to-i32-lowering/index.md`
  - `docs/wiki/binaryen/passes/legalize-and-prune-js-interface/index.md`

## Main uncertainty

The open local question is policy, not an algorithm mystery: should Starshine preserve `legalize-js-interface` and `legalize-and-prune-js-interface` as boundary-only names before any transform exists, or keep them truly unknown until a module/boundary pass is implemented?

The current repo state chooses unknown names.
Future work should make any registry change explicit with tests rather than silently turning the dossier into an implementation promise.

## Files updated by this follow-up

- `docs/wiki/raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md`
- `docs/wiki/raw/research/0291-2026-04-24-legalize-js-interface-primary-sources-and-starshine-followup.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/index.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/temp-ret-helpers-and-pruning-split.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/wat-shapes.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/starshine-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`
