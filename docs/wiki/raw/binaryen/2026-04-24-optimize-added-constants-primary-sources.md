# Binaryen `optimize-added-constants` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/optimize-added-constants/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `optimize-added-constants` provenance and Starshine status follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/optimize-added-constants/index.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/low-memory-threshold-overflow-and-offset-merge-rules.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/wat-shapes.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/starshine-strategy.md`
- `docs/wiki/binaryen/passes/optimize-added-constants-propagate/index.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - Neighboring 2026-04-24 pass ingests observed GitHub showing the publish timestamp as **2026-04-01 14:31**; this follow-up keeps `version_129` as the release oracle for the source reading.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24 in the pass-ingest campaign.

### Official source files consulted

- `src/passes/OptimizeAddedConstants.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeAddedConstants.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/OptimizeAddedConstants.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeAddedConstants.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/OptimizeAddedConstants.cpp>
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `src/pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/pass.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/pass.h>

### Official helper and dependency files consulted

- `src/ir/local-graph.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/local-graph.h>
- `src/ir/properties.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/properties.h>
- `src/ir/effects.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/effects.h>
- `src/wasm-builder.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-builder.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-builder.h>

### Official test files consulted

- `test/passes/optimize-added-constants_low-memory-unused.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants_low-memory-unused.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/optimize-added-constants_low-memory-unused.wast>
- `test/passes/optimize-added-constants_low-memory-unused.txt`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants_low-memory-unused.txt>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/optimize-added-constants_low-memory-unused.txt>
- `test/passes/optimize-added-constants-propagate_low-memory-unused.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants-propagate_low-memory-unused.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/optimize-added-constants-propagate_low-memory-unused.wast>
- `test/passes/optimize-added-constants-propagate_low-memory-unused.txt`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants-propagate_low-memory-unused.txt>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/optimize-added-constants-propagate_low-memory-unused.txt>
- `test/lit/passes/optimize-added-constants-memory64.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-memory64.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/optimize-added-constants-memory64.wast>
- `test/lit/passes/optimize-added-constants-nomemory.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-nomemory.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/optimize-added-constants-nomemory.wast>

## Durable observations from the captured sources

- `optimize-added-constants` and `optimize-added-constants-propagate` are both real public Binaryen pass names in `version_129`, registered from the same `OptimizeAddedConstants.cpp` engine through `src/passes/pass.cpp`.
- The shared owner file is a function pass over memory operations. Its core target is `Load` / `Store` pointer canonicalization, not generic integer reassociation.
- Both public variants require `--low-memory-unused`; the pass aborts rather than silently running without the low-memory assumption.
- The reviewed threshold is still `PassOptions::LowMemoryBound = 1024`, and the official tests make the strict cutoff visible: `1023` folds while `1024` does not.
- Plain `optimize-added-constants` handles direct address shapes, commuted adds, existing-offset accumulation, and constant-pointer-plus-offset normalization when unsigned overflow is impossible.
- The propagate sibling adds `LazyLocalGraph` local-pair propagation, optional helper-local insertion, dead-set cleanup, and iteration. That machinery is extra behavior, not part of the plain pass contract.
- The official no-memory lit test proves that modules with no memories are valid no-op inputs.
- The memory64 lit test proves that constant-pointer normalization must check pointer-width overflow instead of merely adding the declared memory offset to the constant.
- A narrow 2026-04-24 current-`main` source revisit on the owner, registration, option, and test surfaces did not add a new teaching-relevant contract beyond the refreshed dossier claims. This is intentionally a narrow freshness note, not a whole-repository equivalence proof.
- Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that both public pass spellings are preserved as **removed** registry names, while CLI/options plumbing already carries `low_memory_unused` and `low_memory_bound` values a future port would need.

## Uncertainties and contradictions

- The earlier living dossier already corrected the most important stale claim: this pass family is not a generic add/sub reassociation pass. This raw capture preserves that correction and points back to the corrected pages instead of trying to resurrect the older reading.
- Starshine exposes `low_memory_bound` as a configurable CLI / `OptimizeOptions` field, while Binaryen's source constant is `PassOptions::LowMemoryBound = 1024`. A future local port must decide whether to match Binaryen's fixed public constant exactly for parity mode or intentionally honor Starshine's configurable option; this dossier records that as a future design choice, not as current behavior.
- This capture focused on the official Binaryen source and tests for `version_129` plus a narrow current-`main` check. It does not claim exhaustive equivalence between the release tag and current trunk.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages and the 2026-04-24 Starshine follow-up research note.
