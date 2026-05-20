# Binaryen `constant-field-propagation` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/constant-field-propagation/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-05-05 `constant-field-propagation` wiki-health pass.
It extends, rather than replaces, the earlier tagged-source manifest in [`docs/wiki/raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md`](./2026-04-24-constant-field-propagation-primary-sources.md) and the 2026-04-24 research follow-up in [`docs/wiki/raw/research/0301-2026-04-24-constant-field-propagation-primary-sources-and-starshine-followup.md`](../research/0301-2026-04-24-constant-field-propagation-primary-sources-and-starshine-followup.md).
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/constant-field-propagation/index.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/copies-subtypes-ref-tests-and-atomics.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/wat-shapes.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/starshine-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/starshine-port-readiness-and-validation.md`

## Official sources consulted

### Binaryen `main`

- `ConstantFieldPropagation.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ConstantFieldPropagation.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ConstantFieldPropagation.cpp>
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- Representative lit surfaces:
  - `cfp.wast`
    - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/cfp.wast>
    - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/cfp.wast>
  - `cfp-reftest.wast`
    - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/cfp-reftest.wast>
    - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/cfp-reftest.wast>

### Comparison anchors

- `ConstantFieldPropagation.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ConstantFieldPropagation.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `cfp.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/cfp.wast>
- `cfp-reftest.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/cfp-reftest.wast>

## Durable observations

- Current `main` still shows the same GC gate, `--closed-world` gate, `PossibleConstantValues` lattice, copy fixed point, and read-rewrite split recorded in `version_129`.
- The reviewed current-main `pass.cpp` still schedules `cfp` / `cfp-reftest` in the closed-world GC/type cluster after `remove-unused-types` and before `gsi`.
- The reviewed current-main lit files still exercise the same teaching families: impossible reads, default and literal values, immutable globals, subtype gating, packed-field repair, atomic boundaries, and the sibling `ref.test` rescue path.
- No teaching-relevant drift was found in this focused recheck. The 2026-05-05 wiki change is freshness and reference hygiene, not a semantic rewrite of the existing contract.

## Uncertainty and follow-up

- This recheck is source-level and documentation-focused. It does not assert byte-for-byte equivalence between `version_129` and current `main`; it only records that the reviewed public contract and teaching examples did not change in a way that affects Starshine wiki guidance.
- The local Starshine status is unchanged by this source recheck: `constant-field-propagation` and `constant-field-null-test-folding` remain boundary-only until a closed-world module pass can rewrite nominal function heap types, field reads, and `ref.test` rescue forms coherently.
