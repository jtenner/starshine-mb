# Binaryen `monomorphize-always` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/monomorphize-always/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `monomorphize-always` follow-up. It is intentionally provenance-heavy rather than explanatory. Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/monomorphize-always/index.md`
- `docs/wiki/binaryen/passes/monomorphize-always/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/monomorphize-always/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/monomorphize-always/usefulness-gate-and-sibling-split.md`
- `docs/wiki/binaryen/passes/monomorphize-always/wat-shapes.md`
- `docs/wiki/binaryen/passes/monomorphize-always/starshine-strategy.md`
- `docs/wiki/binaryen/passes/monomorphize/index.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - Used as the stable release anchor for the reviewed upstream source contract.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24.
  - Used to confirm that `version_129` was still present on the official reviewed release surface for this dossier.

### Official source files consulted

- `Monomorphize.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Monomorphize.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Helper headers shared with the parent `monomorphize` dossier:
  - `cost.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
  - `effects.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - `find_all.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
  - `manipulation.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>
  - `module-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - `names.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
  - `properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - `return-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h>
  - `type-updating.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - `utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
  - `wasm-limits.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-limits.h>

### Official test files consulted

- `monomorphize-types.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/monomorphize-types.wast>
  - This is the direct lit proof that runs `--monomorphize-always` and contrasts it with `--monomorphize --pass-arg=monomorphize-min-benefit@0` on refined-type cases.
- `monomorphize-benefit.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/monomorphize-benefit.wast>
  - This file does **not** run `--monomorphize-always`; it is supporting evidence for the threshold-tuned parent policy, not direct sibling execution proof.
- Shared family tests that still define the inherited legality/clone behavior:
  - `monomorphize-consts.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-consts.wast>
  - `monomorphize-context.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast>
  - `monomorphize-drop.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast>
  - `monomorphize-limits.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-limits.wast>
  - `monomorphize-mvp.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-mvp.wast>
  - `no-inline-monomorphize-inlining.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline-monomorphize-inlining.wast>

## Durable observations from the captured sources

- `Monomorphize.cpp` explicitly describes a testing-oriented variant that always monomorphizes nontrivial callsites without checking whether the nested optimizer can help.
- `Monomorphize` stores an `onlyWhenHelpful` flag; `createMonomorphizePass()` constructs it with `true`, while `createMonomorphizeAlwaysPass()` constructs it with `false`.
- `pass.cpp` registers `monomorphize-always` as a separate public pass name with the description "creates specialized versions of functions (even if unhelpful)".
- The always sibling still shares the parent engine's correctness guards: imported functions, recursive self-calls, unreachable calls, trivial contexts, immovable/effectful context expressions, tuple-param complications, return-call-sensitive dropped-result cases, and `MaxParams` overflow remain bailouts.
- The always sibling still constructs the same clone shape: copy the target function, rebuild the signature from surviving `local.get` operands, turn dropped-result clones into `none` results, repair local indexes and names, prepend reverse-inlined context `local.set`s, run nested function optimization, update the original call, and add the clone when accepted.
- The main correction from this review is lit-surface precision: `monomorphize-types.wast` is the direct `--monomorphize-always` test, while `monomorphize-benefit.wast` only proves the neighboring `monomorphize-min-benefit` policy axis.
- A narrow 2026-04-24 current-`main` spot check on `Monomorphize.cpp`, `pass.cpp`, and `monomorphize-types.wast` did not surface teaching-relevant drift from the tagged `version_129` sibling contract.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
