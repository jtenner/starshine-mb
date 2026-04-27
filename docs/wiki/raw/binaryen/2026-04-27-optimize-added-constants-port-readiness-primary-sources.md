# Binaryen `optimize-added-constants` port-readiness primary-source capture

_Capture date:_ 2026-04-27  
_Status:_ immutable current-main recheck and Starshine port-readiness source manifest for the `docs/wiki/binaryen/passes/optimize-added-constants/` dossier

## Scope

This capture refreshes the earlier 2026-04-24 source manifest for the plain `optimize-added-constants` pass and records the exact local Starshine surfaces that a first implementation slice would use.

Use this file together with:

- `docs/wiki/binaryen/passes/optimize-added-constants/index.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/wat-shapes.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/starshine-strategy.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/optimize-added-constants-propagate/index.md`

## Official online primary sources rechecked

### Binaryen current `main`

- `src/passes/OptimizeAddedConstants.cpp`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeAddedConstants.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/OptimizeAddedConstants.cpp>
  - Important source locations: file header contract; `MemoryAccessOptimizer`; `optimizeConstantPointer`; `tryToOptimizeConstant`; `canOptimizeConstant`; `OptimizeAddedConstants::doWalkFunction`; `createOptimizeAddedConstantsPass`; `createOptimizeAddedConstantsPropagatePass`.
- `src/passes/pass.cpp`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - Important source location: public registration strings for `optimize-added-constants` and `optimize-added-constants-propagate`.
- `src/pass.h`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/pass.h>
  - Important source location: `PassOptions::LowMemoryBound`.
- `test/passes/optimize-added-constants_low-memory-unused.wast`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/optimize-added-constants_low-memory-unused.wast>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/passes/optimize-added-constants_low-memory-unused.wast>
- `test/passes/optimize-added-constants_low-memory-unused.txt`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/optimize-added-constants_low-memory-unused.txt>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/passes/optimize-added-constants_low-memory-unused.txt>
- `test/lit/passes/optimize-added-constants-memory64.wast`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-added-constants-memory64.wast>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/optimize-added-constants-memory64.wast>
- `test/lit/passes/optimize-added-constants-nomemory.wast`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-added-constants-nomemory.wast>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/optimize-added-constants-nomemory.wast>

### Stable release oracle retained

- Binaryen GitHub release `version_129`: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Earlier immutable source manifest retained as the release-tag oracle: `docs/wiki/raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md`

## Local Starshine code surfaces rechecked

- `src/passes/optimize.mbt`
  - `pass_registry_removed_names()` lists `optimize-added-constants` and `optimize-added-constants-propagate` together.
- `src/cli/cli.mbt`
  - parses `--low-memory-unused`, `--no-low-memory-unused`, and `--low-memory-bound`.
- `src/cmd/cmd.mbt`
  - `OptimizeOptions` carries `low_memory_unused` and `low_memory_bound`, defaults them to `false` and `1024`, and accepts JSON / environment plumbing for both fields.
- `src/ir/hot_core.mbt`
  - `HotOp` includes `Load`, `Store`, `Binary`, and `Const`, the minimal node families needed for a direct-address slice.
- `src/ir/hot_side_tables.mbt`
  - maps `HotOp::Load`, `HotOp::Store`, and `HotOp::Atomic` to `HotSideTableKind::MemArgTable`.
- `src/ir/hot_builders.mbt`
  - `hot_build_load(...)` and `hot_build_store(...)` allocate `HotMemArg` payloads from `MemArg`.
- `src/ir/hot_lift.mbt` / `src/ir/hot_lower.mbt`
  - lift and lower exact memory instructions through HOT, making rewritten offsets observable in binary/WAT roundtrips.
- `src/lib/types.mbt`
  - `MemArg(U32, MemIdx?, U64)` is the current Starshine memory-argument payload.
- `src/binary/decode.mbt` / `src/binary/encode.mbt`
  - decode and encode `MemArg` on scalar/SIMD memory operations.
- `src/wast/lexer.mbt` / `src/wast/keywords.mbt`
  - tokenize and spell `offset=` memory arguments and memory op names.
- `src/validate/typecheck.mbt`
  - is the post-rewrite guard for stack and memory-op typing.

## Durable observations

- Binaryen current `main` still teaches the same plain-pass contract captured on 2026-04-24: a direct load/store-address offset fold under the hard low-memory assumption, with a separate propagation sibling.
- No teaching-relevant current-main drift was observed for the plain pass's owner file, public registration, low-memory threshold, no-memory behavior, or memory64 overflow proof.
- Starshine has honest registry behavior today: the pass name is preserved only as a removed name, so explicit `--pass optimize-added-constants` is rejected instead of silently no-oping.
- Starshine already has the public option plumbing and HOT memory-op payload infrastructure needed for a narrow first slice, but there is no pass owner file, active dispatcher arm, focused test file, or pass-fuzz compare entry for this pass today.
- The first mutating Starshine slice should be deliberately smaller than Binaryen's shared file: direct `Load` / `Store` pointer folds only. The `LazyLocalGraph` local-pair propagation behavior belongs to `optimize-added-constants-propagate`.

## Uncertainties and contradictions

- The 2026-04-24 and 2026-04-27 source readings agree on the plain-pass contract. This capture does not supersede the older raw source; it adds a current-main freshness check and local implementation-readiness bridge.
- Starshine exposes `low_memory_bound` as configurable, while Binaryen's public source constant remains `PassOptions::LowMemoryBound = 1024`. A faithful parity mode should probably freeze `1024` unless the project explicitly chooses Starshine-specific configurability; that remains a future design choice, not current behavior.
- The web-rendered raw GitHub view observed by the agent folded C++ source lines into long records, so this manifest cites files and function / method names rather than depending on fragile rendered line numbers.
