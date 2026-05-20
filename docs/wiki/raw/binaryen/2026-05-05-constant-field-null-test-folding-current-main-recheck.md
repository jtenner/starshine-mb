# Binaryen `constant-field-null-test-folding` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/constant-field-null-test-folding/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-05-05 `constant-field-null-test-folding` wiki-health pass.
It extends, rather than replaces, the sibling-specific tagged-source manifest in [`docs/wiki/raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md`](./2026-04-25-constant-field-null-test-folding-primary-sources.md) and the 2026-04-25 research bridge in [`docs/wiki/raw/research/0335-2026-04-25-constant-field-null-test-folding-source-bridge.md`](../research/0335-2026-04-25-constant-field-null-test-folding-source-bridge.md).
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/constant-field-null-test-folding/index.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/two-bucket-subtype-partitions-and-nonnullable-ref-test-gates.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/wat-shapes.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/starshine-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/starshine-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/starshine-port-readiness-and-validation.md`

## Official sources consulted

### Binaryen `main`

- `ConstantFieldPropagation.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ConstantFieldPropagation.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ConstantFieldPropagation.cpp>
  - Relevant lines: the `optimizeUsingRefTest(...)` selector path and its two-bucket / subtype-partition checks remain the same teaching surface as `version_129`.
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - Relevant lines: the public `cfp` / `cfp-reftest` registrations still exist in the closed-world GC/type cluster.
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

- Current `main` still shows the same shared CFP engine contract as `version_129`: GC + closed-world gating, field-fact collection, copy fixed point, ordinary replacement first, and the narrow `ref.test` rescue path only when exactly two usable buckets remain.
- The reviewed current-main `pass.cpp` still keeps the public `cfp` / `cfp-reftest` names in the same closed-world GC/type cluster.
- The reviewed current-main lit files still exercise the same teaching families: impossible reads, ordinary constants, immutable globals, subtype gating, nullable-base repair, packed-field/atomic boundaries, and the sibling `select(ref.test(...))` surface.
- No teaching-relevant drift was found in this focused recheck. The 2026-05-05 wiki change is freshness and reference hygiene, not a semantic rewrite of the contract.

## Uncertainty and follow-up

- This recheck is source-level and documentation-focused. It does not assert byte-for-byte equivalence between `version_129` and current `main`; it only records that the reviewed public contract and teaching examples did not change in a way that affects Starshine wiki guidance.
- The local Starshine status is unchanged by this source recheck: `constant-field-propagation` and `constant-field-null-test-folding` remain boundary-only until a closed-world module pass can rewrite nominal function heap types, field reads, and `ref.test` rescue forms coherently.
