# Binaryen `signature-pruning` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/signature-pruning/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-05-05 `signature-pruning` wiki-health pass.
It extends, rather than replaces, the earlier tagged-source manifest in [`docs/wiki/raw/binaryen/2026-04-24-signature-pruning-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md) and the 2026-04-26 port-readiness bridge in [`docs/wiki/raw/binaryen/2026-04-26-signature-pruning-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-signature-pruning-port-readiness-primary-sources.md).
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/signature-pruning/index.md`
- `docs/wiki/binaryen/passes/signature-pruning/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/signature-pruning/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/signature-pruning/constant-actuals-localization-and-boundaries.md`
- `docs/wiki/binaryen/passes/signature-pruning/wat-shapes.md`
- `docs/wiki/binaryen/passes/signature-pruning/starshine-strategy.md`
- `docs/wiki/binaryen/passes/signature-pruning/starshine-port-readiness-and-validation.md`

## Official sources consulted

### Binaryen `main`

- `SignaturePruning.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SignaturePruning.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SignaturePruning.cpp>
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- Representative lit surface:
  - `test/lit/passes/signature-pruning.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/signature-pruning.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/signature-pruning.wast>

### Comparison anchors

- `SignaturePruning.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SignaturePruning.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `test/lit/passes/signature-pruning.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/signature-pruning.wast>

## Durable observations

- Current `main` still shows the same GC gate, `--closed-world` gate, table early-return, and two-cycle pass-body structure recorded in `version_129`.
- The reviewed current-main `SignaturePruning.cpp` still uses the same helper chain: `ParamUtils::applyConstantValues(...)`, `ParamUtils::removeParameters(...)`, `GlobalTypeRewriter::updateSignatures(...)`, and delayed `ParamUtils::localizeCallsTo(...)`.
- `pass.cpp` still schedules `signature-pruning` inside the GC + closed-world cluster after `type-refining` and before `signature-refining`.
- The dedicated lit surface still exercises the same teaching families: direct `call`, `call_ref`, `ref.null`, public / tag / continuation / JS / table blockers, and delayed localization.
- No teaching-relevant drift was found in this focused recheck. The 2026-05-05 wiki change is freshness and reference hygiene, not a semantic rewrite of the existing contract.

## Uncertainty and follow-up

- This recheck is source-level and documentation-focused. It does not assert byte-for-byte equivalence between `version_129` and current `main`; it only records that the reviewed public contract and teaching examples did not change in a way that affects Starshine wiki guidance.
- The local Starshine status is unchanged by this source recheck: `signature-pruning` remains boundary-only until a closed-world module pass can rewrite nominal function heap types, direct calls, `call_ref` users, and callee locals coherently.
