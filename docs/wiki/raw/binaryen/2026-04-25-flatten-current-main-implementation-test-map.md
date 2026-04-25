# Binaryen `flatten` current-main implementation/test-map capture

_Capture date:_ 2026-04-25  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/flatten/` dossier

## Scope

This file captures the primary online sources consulted during the 2026-04-25 `flatten` wiki health/deepening run. It supplements, rather than replaces, the tagged `version_129` manifest at `docs/wiki/raw/binaryen/2026-04-23-flatten-primary-sources.md`.

The goal of this capture is practical: make the owner files, helper files, official tests, and current Starshine status map consumable from the new `implementation-structure-and-tests.md` page without re-opening scattered GitHub tabs.

## Official Binaryen sources consulted

### Current `main`

- `src/passes/Flatten.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Flatten.cpp>
  - Current page observed on 2026-04-25.
  - GitHub reported `424` lines / `391` loc.
  - Teaching-relevant current-main observations:
    - still owns the public `Flatten` pass and `createFlattenPass()` constructor;
    - still reports a function-parallel pass and DWARF invalidation;
    - still centers the implementation on `preludes` and `breakTemps`;
    - still uses custom control-flow handling for `Block`, `If`, `Loop`, and legacy `Try`;
    - still eliminates reachable `local.tee` through set/get traffic and unreachable tees by keeping the unreachable value;
    - still routes carried `br` / `br_if` / `switch` values through target temps;
    - still hard-fails on `BrOn*` and `TryTable` with `Unsupported instruction for Flatten`;
    - still finishes functions by attaching remaining preludes and calling `EHUtils::handleBlockNestedPops(...)`.
- `src/ir/flat.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/flat.h>
  - Current page observed on 2026-04-25.
  - GitHub reported `134` lines / `120` loc.
  - Teaching-relevant current-main observations:
    - still defines the formal Flat IR verifier;
    - ordinary operands are still limited to constant expressions, `local.get`, `unreachable`, and `ref.as_non_null`;
    - control-flow structures still must not flow values;
    - tees are still rejected except unreachable tees;
    - `local.set` values still cannot be control-flow structures;
    - function bodies still must not flow values.
- `src/passes/pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Current page observed on 2026-04-25.
  - Teaching-relevant current-main observations:
    - the aggressive `optimizeLevel >= 4` cluster still schedules `flatten`, then `simplify-locals-notee-nostructure`, then `local-cse`;
    - the source comment still frames that cluster as work that depends on Flat IR.
- `src/passes/passes.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - Current page observed on 2026-04-25.
  - Teaching-relevant current-main observation: the public constructor declaration remains part of the pass surface.
- Supporting helper surfaces retained from the tagged manifest and re-used by the current implementation reading:
  - `src/ir/branch-utils.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/branch-utils.h>
  - `src/ir/eh-utils.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/eh-utils.h>
  - `src/ir/properties.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/properties.h>
  - `src/ir/manipulation.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/manipulation.h>

### Tagged `version_129` anchors kept as the oracle

- `src/passes/Flatten.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Flatten.cpp>
- `src/ir/flat.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
- `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>

## Official Binaryen tests consulted

### Current `main`

- `test/lit/passes/flatten.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten.wast>
  - Current page observed on 2026-04-25.
  - GitHub reported `21` lines / `20` loc.
  - Durable observation: this is a tiny non-nullable-param smoke test, not the full shape catalog.
- `test/lit/passes/flatten_all-features.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_all-features.wast>
  - Current page observed on 2026-04-25.
  - GitHub reported `847` lines / `822` loc.
  - Durable observation: this is the broad direct proof surface for all-feature flatten cases, including value-carrying control and branch-payload families.
- `test/lit/passes/flatten-eh-legacy.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten-eh-legacy.wast>
  - Current page observed on 2026-04-25.
  - GitHub reported `233` lines / `227` loc.
  - Durable observation: this directly proves legacy EH/catch `pop` handling and the nested-pop repair story.

### Tagged `version_129` tests retained as the oracle

- `test/lit/passes/flatten.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten.wast>
- `test/lit/passes/flatten_all-features.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_all-features.wast>
- `test/lit/passes/flatten-eh-legacy.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten-eh-legacy.wast>
- `test/lit/passes/opt_flatten.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/opt_flatten.wast>
- `test/lit/passes/flatten_rereloop.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_rereloop.wast>
- `test/lit/passes/flatten_i64-to-i32-lowering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_i64-to-i32-lowering.wast>

## Starshine local surfaces rechecked

- `src/passes/optimize.mbt:144-151`
  - `pass_registry_removed_names()` still lists `flatten` as a known removed pass.
- `src/cli/cli_test.mbt:280-285`
  - `--flatten` remains preserved when trap-mode flags are filtered from scheduled pass flags.
- `src/cli/cli_test.mbt:313-316`
  - `--flatten` remains preserved when `-O` flags are ignored for explicit preset expansion tests.
- `src/passes/pass_manager.mbt`
  - No active `flatten` dispatcher case exists today.
- `docs/0065-2026-03-24-ir2-execution-plan.md:39`
  - The old IR2 execution plan still lists `flatten` first in the preferred Batch 2 order.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md:47`
  - The old registry map still lists `flatten` as removed until implementation lands.
- `agent-todo.md`
  - No dedicated active `flatten` slice exists as of 2026-04-25. Mentions of “flattened” in hot-lower/merge-blocks text are shape descriptions, not a pass backlog slice.

## Durable conclusions

- No teaching-relevant current-main drift was found from the 2026-04-23 `version_129` dossier for the reviewed owner, flatness contract, scheduler, and dedicated lit surfaces.
- The new useful wiki work is therefore not a strategy correction; it is an implementation/test-map addition and a sharper current Starshine code map.
- The pass remains best taught as a Flat-IR structural normalizer whose official proof surface is split across a tiny smoke file, a broad all-features file, and a legacy EH repair file.
- The main Starshine status remains unchanged: known removed name, parse-preserved `--flatten` spelling, no dispatcher/owner file, old Batch 2 docs, and no active backlog slice.

## Consumability rule

Use this file as provenance for current-main freshness and owner/test-map claims. Use the living pages under `docs/wiki/binaryen/passes/flatten/` for explanations and future port guidance.
