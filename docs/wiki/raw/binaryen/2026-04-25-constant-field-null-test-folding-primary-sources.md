# Binaryen `constant-field-null-test-folding` / upstream `cfp-reftest` primary-source capture

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/constant-field-null-test-folding/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-25 `constant-field-null-test-folding` / upstream `cfp-reftest` provenance and Starshine status bridge.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/constant-field-null-test-folding/index.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/two-bucket-subtype-partitions-and-nonnullable-ref-test-gates.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/wat-shapes.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-25.
  - GitHub showed `kripken` released `version_129` on **2026-04-01 14:31** and that the release tag points at commit `d0e2be9`.

### Official source files consulted

- `ConstantFieldPropagation.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ConstantFieldPropagation.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstantFieldPropagation.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ConstantFieldPropagation.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ConstantFieldPropagation.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `possible-constant.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-constant.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-constant.h>
- `struct-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/struct-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
- `subtypes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/subtypes.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>

### Official test files consulted

- `cfp-reftest.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/cfp-reftest.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/cfp-reftest.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/cfp-reftest.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/cfp-reftest.wast>
- `cfp.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/cfp.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/cfp.wast>
- `gto_and_cfp_in_O.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gto_and_cfp_in_O.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto_and_cfp_in_O.wast>

## Durable observations from the captured sources

- Upstream publishes the variant as `cfp-reftest`; Starshine tracks the descriptive local spelling `constant-field-null-test-folding`.
- `pass.cpp` registers both `cfp` and `cfp-reftest`, and the default closed-world GC/type pass sequence chooses `cfp-reftest` instead of plain `cfp` at high speed optimization levels.
- `ConstantFieldPropagation.cpp` is still the shared engine. The public sibling differs by constructing `ConstantFieldPropagation(true)` rather than a separate analysis pass.
- The engine remains GC-gated and closed-world-only. No-GC modules return without work; open-world execution fatally reports that CFP requires `--closed-world`.
- The variant is entered only when ordinary CFP cannot produce one constant/global replacement and the receiver reference is not exact.
- `optimizeUsingRefTest(...)` tracks at most two values. `version_129` uses a two-slot array plus a `fail` flag; current `main` has the same semantic gate but now returns `false` from the subtype iterator to stop early instead of continuing after failure.
- A value bucket must be tied to a simple testable type set: one bucket side must contain a single candidate type whose immediate-subtype list is empty in the closed-world subtype graph.
- The visible replacement is `select(payload_for_test_type, payload_for_other_side, ref.test(nonnullable-test-type, ref.as_non_null(original-ref)))`, followed by per-function refinalization when anything changed.
- The dedicated `cfp-reftest.wast` lit file proves the public CLI surface with `wasm-opt --cfp-reftest --closed-world -all -S`, positive `select(ref.test(...))` rewrites, nullable-base `ref.as_non_null` repair, no-op `struct.set` tolerance, and negative families where no single `ref.test` can separate the value sets.
- The reviewed current-`main` source did not change the teaching contract above. The notable drift is mechanical: the subtype-iteration failure path now stops early instead of carrying a separate failure flag.
- Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that `constant-field-null-test-folding` is a **boundary-only** registry name with no owner file, no dispatcher case, no preset role, and no active backlog slice.

## Uncertainties and caveats

- This capture does not prove that every `cfp-reftest.wast` assertion is unchanged on current `main`; it records a narrow current-source spot check of the owner file and the continued presence of the same public file paths.
- The local Starshine name emphasizes “null-test folding,” but the upstream sources do not define a generic null-test optimizer. Treat the local name as an alias for the two-value CFP `ref.test` sibling.
- Any future Starshine port must source-confirm the exact feature-gating and validation story in the then-current Binaryen and Wasm GC specifications before promising parity for nonnullable `ref.test` emission.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions for the sibling specifically, cite this raw capture together with the living dossier pages. Use the parent `constant-field-propagation` raw manifest for the ordinary CFP field-analysis engine and this file for the `cfp-reftest` public-name, scheduler, and variant-output details.
