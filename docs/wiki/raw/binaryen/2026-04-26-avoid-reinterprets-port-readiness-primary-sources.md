# Binaryen `avoid-reinterprets` port-readiness primary-source bridge

_Capture date:_ 2026-04-26  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/avoid-reinterprets/` port-readiness follow-up

## Scope

This file captures the focused primary sources rechecked while deepening the `avoid-reinterprets` dossier from source-correct status coverage into a future Starshine implementation-readiness guide.
It does not replace the earlier source manifest:

- `docs/wiki/raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md`

Use the living pages for explanation:

- `docs/wiki/binaryen/passes/avoid-reinterprets/index.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/single-load-chains-and-bailouts.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/wat-shapes.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/starshine-strategy.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/starshine-port-readiness-and-validation.md`

## Official upstream sources rechecked

### Core implementation

- Binaryen `version_129` `src/passes/AvoidReinterprets.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AvoidReinterprets.cpp>
- Binaryen current `main` `src/passes/AvoidReinterprets.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/AvoidReinterprets.cpp>

Teaching anchors rechecked:

- the file-level comment still frames the pass as avoiding reinterprets by issuing extra loads for the alternate type;
- `canReplaceWithReinterpret(...)` still rejects unreachable and non-full-width loads;
- `getSingleLoad(...)` still requires exactly one reaching set, rejects `nullptr`, follows `Properties::getFallthrough(...)`, follows copy `local.get` chains, and bails out on cycles;
- `visitUnary(...)` still discovers only reinterpret users whose operand falls through to a `local.get` with one source load;
- `optimize(...)` still allocates one pointer local using the memory's address type and one alternate typed value local per eligible source load;
- the inner final optimizer still splits direct `reinterpret(load)` load-type flips from indirect `reinterpret(local.get)` helper-local rewrites.

### Registration and tests

- Binaryen `version_129` `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen current `main` `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Binaryen `version_129` `test/lit/passes/avoid-reinterprets.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets.wast>
- Binaryen current `main` `test/lit/passes/avoid-reinterprets.wast`
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/avoid-reinterprets.wast>
- Binaryen `version_129` `test/lit/passes/avoid-reinterprets64.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets64.wast>
- Binaryen current `main` `test/lit/passes/avoid-reinterprets64.wast`
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/avoid-reinterprets64.wast>

Teaching anchors rechecked:

- the pass remains a public upstream spelling `avoid-reinterprets`;
- the memory32 lit lane still runs `wasm-opt --avoid-reinterprets` and proves direct flips, indirect helper locals, shared helpers, mixed uses, copy chains, partial-load no-ops, and non-fallthrough bailouts;
- the memory64 lit lane still runs the same pass with `--enable-memory64` and proves the `i64` pointer-helper-local shape.

## Local Starshine sources rechecked

- `src/passes/optimize.mbt`
  - `pass_registry_removed_names()` keeps `avoid-reinterprets` as a removed name at `src/passes/optimize.mbt:144-150`.
  - `pass_registry_entries()` turns removed names into removed registry entries at `src/passes/optimize.mbt:274-276`.
  - explicit removed-name requests still fail at `src/passes/optimize.mbt:469-471`.
- `src/passes/registry_test.mbt`
  - the current removed-name rejection regression is category-level and uses `de-nan`, not a pass-specific `avoid-reinterprets` fixture.
- `src/ir/hot_builders.mbt`
  - current builders cover the required future output shapes: `hot_build_local_get`, `hot_build_local_set`, `hot_build_local_tee`, `hot_build_load`, and `hot_build_unary`.
- `src/ir/hot_mutate.mbt`
  - `hot_append_body_local(...)` remains the fresh body-local allocation surface a future helper-local port would likely use.
- `src/ir/use_def.mbt`
  - use-def tracks local reads and writes and block-level local sets, but it is not currently a Binaryen `LocalGraph` equivalent.
- `src/ir/ssa_local.mbt`
  - HOT local SSA maps local gets to value IDs, records local write definitions, entry definitions, phi inputs, and value uses, but it is not yet documented as matching Binaryen's exact `getSingleLoad(...)` proof for params, merges, fallthrough wrappers, and unreachable cycles.
- `src/ir/hot_lift.mbt`, `src/ir/hot_lower.mbt`, `src/lib/types.mbt`, `src/wast/lower_to_lib.mbt`, `src/binary/encode.mbt`, and `src/validate/typecheck.mbt`
  - the four reinterpret opcodes already parse/lower/validate/encode/HOT-lift roundtrip, so the first missing piece is pass logic, not opcode representation.

## Durable observations

- The 2026-04-26 current-main source recheck found no teaching-relevant drift from the earlier `version_129` interpretation: the pass remains a narrow extra-load rewrite, not a generic reinterpret, local-propagation, or load-CSE pass.
- The most useful new documentation gap was Starshine implementation readiness, not upstream semantics. The existing folder taught the Binaryen contract correctly, but future implementers still had to infer a first safe local slice and validation ladder from scattered registry, HOT builder, use-def, local SSA, validator, and binary surfaces.
- A faithful first Starshine slice should be direct `reinterpret(load)` load-type flips before any `LocalGraph`-like local-chain proof. That slice has the smallest correctness surface and can validate against the `simple` family in the official lit tests.
- The second slice should add the indirect `reinterpret(local.get)` helper-local rewrite only after a documented single-load provenance helper exists. That helper must make entry/default values, multi-source merges, fallthrough wrappers, and unreachable-copy cycles explicit.
- No contradiction was found with the earlier dossier. The only refreshed local correction is line-anchor hygiene: current `optimize.mbt` removed-name and request-guard anchors are now `144-150`, `274-276`, and `469-471`, not the older nearby ranges.

## Consumability rule

Cite this manifest when discussing Starshine port-readiness or the 2026-04-26 current-main recheck. Cite the earlier 2026-04-24 manifest when discussing the original source capture and release provenance.
