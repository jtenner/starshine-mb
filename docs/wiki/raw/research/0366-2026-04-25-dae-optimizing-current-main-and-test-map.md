# `dae-optimizing` current-main and implementation/test-map follow-up

_Date:_ 2026-04-25  
_Status:_ absorbed into living wiki pages

## Question

The `dae-optimizing` dossier already had overview, Binaryen strategy, transformed-shape, focused scheduler/signature, and Starshine status pages, but it still lacked the now-standard implementation/test-map page. That made the folder harder to use as a beginner-to-advanced bridge because readers had to infer which upstream file owned which part of the pass and which lit files proved the optimizing-specific behavior.

## Sources read

Primary online sources are captured in:

- `docs/wiki/raw/binaryen/2026-04-25-dae-optimizing-current-main-and-test-map.md`

Prior wiki sources reviewed for overlap:

- `docs/wiki/binaryen/passes/dae-optimizing/index.md`
- `docs/wiki/binaryen/passes/dae-optimizing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dae-optimizing/signature-updates-and-nested-reruns.md`
- `docs/wiki/binaryen/passes/dae-optimizing/wat-shapes.md`
- `docs/wiki/binaryen/passes/dae-optimizing/starshine-strategy.md`
- `docs/wiki/binaryen/passes/dead-argument-elimination/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`

Local status sources:

- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`

## Findings

### The source contract remains stable

The focused 2026-04-25 current-main recheck found no teaching-relevant drift from the `version_129` contract already taught by the dossier.

The same owner split remains the right mental model:

- `DeadArgumentElimination.cpp` owns the shared direct-call boundary rewrite engine.
- `pass.cpp` owns the public pass-name split between `dae`, `dae-optimizing`, and neighboring `dae2`.
- `opt-utils.h` owns the optimizing-only nested cleanup helper.
- `param-utils.h`, `return-utils.h`, `lubs.h`, `type-updating.h`, and `utils.h` explain why the pass is both boundary analysis and repair plumbing rather than simple parameter deletion.

### The test surface is distributed

The best proof map is not one file:

- `dae-optimizing.wast` is the strongest optimizing-wrapper public proof.
- `dae-refine-params-and-optimize.wast` ties parameter refinement to optimizing cleanup.
- `dae-gc.wast` is broad shared-core GC evidence.
- `dae-gc-refine-params.wast` and `dae-gc-refine-return.wast` isolate the main refinement families.
- `dae_tnh.wast` proves TNH / unreachable repair behavior relevant to dropped-return removal.

The plain `dead-argument-elimination` implementation/test-map page already covered the shared core, but the optimizing sibling still needed its own owner/test page so future port work does not miss the nested-rerun delta.

### Starshine local status did not change

Starshine still does not implement the pass. The local registry knows `dead-argument-elimination-optimizing` as boundary-only, not exact upstream `dae-optimizing` as an alias. A faithful port remains module-boundary plus scheduler work, not a HOT peephole.

## Wiki updates made from this research

- Added `docs/wiki/raw/binaryen/2026-04-25-dae-optimizing-current-main-and-test-map.md`.
- Added `docs/wiki/binaryen/passes/dae-optimizing/implementation-structure-and-tests.md`.
- Refreshed the `dae-optimizing` landing, Binaryen strategy, focused signature/rerun page, WAT-shape catalog, and Starshine status page to point at the new implementation/test-map page and current-main source bridge.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/log.md`, and `CHANGELOG.md`.

## Follow-up questions

- The local spelling decision remains open: add exact upstream aliases, keep only descriptive names, or support both.
- When implementation work starts, the pass will need a real module-boundary owner plus nested rerun scheduler support. The docs now identify the required source and test surfaces, but they intentionally do not invent the future MoonBit file layout.
