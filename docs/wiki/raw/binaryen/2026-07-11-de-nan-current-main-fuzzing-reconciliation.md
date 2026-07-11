# Binaryen `denan` current-main and Starshine fuzzing reconciliation

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source/current-local-status bridge for `docs/wiki/binaryen/passes/de-nan/`

## Scope

This narrow refresh reread Binaryen `main`'s `denan` owner, registration, and focused lit oracle, then reconciled them with the current Starshine pass registry and compare-pass allowlist. It supersedes the **freshness claim** in the 2026-05-06 line-anchor refresh, but does not replace the older tagged or historical captures.

The purpose is twofold:

1. confirm the durable upstream `denan` contract used by the living dossier; and
2. correct the stale claim that a Starshine-vs-Binaryen `de-nan` compare-pass lane is runnable.

## Primary sources reread

### Upstream Binaryen `main`

- Owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeNaN.cpp>
- Registration/default-scheduler context: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Focused oracle: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/denan.wast>

### Current Starshine evidence

- Registry and removed-name execution path: `src/passes/optimize.mbt`
- Registry-category and removed-request tests: `src/passes/registry_test.mbt`
- Compare-pass admission and local-to-Binaryen alias map: `scripts/lib/pass-fuzz-compare-task.ts`
- Preflight policy: `docs/wiki/tooling/pass-fuzz-compare.md`

## Current upstream result

No behavior-bearing change was observed in the reread scope:

- Binaryen still registers the public pass spelling `denan` as runtime NaN-to-zero instrumentation.
- The owner still replaces constant `f32`, `f64`, and `v128` NaNs with zero constants; wraps nonconstant producers in same-typed helper calls; skips `local.get` and result-fallthrough shells; sanitizes parameters of defined functions; and adds helpers after the walk.
- Helper insertion still adds effects, avoids collisions with user function names, limits call-based rewrites to function context, uses lane-wise scalar checks for the SIMD helper, and runs nested `merge-blocks` after entry-param repair.
- The focused lit source remains the relevant shape oracle for global constants, entry repairs, calls, skipped locals/fallthroughs, and helper-name collisions.

This is a narrow source check, not a claim that every Binaryen option interaction or unrelated test file was exhaustively audited.

## Starshine compare-pass result

`de-nan` is **not a runnable compare-pass target today**:

- Starshine keeps `de-nan` in the `Removed` registry category; an explicit request is rejected instead of running a transform.
- The compare harness does not admit `--de-nan` in `SUPPORTED_PASS_FLAGS`.
- The current alias map has no `--de-nan` to Binaryen `--denan` mapping.

Therefore a command mentioning `--pass de-nan` fails before input generation or either optimizer executes. That parser rejection is only an admission/status observation. It is not a Binaryen comparison, command-failure result, or parity signal.

## Future admission checklist

A meaningful `denan` lane needs all of the following:

1. an active Starshine module-owned implementation rather than a removed-name rejection;
2. `SUPPORTED_PASS_FLAGS` admission for the chosen local spelling;
3. an explicit local `--de-nan` to upstream `--denan` alias mapping recorded in `result.json`; and
4. a focused generator/profile with a nonzero `--min-compared` threshold covering scalar NaNs, legal global constant replacement, function-only helper calls, entry parameters, fallthrough/local-get skips, helper-name collisions, and a separate SIMD lane.

A canonical-WAT match after those gates would still need dedicated tests for the user-visible behavior change: this pass deliberately converts NaNs to zero rather than merely canonicalizing representations.

## Consumability rule

Use this note for the July 11, 2026 freshness and fuzz-admission claims. Use the older raw captures for `version_129` provenance and historical source detail. The living `de-nan` folder remains the current explanation and port-planning home.
