---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md
  - ../../../raw/research/0385-2026-04-26-string-lifting-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md
  - ../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md
  - ../../../raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md
  - ../../../raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./import-and-call-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Binaryen `string-lifting` implementation structure and tests

## Why this page exists

`string-lifting` can sound like a hidden mode of [`string-lowering`](../string-lowering/index.md), but Binaryen implements it as its own pass file and public pass.
This page maps the source ownership and proof surface so readers know which claims are source-backed, which are lit-backed, and which remain source-only boundaries.

## Source ownership map

| File | What it proves |
| --- | --- |
| `src/passes/StringLifting.cpp` | Main pass: imported string-global discovery, `string.consts` JSON parsing, helper import roster and signature checks, wrong-signature fatal behavior for recognized helpers, global-get/call rewrites, per-function refinalization, module-code walk, Strings feature enable, and `createStringLiftingPass()` |
| `src/passes/pass.cpp` | Public pass registration for `string-lifting` beside `string-gathering` and `string-lowering*` siblings |
| `src/passes/passes.h` | Pass factory declaration surface |
| `src/passes/string-utils.h` | Shared module-name constants such as `wasm:js-string`, default string constants module, and `string.consts` section naming |
| `test/lit/passes/string-lifting.wast` | Direct lit proof for magic-import constants, recognized `wasm:js-string` helpers, and wrong-module / wrong-name negatives |

Primary URLs are captured in [`../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md`](../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md).

## `StringLifting.cpp`

The implementation has three teaching-important parts.

### 1. Module pass setup

The `StringLifting` pass stores:

- the configured string-constants module name;
- a map from imported global names to literal payloads;
- a set of recognized imported helper functions.

This is module-scope state, not per-function peephole state.

### 2. Discovery before rewrite

Before rewriting function bodies, the pass discovers all relevant imports:

- magic string globals from the configured constants module;
- numbered `string.const` globals paired with the `string.consts` JSON custom section;
- known `wasm:js-string` helper functions with exact expected signatures.

This pre-scan is a correctness requirement because function rewrites need stable global/helper maps. The recognized-helper signature check is not a soft bailout: source review on 2026-04-25 confirmed that a known helper base with the wrong expected type is fatal.

### 3. `StringApplier` rewrite walk

The nested applier owns the expression-level changes:

- `visitGlobalGet(...)` replaces recognized imported string globals with `StringConst`.
- `visitCall(...)` replaces recognized helper calls with wasm string instructions.

The same applier is used for function bodies and later for module code.

## Refinalization and feature repair

`StringLifting.cpp` refinalizes modified functions after the applier walks them.
That is where expression annotations are made coherent after replacing external helper calls with string-typed operations.

At the module level, the pass enables the Strings feature after lifting.
That is part of the pass contract, not a scheduler afterthought.

## Direct test file: `string-lifting.wast`

The dedicated lit file is the strongest direct proof for these families:

- magic imported constants become `string.const`;
- repeated uses of the same imported constant lift repeatedly;
- the supported `wasm:js-string` helpers lower to their wasm string instruction counterparts;
- wrong module names do not lift;
- unknown helper names do not lift; recognized helper names with mismatched signatures are source-confirmed fatal errors, not preserved-call negatives.

The file is also useful because it shows the actual printed operation names for Binaryen `version_129`, including the proposal-era `stringview_wtf16.*` spelling used for view-based operations.

## Source-backed but less directly isolated in the lit output

The JSON `string.consts` path is source-confirmed in `StringLifting.cpp` and is the natural inverse of default [`string-lowering`](../string-lowering/index.md), but the direct `string-lifting.wast` proof is more visibly focused on magic imports and helper calls.

Treat the JSON path as supported by source review, not as a heavily exercised dedicated-output family in the reviewed lit file.

## Current-main check

A 2026-04-26 focused spot check of:

- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLifting.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/string-lifting.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>

found no teaching-relevant drift from the tagged `version_129` surfaces reviewed for this page, including the recognized-helper wrong-signature fatal behavior, module-code walk, custom-section removal, and public pass registration. The durable capture is [`../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md).

## Validation matrix for future work

A future Starshine implementation should have at least:

| Test family | Required assertion |
| --- | --- |
| magic imported global | `global.get` becomes `string.const` with exact payload |
| JSON imported global | numbered `string.const` import plus `string.consts` section becomes exact `string.const` |
| helper call positives | every supported helper maps to the expected string instruction |
| wrong module | call/global remains unchanged |
| wrong signature for recognized helper | pass reports an error / fatal fixture matches Binaryen behavior |
| module-code expression | global initializer or other module expression is also rewritten |
| feature repair | output module records Strings feature |
| cast TODO boundary | port either preserves upstream limitation honestly or explicitly repairs it with tests |

## Sources

- [`../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md)
- [`../../../raw/research/0385-2026-04-26-string-lifting-port-readiness.md`](../../../raw/research/0385-2026-04-26-string-lifting-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md`](../../../raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md)
- [`../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md`](../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md)
- [`../../../raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md`](../../../raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md)
- [`../../../raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md`](../../../raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLifting.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lifting.wast>
