# `propagate-globals-globally` source correction and Starshine follow-up

Date: 2026-04-24  
Status: source-backed wiki correction and Starshine status bridge  
Pass: `propagate-globals-globally`  
Local registry status: `boundary-only` in `src/passes/optimize.mbt`

## 1. Why this pass was selected

I re-read `AGENTS.md`, `docs/README.md`, `docs/wiki/`, `docs/wiki/index.md`, `docs/wiki/log.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/raw/research/` before choosing a pass.

`propagate-globals-globally` qualified because its folder was visibly incomplete and partly stale:

1. it had no immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`
2. it had no dedicated Starshine status/port-strategy page
3. the older 2026-04-21 correction got the shared `SimplifyGlobals.cpp` owner file right but still over-described nonexistent helper names, the scan order, and the family split
4. the pass is already a local boundary-only registry name, so exact local behavior matters even though it is outside the current no-DWARF and saved `-O4z` parity queues

## 2. Source inventory reviewed

### Local repo sources

- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/lib/types.mbt`
- `src/wast/parser.mbt`
- `src/wast/lower_to_lib.mbt`
- `src/validate/validate.mbt`
- `src/binary/encode.mbt`
- `src/binary/decode.mbt`
- `src/validate/gen_valid.mbt`
- `docs/wiki/binaryen/passes/propagate-globals-globally/`
- `docs/wiki/binaryen/passes/simplify-globals/`
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/`
- `docs/wiki/raw/research/0162-2026-04-21-propagate-globals-globally-binaryen-research.md`
- `docs/wiki/raw/research/0196-2026-04-21-propagate-globals-globally-shared-engine-research.md`
- `agent-todo.md`

### Official Binaryen sources

Captured in `docs/wiki/raw/binaryen/2026-04-24-propagate-globals-globally-primary-sources.md`:

- Binaryen `version_129` release page
- `src/passes/SimplifyGlobals.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/propagate-globals-globally.wast`
- current `main` spot-check URLs for the same surfaces

## 3. Main source correction

The 2026-04-21 folder already corrected the original standalone-file mistake: the pass is implemented in `SimplifyGlobals.cpp`, not `PropagateGlobals.cpp`.

This run found three follow-up corrections:

1. The reviewed `version_129` source does not expose the earlier wiki's `canHandleAsGlobal` / `allInputsConstant` helper pair. The actual startup-global pass uses `FindAllPointers<GlobalGet>`, `Builder::makeConstantExpression(...)`, `Literals`, and `Properties::isConstantExpression(...)`.
2. The global-initializer phase scans defined globals in declaration order, not reverse order.
3. The public pass boundary is not simply “construct shared engine with `optimize = false`.” The public pass is a separate `PropagateGlobalsGlobally` subclass whose `run(Module*)` calls only `propagateConstantsToGlobals()`. The broader `SimplifyGlobals` pass calls `propagateConstantsToGlobals()` and then `propagateConstantsToCode()` in its ordinary iteration; the `optimize` flag controls cleanup behavior after code-level propagation, not the top-level public-pass boundary by itself.

## 4. Correct Binaryen strategy in one paragraph

Binaryen `propagate-globals-globally` is a narrow module pass implemented beside `simplify-globals*`. It collects literal values for immutable global initializers that remain Binaryen constant expressions after substituting already-known `global.get` inputs, records them by global name, substitutes those known values into later startup-level places, and applies the same replacement to active element and data offsets. It intentionally does not run `propagateConstantsToCode()`, so ordinary function-body `global.get` uses are preserved by this public pass even though the broader `simplify-globals` sibling may rewrite them.

## 5. Local Starshine status

Starshine currently does not implement `propagate-globals-globally`.

Exact code-map facts:

- `src/passes/optimize.mbt` lists `propagate-globals-globally` in `pass_registry_boundary_only_names()`.
- The active `optimize` and `shrink` preset arrays in `src/passes/optimize.mbt` omit the pass.
- `run_hot_pipeline_expand_passes(...)` rejects explicit requests for boundary-only names with the standard “boundary-only and not implemented” error before any pass runs.
- `src/passes/pass_manager.mbt` has no `run_hot_pipeline_apply_module_pass(...)` case for `propagate-globals-globally`.
- No owner file such as `src/passes/propagate_globals_globally.mbt` exists.
- `agent-todo.md` has no dedicated backlog slice for this pass.

Reusable local surfaces for a future implementation include:

- `src/lib/types.mbt` for `GlobalSec`, `Global`, `Expr`, `ElemSec`, `ElemMode::Active`, `DataSec`, `DataMode::Active`, `Instruction::GlobalGet`, and constant instructions.
- `src/validate/validate.mbt` for constant-expression validation, immutable-global `global.get` checks, and active data/elem offset validation.
- `src/wast/parser.mbt` and `src/wast/lower_to_lib.mbt` for text fixtures and lowering global initializers / `global.get` instructions.
- `src/binary/encode.mbt` and `src/binary/decode.mbt` for global, elem, and data section roundtrips.

## 6. Wiki updates made from this note

This run:

- added `docs/wiki/raw/binaryen/2026-04-24-propagate-globals-globally-primary-sources.md`
- added `docs/wiki/binaryen/passes/propagate-globals-globally/starshine-strategy.md`
- refreshed `index.md`, `binaryen-strategy.md`, `implementation-structure-and-tests.md`, `shared-engine-and-startup-boundaries.md`, and `wat-shapes.md`
- updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/log.md`, and `CHANGELOG.md`
- marked the older `0162` and `0196` research notes as superseded for the corrected claims instead of silently overwriting them

## 7. Remaining uncertainties

- The raw capture includes a narrow current-`main` spot check, not a full semantic diff between `version_129` and trunk.
- The exact expression-family coverage comes from Binaryen's `Properties::isConstantExpression(...)`; living docs should avoid maintaining a stale closed whitelist unless future work reviews that helper directly.
- A future Starshine port needs a deliberate design choice about whether to build a shared module helper family with future `simplify-globals*` work or land this smaller pass first with clearly separable startup-expression utilities.
