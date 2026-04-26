# Binaryen `remove-relaxed-simd` port-readiness primary-source recheck

_Capture date:_ 2026-04-26  
_Status:_ immutable focused source manifest for `docs/wiki/binaryen/passes/remove-relaxed-simd/`

## Scope

This manifest keeps the existing `remove-relaxed-simd` dossier current and adds a port-readiness framing for Starshine. It does not replace the broader 2026-04-24 manifest or the 2026-04-25 correction; it narrows the remaining implementation questions to child-effect preservation, result-context validation, Binaryen-vs-Starshine dot-product spelling, and local registry honesty.

Living pages updated from this source:

- `docs/wiki/binaryen/passes/remove-relaxed-simd/index.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/wat-shapes.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/starshine-strategy.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/starshine-port-readiness-and-validation.md`

## Primary sources rechecked

### Official Binaryen owner file

- `src/passes/RemoveRelaxedSIMD.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveRelaxedSIMD.cpp>
  - raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RemoveRelaxedSIMD.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveRelaxedSIMD.cpp>
  - Reviewed current-main surfaces:
    - the file still describes the pass as replacing relaxed SIMD instructions with traps;
    - `RemoveRelaxedSIMD` is still a function-parallel `WalkerPass<PostWalker<RemoveRelaxedSIMD>>`;
    - `replace(...)` still creates a `ChildLocalizer` replacement block, appends `unreachable`, and replaces the current expression;
    - `visitUnary`, `visitBinary`, and `visitSIMDTernary` still enumerate relaxed opcode families by arity;
    - `visitFunction(...)` still refinalizes the walked function in the module;
    - no feature-section cleanup step was found in the reviewed owner file.

### Official Binaryen dedicated test

- `test/lit/passes/remove-relaxed-simd.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-relaxed-simd.wast>
  - raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/remove-relaxed-simd.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-relaxed-simd.wast>
  - Reviewed current-main surfaces:
    - the test still runs `wasm-opt %s -all --remove-relaxed-simd -S -o -`;
    - expected output still shows relaxed expressions becoming blocks ending in `unreachable`;
    - the fixture imports an effectful helper and remains the best official starting point for reduced child-localization tests;
    - ordinary SIMD neighbor preservation remains a lit-backed part of the contract.

### Proposal context

- WebAssembly relaxed SIMD proposal overview: <https://github.com/WebAssembly/relaxed-simd/blob/main/proposals/relaxed-simd/Overview.md>
- Proposal repository: <https://github.com/WebAssembly/relaxed-simd>

The proposal overview remains supporting context, not the pass contract. It explains that relaxed SIMD adds instructions with local nondeterminism and implementation-defined result choices; Binaryen's pass-specific response is the owner-file trap replacement above.

## Starshine code surfaces rechecked

These local surfaces make the pass realistic to port later, but no pass is implemented today:

- `src/passes/optimize.mbt:126-151` - boundary-only and removed registries do not include `remove-relaxed-simd`.
- `src/passes/optimize.mbt:455-461` - unknown requested names fail with `unknown pass flag`.
- `src/wast/types.mbt:720-740` - relaxed SIMD opcode enum coverage.
- `src/wast/keywords.mbt:440-468` - current Starshine WAT spelling, including `i16x8.relaxed_dot_i8x16_i7x16_s` and `i32x4.relaxed_dot_i8x16_i7x16_add_s`.
- `src/binary/encode.mbt:3792-3814` and `src/binary/decode.mbt:3783-3813` - opcode `0xfd` relaxed-SIMD encode/decode coverage.
- `src/validate/typecheck.mbt:3710-3729` and `src/validate/typecheck.mbt:9573-9790` - v128 unary/binary/ternary typechecking and focused tests.
- `src/ir/hot_lift.mbt:1178-1198` and `src/ir/hot_lower.mbt:1091` - relaxed SIMD lifts into HOT `Simd` payloads and lowers by replaying the stored instruction.
- `src/lib/show.mbt:2106-2113` - current pretty-printer spelling still omits some underscores in relaxed dot-product names; keep this as a port-readiness caveat before WAT roundtrip tests.

## Durable takeaways

- The safe first Starshine slice is registry honesty plus a classifier over the 20 relaxed SIMD instruction variants; it should not start by inventing deterministic replacements.
- A faithful rewrite needs a `ChildLocalizer` equivalent or another proof that side-effecting children are evaluated before the trap.
- The pass should validate typed `v128` result contexts after replacement; `unreachable` makes the value side possible, but local writeback/lowering still needs proof.
- The dot-product spelling split is now important enough to be a pre-port decision: either add Binaryen-compatible aliases or document that local WAT tests must use current Starshine spellings while Binaryen oracle tests use Binaryen spellings.
- Feature metadata remains an uncertainty. The reviewed Binaryen owner source proves expression replacement and refinalization, not target-feature custom-section stripping.
