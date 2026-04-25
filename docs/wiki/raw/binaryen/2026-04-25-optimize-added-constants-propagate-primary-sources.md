# Binaryen `optimize-added-constants-propagate` primary-source capture

_Capture date:_ 2026-04-25  
_Status:_ immutable sibling-specific source manifest for the `docs/wiki/binaryen/passes/optimize-added-constants-propagate/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-25 `optimize-added-constants-propagate` provenance and Starshine status follow-up.
The sibling [`2026-04-24-optimize-added-constants-primary-sources.md`](./2026-04-24-optimize-added-constants-primary-sources.md) already captured the shared owner file; this manifest exists because the propagate variant previously lacked its own raw-source anchor and dedicated Starshine page even though it has a distinct public contract.

Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/optimize-added-constants-propagate/index.md`
- `docs/wiki/binaryen/passes/optimize-added-constants-propagate/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/optimize-added-constants-propagate/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/optimize-added-constants-propagate/wat-shapes.md`
- `docs/wiki/binaryen/passes/optimize-added-constants-propagate/starshine-strategy.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/index.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-25.
  - The release tag remains the source oracle for this dossier. Neighboring 2026-04-24 ingests recorded GitHub showing this release as published on 2026-04-01; this run did not need to reinterpret that release horizon.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-25.

### Official source files consulted

- `src/passes/OptimizeAddedConstants.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeAddedConstants.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/OptimizeAddedConstants.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeAddedConstants.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/OptimizeAddedConstants.cpp>
  - Important source locations/names: the `MemoryAccessOptimizer` pass class, the `propagate` constructor field, `visitLoad`, `visitStore`, `optimize`, `tryPropagate`, `tryRemoveSet`, and the `run(...)` loop that creates `LazyLocalGraph` only when `propagate` is enabled.
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - Important source locations/names: public registrations for `optimize-added-constants` and `optimize-added-constants-propagate` with the propagate description saying it propagates across locals.
- `src/pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/pass.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/pass.h>
  - Important source location/name: `PassOptions::LowMemoryBound = 1024`.

### Official helper and dependency files consulted

- `src/ir/local-graph.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/local-graph.h>
  - Why it matters: `LazyLocalGraph` is the propagate sibling's defining extra analysis dependency.
- `src/ir/properties.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/properties.h>
  - Why it matters: the pass classifies integer constants and address expressions.
- `src/ir/effects.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/effects.h>
  - Why it matters: helper-local insertion and movement safety must preserve observable effects.
- `src/wasm-builder.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-builder.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-builder.h>
  - Why it matters: `Builder` constructs helper-local and replacement expressions.

### Official test files consulted

- `test/passes/optimize-added-constants-propagate_low-memory-unused.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants-propagate_low-memory-unused.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/optimize-added-constants-propagate_low-memory-unused.wast>
  - Why it matters: direct behavioral oracle for local-pair propagation, helper-local salvage, repeated stack-pointer style updates, and bailouts.
- `test/passes/optimize-added-constants-propagate_low-memory-unused.txt`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants-propagate_low-memory-unused.txt>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/optimize-added-constants-propagate_low-memory-unused.txt>
  - Why it matters: expected-output oracle for `nop` leftovers, helper locals, and preserved non-propagated local-carrier shapes.
- `test/passes/optimize-added-constants_low-memory-unused.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants_low-memory-unused.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/optimize-added-constants_low-memory-unused.wast>
- `test/passes/optimize-added-constants_low-memory-unused.txt`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants_low-memory-unused.txt>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/optimize-added-constants_low-memory-unused.txt>
  - Why the plain tests still matter: they define the direct-address fold, strict threshold, negative-constant, existing-offset, and no-propagation baseline inherited by the propagate sibling.
- `test/lit/passes/optimize-added-constants-memory64.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-memory64.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/optimize-added-constants-memory64.wast>
  - Why it matters: constant-pointer-plus-offset normalization must respect pointer-width overflow.
- `test/lit/passes/optimize-added-constants-nomemory.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-nomemory.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/optimize-added-constants-nomemory.wast>
  - Why it matters: no-memory modules are a no-op input, not a fatal error once the low-memory option is present.

## Durable observations from the captured sources

- `optimize-added-constants-propagate` is a real public Binaryen pass name in `version_129`, not just an undocumented mode of `optimize-added-constants`.
- The pass is the same memory-address-to-load/store-offset optimizer as the plain sibling, with an extra `propagate = true` mode that builds `LazyLocalGraph` and chases local `set/get` address carriers.
- The pass still hard-requires `--low-memory-unused` and uses the same strict `PassOptions::LowMemoryBound = 1024` cutoff for candidate constants and final merged offsets.
- The propagate-only contract includes dead address-local cleanup, helper-local insertion when direct base reuse is unsafe, and repeated iteration because one local propagation can unlock the next.
- The official propagate output file intentionally shows visible `nop`s and helper locals. Those are not formatting accidents; they are part of the beginner-facing shape story.
- Current Starshine keeps `optimize-added-constants-propagate` in `pass_registry_removed_names()` and rejects explicit requests through the removed-pass guard. There is no `src/passes/optimize_added_constants_propagate.mbt` owner file, no dispatcher case, and no active backlog slice found in this run.
- Starshine already has relevant prerequisites: `--low-memory-unused` / `--low-memory-bound` option plumbing, HOT `Load` / `Store` nodes with `MemArg` side-table payloads, WAT/binary memory-op offset parsing/encoding, and local use-def analysis. Those are reusable surfaces, not an implementation.
- A narrow 2026-04-25 current-`main` revisit of the owner, registration, option, helper, and direct test URLs did not reveal a teaching-relevant contract change beyond the `version_129` claims. This is a targeted freshness check, not an exhaustive release-drift audit.

## Uncertainties and contradictions

- The shared 2026-04-24 manifest already covered many of these files for the plain sibling. This sibling-specific capture supersedes that manifest only for the question “does `optimize-added-constants-propagate` have its own raw provenance and Starshine status bridge?” It does not replace the shared family source capture.
- Starshine exposes `low_memory_bound` as a configurable option, while Binaryen's source uses the fixed public `PassOptions::LowMemoryBound = 1024`. A future parity port must explicitly choose whether the exact Binaryen mode ignores Starshine's configurability or intentionally honors it as a Starshine extension.
- This run confirmed the local registry status and prerequisite surfaces by repository search; it did not design or implement a faithful local propagation algorithm.

## Consumability rule

Future wiki pages should cite this manifest for the propagate-specific public-pass contract, [`2026-04-24-optimize-added-constants-primary-sources.md`](./2026-04-24-optimize-added-constants-primary-sources.md) for the shared family source capture, and `docs/wiki/binaryen/passes/optimize-added-constants-propagate/starshine-strategy.md` for the current local status and future-port map.
