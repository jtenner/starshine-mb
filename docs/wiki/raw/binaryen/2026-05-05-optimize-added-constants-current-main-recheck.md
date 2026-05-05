# Binaryen `optimize-added-constants` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main recheck and exact source-anchor digest for the plain `optimize-added-constants` dossier

## Scope

This capture refreshes the plain `optimize-added-constants` source map and records the line-anchored upstream locations that matter for a first Starshine port.

Use this file together with:

- `docs/wiki/binaryen/passes/optimize-added-constants/index.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/wat-shapes.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/starshine-strategy.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/optimize-added-constants-propagate/index.md`

## Official online primary sources rechecked

### Binaryen `version_129` / current-main contract surfaces

- `src/passes/OptimizeAddedConstants.cpp`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeAddedConstants.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/OptimizeAddedConstants.cpp>
  - Exact source locations:
    - file header and contract summary (`Optimize added constants into load/store offsets`, low-memory assumption, propagate sibling note)
    - `MemoryAccessOptimizer`
    - `optimizeConstantPointer`
    - `tryToOptimizeConstant`
    - `tryToOptimizePropagatedAdd`
    - `canOptimizeConstant`
    - `OptimizeAddedConstants::isFunctionParallel`
    - `OptimizeAddedConstants::doWalkFunction`
    - `createOptimizeAddedConstantsPass`
    - `createOptimizeAddedConstantsPropagatePass`
- `src/passes/pass.cpp`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - Exact source location: public registration strings for `optimize-added-constants` and `optimize-added-constants-propagate`.
- `src/pass.h`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/pass.h>
  - Exact source location: `PassOptions::LowMemoryBound`.
- `test/passes/optimize-added-constants_low-memory-unused.wast`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants_low-memory-unused.wast>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/optimize-added-constants_low-memory-unused.wast>
- `test/passes/optimize-added-constants_low-memory-unused.txt`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants_low-memory-unused.txt>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/optimize-added-constants_low-memory-unused.txt>
- `test/lit/passes/optimize-added-constants-memory64.wast`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-memory64.wast>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/optimize-added-constants-memory64.wast>
- `test/lit/passes/optimize-added-constants-nomemory.wast`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-nomemory.wast>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/optimize-added-constants-nomemory.wast>

## Source anchor digest

The reviewed upstream file is compact and deliberately narrow:

- plain mode is the direct-address half of the shared engine;
- propagate mode is the same engine plus local-pair follow-through;
- the safety gate is `--low-memory-unused`;
- the public threshold is `PassOptions::LowMemoryBound = 1024`;
- constant-pointer normalization is overflow-aware and separate from the low-memory gate.

## Durable observations

- No teaching-relevant current-main drift was observed on the reviewed owner, registration, threshold, and test surfaces.
- The plain pass stays a memory-address canonicalizer, not a generic arithmetic reassociation pass.
- The sibling pass should remain a separate contract: local-pair propagation is extra behavior, not hidden plain-pass behavior.
