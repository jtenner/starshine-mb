---
kind: entity
status: supported
last_reviewed: 2026-06-02
sources:
  - ../../../raw/binaryen/2026-06-02-string-lifting-current-main-recheck.md
  - ../../../raw/research/0697-2026-06-02-string-lifting-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-05-string-lifting-current-main-recheck.md
  - ../../../raw/research/0457-2026-05-05-string-lifting-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md
  - ../../../raw/research/0385-2026-04-26-string-lifting-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md
  - ../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md
  - ../../../raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md
  - ../../../raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md
  - ../string-lowering/index.md
  - ../string-gathering/index.md
  - ../../../strings/string-const-surface.md
  - ../../../../../src/passes/optimize.mbt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./import-and-call-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../string-lowering/index.md
  - ../string-gathering/index.md
  - ../../../strings/string-const-surface.md
  - ../tracker.md
---

# `string-lifting`

## Role

- `string-lifting` is an upstream-only Binaryen module transformation pass.
- It is currently **unimplemented** in Starshine.
- It is a real public pass in Binaryen `version_129`, but it is **not** part of Starshine's current no-DWARF parity queue.
- Its job is to lift imported JavaScript-string constants and helper calls back into wasm-string instructions.

## Why this dossier exists

The wiki already had dedicated pages for:

- [`string-gathering`](../string-gathering/index.md)
- [`string-lowering`](../string-lowering/index.md)

Both mentioned `string-lifting`, but the pass had no stable page.
That left a confusing gap: readers could see that Binaryen exposes a bidirectional string family, but could not tell what the upward direction actually rewrites.

This dossier closes that gap.

## Beginner summary

A good beginner model is:

1. a module imports string constants and JavaScript string helper functions,
2. `string-lifting` recognizes the known import shapes,
3. it replaces those imports/calls with wasm string instructions such as `string.const`, `string.concat`, or string measurement/slicing operations,
4. it enables the Strings feature and refinalizes changed functions.

That is the opposite direction from [`string-lowering`](../string-lowering/index.md), which lowers wasm strings back into imports and `externref`-shaped operations.

## Inputs

The pass looks for two main input families:

- imported string globals:
  - magic imports from the configured string-constants module;
  - numbered imports from module `string.const` plus a `string.consts` JSON custom section.
- imported helper functions under module `wasm:js-string` with exact expected signatures; a recognized helper name with the wrong expected type is a fatal Binaryen pass error, not a preserved-call bailout.

## Outputs

When a shape is accepted, Binaryen emits wasm-string instructions:

- `string.const`
- `string.new_wtf16_array`
- `string.from_code_point`
- `string.concat`
- `string.encode_wtf16_array`
- `string.eq` / `string.compare` / `string.test`
- `string.measure_wtf16`
- `stringview_wtf16.get_codeunit`
- `stringview_wtf16.slice`

Binaryen also removes the consumed `string.consts` custom section and enables the Strings feature.

## Correctness constraints

- Import identity matters. Wrong modules and unknown helper bases must not be lifted; recognized helper bases with wrong expected signatures must fail rather than silently preserve a call.
- Literal bytes matter. Magic-import string bases and JSON `string.consts` payloads must map to the exact replacement `string.const` bytes.
- Function refinalization is required after lifting because helper-call types are `externref`-shaped while lifted instructions produce or consume string types.
- Module-code expressions matter too; the pass is not only a function-body walk.
- The upstream source contains an explicit cast-repair TODO for generated string inputs. Do not teach or port this as if it already inserts all needed `ref.cast` repairs.

## Notable edge cases

- A helper import with the right base but the wrong signature is a fatal Binaryen pass error.
- Unknown `wasm:js-string` helper names produce a warning in Binaryen rather than a rewrite.
- Imports from the wrong module stay untouched.
- The JSON `string.consts` path is source-confirmed, but the direct `string-lifting.wast` lit proof is stronger for magic imports and helper calls.
- `string-lifting` is not a string optimizer by itself; it makes imported string operations visible to later Binaryen string-aware optimizations.

## Validation guidance

For Binaryen parity research:

- run `wasm-opt --string-lifting --enable-all -S` on cases with magic string imports and `wasm:js-string` helper calls;
- verify wrong-module and unknown-helper cases remain imports/calls, but recognized helper names with wrong signatures fail the pass;
- verify lifted functions refinalize and the module has the Strings feature enabled;
- if testing JSON constants, include a `string.consts` custom section paired with numbered `string.const` imports.

For Starshine work:

- first add honest registry handling if the pass is tracked locally;
- add module-pass tests before implementation;
- start with the magic-import `global.get -> string.const` slice before JSON custom-section or helper-call work;
- keep the pass out of active presets until parser/type/model coverage includes the full lifted output surface.

See [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the first-slice order, prerequisite code map, and validation ladder.

## Current-main drift check

A 2026-06-02 focused spot check against current `main` for `StringLifting.cpp`, `string-lifting.wast`, and pass registration did not reveal teaching-relevant drift from the `version_129` source contract described here, including the recognized-helper wrong-signature fatal behavior, module-code walk, `string.consts` custom-section removal, Strings feature enablement, and cast-repair TODO.
Treat that as a narrow freshness check, not a proof that every helper edge case is unchanged forever.
See [`../../../raw/binaryen/2026-06-02-string-lifting-current-main-recheck.md`](../../../raw/binaryen/2026-06-02-string-lifting-current-main-recheck.md) for the source manifest and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the local implementation ladder.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Source-backed Binaryen algorithm, phase order, family split, and open cast TODO.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Owner-file and test-map page for `StringLifting.cpp`, `pass.cpp`, `passes.h`, `string-utils.h`, and `string-lifting.wast`.
- [`./import-and-call-shapes.md`](./import-and-call-shapes.md)
  Beginner-to-advanced transformed-shape catalog with before/after examples and bailout cases.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact current Starshine status and code-location map for the missing pass plus reusable string plumbing.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Future-port checklist: registry honesty, local opcode prerequisites, magic-import first slice, JSON/helper follow-on slices, cast-policy decision, and validation ladder.

## Sources

- [`../../../raw/binaryen/2026-06-02-string-lifting-current-main-recheck.md`](../../../raw/binaryen/2026-06-02-string-lifting-current-main-recheck.md)
- [`../../../raw/research/0697-2026-06-02-string-lifting-current-main-recheck.md`](../../../raw/research/0697-2026-06-02-string-lifting-current-main-recheck.md)
- [`../../../raw/binaryen/2026-05-05-string-lifting-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-string-lifting-current-main-recheck.md)
- [`../../../raw/research/0457-2026-05-05-string-lifting-current-main-recheck.md`](../../../raw/research/0457-2026-05-05-string-lifting-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md)
- [`../../../raw/research/0385-2026-04-26-string-lifting-port-readiness.md`](../../../raw/research/0385-2026-04-26-string-lifting-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md`](../../../raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md)
- [`../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md`](../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md)
- [`../../../raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md`](../../../raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md)
- [`../../../raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md`](../../../raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLifting.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lifting.wast>
