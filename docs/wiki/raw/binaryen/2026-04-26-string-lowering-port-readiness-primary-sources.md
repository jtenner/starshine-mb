---
kind: raw-source
status: supported
last_reviewed: 2026-04-26
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lowering.wast
  - https://github.com/WebAssembly/js-string-builtins/blob/main/proposals/js-string-builtins/Overview.md
  - ../../../binaryen/passes/string-lowering/index.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/wast/keywords.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/ir/hot_lift.mbt
  - ../../../../src/ir/hot_lower.mbt
---

# Binaryen `string-lowering` port-readiness primary-source bridge

## Scope

This source bridge rechecks official Binaryen `version_129` and current `main` sources for details that matter to a future Starshine port of `string-lowering` and its magic-import siblings.

The earlier dossier correctly taught that `string-lowering` is broader than `string-gathering`, but it still left first-slice sequencing, helper-import ABI details, and Starshine local code anchors too implicit for an implementer.

## Official Binaryen facts confirmed on 2026-04-26

- `StringLowering.cpp` still owns both `StringGathering` and `StringLowering`; `StringLowering::run` returns early unless the Strings feature is enabled, runs gathering first, updates types, turns gathered string globals into imports, replaces supported string instructions with helper calls, refinalizes, and disables the Strings feature.
- `StringLowering.cpp` itself cites the WebAssembly stringref and JS string builtins proposals as its specification context.
- The current-main source is still teaching-equivalent to tagged `version_129` for the checked surfaces: no changed phase order, helper import roster, JSON/magic import behavior, or unsupported-op boundary was found.
- `makeImports` keeps three distinct literal paths: default numbered imports under module `string.const` plus a `string.consts` JSON custom section; magic imports under the pass-argument-selected string-constants module when UTF-16-to-UTF-8 conversion succeeds; and assert-mode fatal behavior for non-convertible strings.
- `updateTypes` maps string heap types to extern heap types while preserving nullability. It also manually handles singleton-rec-group function types before invoking `TypeMapper`; the source explicitly says broader public-type cases need more work.
- `replaceInstructions` creates all helper function imports up front under `wasm:js-string`. The helper roster is `fromCharCodeArray`, `fromCodePoint`, `concat`, `intoCharCodeArray`, `equals`, `test`, `compare`, `length`, `charCodeAt`, and `substring`.
- The supported opcode rewrites are intentionally narrow: WTF-16 array construction, code-point construction, concat, WTF-16 array encoding, equality/compare, string test, measure, WTF-16 get, and WTF slice. Other `string.new*` and `string.encode*` families still hit explicit upstream TODO/unreachable paths.
- The JS string builtins proposal backs the `wasm:js-string` namespace, compile-time builtin opt-in, imported string constants, and helper behaviors used by Binaryen's lowered imports.

## Starshine local facts rechecked

- `src/passes/optimize.mbt:118-139` still omits `string-lowering`, `string-lowering-magic-imports`, and `string-lowering-magic-imports-assert` from both boundary-only and removed registry arrays. Requests are unknown today, not intentionally rejected as boundary-only.
- `src/wast/keywords.mbt:101-109`, `src/wast/parser.mbt:2180-2191`, and `src/wast/lower_to_lib.mbt:2389-2399` already parse and lower `string.const` plus several string new/encode array opcodes.
- `src/binary/encode.mbt:2818-2879` already encodes the local string opcode subset, including `string.const` and the array new/encode variants.
- `src/validate/typecheck.mbt:3230-3259` already typechecks `string.const` and the local new/encode array family.
- `src/ir/hot_lift.mbt:1292-1295` and `src/ir/hot_lower.mbt:196-198` already roundtrip `string.const` through HOT constants.
- Starshine still lacks local parser / IR / encoder / validator coverage for Binaryen's broader helper-call source op families such as concat, equality, test, measure, WTF-16 get, and slice. A faithful port cannot be just a pass over already-complete string instructions.

## Corrections this bridge applies to the living dossier

- Promote `string-lowering` from `dossier` to `deep` by adding a dedicated Starshine port-readiness / validation page.
- Make registry honesty the first local slice: today the pass names are unknown, not boundary-only.
- Keep helper imports tied to the JS string builtins contract rather than documenting them as arbitrary host imports.
- Make opcode-surface mismatch explicit: Starshine already supports some source string instructions that Binaryen `string-lowering` treats as unsupported, while Starshine lacks other instructions Binaryen lowers today.
- Treat public-type lowering as an explicit narrow Binaryen contract, not a solved all-public-types mechanism.

## Remaining uncertainty

- This bridge records source behavior, not an implementation request. Starshine still has no owner file, registry category, or active backlog slice for `string-lowering`.
- The JS string builtins proposal is still proposal material; a future Starshine implementation should recheck the proposal and Binaryen source before fixing helper ABI tests.
- If Starshine lands `string-gathering` first, this page should be rechecked because the correct `string-lowering` first mutating slice may become "compose with local gathering" instead of "registry-honesty plus no-op analyzer." 
