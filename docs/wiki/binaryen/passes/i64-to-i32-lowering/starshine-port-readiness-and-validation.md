---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-i64-to-i32-lowering-port-readiness-primary-sources.md
  - ../../../raw/research/0412-2026-04-26-i64-to-i32-lowering-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md
  - ./index.md
  - ./binaryen-strategy.md
  - ./abi-surface-and-opcode-coverage.md
  - ./flatness-helpers-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/lib/util.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../src/validate/typecheck.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flatness-helpers-and-boundaries.md
  - ./abi-surface-and-opcode-coverage.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../flatten/index.md
  - ../legalize-js-interface/index.md
---

# Starshine port readiness and validation for `i64-to-i32-lowering`

This page bridges the source-backed Binaryen dossier to a safe future Starshine implementation plan.
It is **not** an implementation claim: Starshine still rejects `i64-to-i32-lowering` as boundary-only today.

## Current hold point

Keep the pass boundary-only until there is a real module rewrite.

Exact local status:

- [`src/passes/optimize.mbt:135-138`](../../../../../src/passes/optimize.mbt) lists `i64-to-i32-lowering` in `pass_registry_boundary_only_names()`.
- [`src/passes/optimize.mbt:470-473`](../../../../../src/passes/optimize.mbt) rejects boundary-only requests before dispatch.
- [`src/passes/pass_manager.mbt:8671-8683`](../../../../../src/passes/pass_manager.mbt) is the active module-pass dispatch match; it has no `i64-to-i32-lowering` case.
- There is no `src/passes/i64_to_i32_lowering.mbt` owner file.
- No current preset should schedule this pass.

The first implementation PR should therefore start with tests that preserve this truth, then add a guarded module-pass skeleton only when the next sentence becomes true:

> Starshine can classify the module, reject unsupported shapes deterministically, and leave the module byte-for-byte or semantically unchanged when the mutating slice is disabled.

## Why the first slice must be module-level

Binaryen rewrites more than instructions:

- function types and function-section type uses
- params, locals, and local indexes
- defined globals and a synthetic high-bits return global
- direct and indirect call signatures
- `ref.func` heap-visible signatures
- function bodies, memory traffic, and selected helper imports

A HOT-only pass cannot keep those surfaces coherent. HOT IR may help rewrite function bodies later, but the ownership boundary should be a module pass with final module validation.

## First safe Starshine sequence

### Slice 0: registry-honesty tests

Goal: prevent accidental enablement.

Required checks:

- `--pass i64-to-i32-lowering` still reports boundary-only while no owner exists.
- Presets do not expand to this pass.
- `pass_manager.mbt` has no fallback path that can silently accept the name.

Primary files:

- [`src/passes/optimize.mbt:135-138`](../../../../../src/passes/optimize.mbt)
- [`src/passes/optimize.mbt:470-473`](../../../../../src/passes/optimize.mbt)
- [`src/passes/pass_manager.mbt:8671-8683`](../../../../../src/passes/pass_manager.mbt)

### Slice 1: no-rewrite analyzer / classifier

Goal: learn which modules are in the future subset without changing output.

The analyzer should classify at least:

- whether any function type has `i64` params or results
- whether any defined function params/body locals are `i64`
- whether any imported `i64` global exists, which Binaryen still treats as unsupported
- whether any `return_call` / `return_call_indirect` can produce `i64`
- whether any helper-backed family appears: reinterpret, atomic RMW/wait, or atomic cmpxchg
- whether any assumed-gone hard op remains: `i64.mul`, division, remainder, rotates, `popcnt`, or `ctz`

This slice can be validated with reduced WAT fixtures and final module equality. It should not move the public registry entry yet.

Relevant Starshine surfaces:

- [`src/lib/types.mbt:8-27`](../../../../../src/lib/types.mbt) for `I64` and `I64NumType`
- [`src/lib/types.mbt:527-532`](../../../../../src/lib/types.mbt) for call instructions
- [`src/lib/types.mbt:536-540`](../../../../../src/lib/types.mbt) for locals/globals
- [`src/lib/types.mbt:543-565`](../../../../../src/lib/types.mbt) for i64 memory traffic
- [`src/lib/types.mbt:572-585`](../../../../../src/lib/types.mbt) for atomic memory traffic
- [`src/lib/types.mbt:589`](../../../../../src/lib/types.mbt) and [`src/lib/types.mbt:603-690`](../../../../../src/lib/types.mbt) for scalar i64 constants and numeric families

### Slice 2: scalar type/param/local rewrite only

Goal: prove the structural substrate before calls, globals, returns, or helpers.

Allowed input subset:

- defined functions only
- no imported or exported function boundary that would expose the changed ABI
- no direct/indirect calls that mention a rewritten signature
- no `ref.func`
- no `i64` globals
- no `i64` result functions
- no i64 memory, atomic, reinterpret, hard arithmetic, or return-call families

Mutations:

- rewrite function types so each `i64` param becomes low/high `i32` params
- rewrite defined function params and body locals so each original `i64` slot becomes adjacent low/high `i32` slots
- remap `local.get`, `local.set`, and `local.tee` for the scalar local subset
- insert the minimum temps needed to preserve single evaluation if the subset allows tees

Validation:

- Starshine validator succeeds after the rewrite.
- Binary encode/decode roundtrip succeeds.
- A reduced Binaryen oracle lane compares against `wasm-opt --flatten --i64-to-i32-lowering` only for shapes inside the declared subset.

Relevant files:

- [`src/lib/types.mbt:114-118`](../../../../../src/lib/types.mbt) for function types
- [`src/lib/types.mbt:515-690`](../../../../../src/lib/types.mbt) for instruction bodies
- [`src/lib/util.mbt:1-154`](../../../../../src/lib/util.mbt) for `Locals` run rebuild helpers
- [`src/validate/env.mbt`](../../../../../src/validate/env.mbt) for type/global/local lookup environment construction
- [`src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt) for final stack/type validation

### Slice 3: call/signature boundary

Goal: make the changed ABI usable inside a closed reduced module.

Add:

- direct call argument widening
- direct call result narrowing only after the high-half result policy exists
- function-section type-index updates
- `call_indirect` and `ref.func` only after type-use remapping is proven

Do not include imported direct-call retargeting until the JS-interface interaction is specified.
The Binaryen strategy retargets imported calls to `legalfunc$...`, which belongs with the neighboring [`../legalize-js-interface/index.md`](../legalize-js-interface/index.md) story.

### Slice 4: return-high global and defined globals

Goal: add ABI-visible high-half storage deliberately.

Add only after type/local/call validation is green:

- synthetic mutable high-bits return global
- `i64` result lowering through low return plus high global write
- non-imported `i64` global splitting

Still reject imported `i64` globals unless Starshine intentionally implements behavior beyond Binaryen's reviewed contract.

### Slice 5: memory and ordinary numeric families

Goal: expand from structural ABI rewriting into expression lowering.

Suggested order:

1. constants, `eqz`, wrap/extend, bitwise ops
2. add/sub with carry/borrow
3. comparisons
4. shifts
5. non-atomic load/store with single-evaluation pointer temps
6. `select`, `drop`, and narrow unreachable fallback

Use [`./abi-surface-and-opcode-coverage.md`](./abi-surface-and-opcode-coverage.md) as the coverage checklist.

### Slice 6: helper-backed and high-risk families

Do last:

- scratch-memory reinterpret helpers
- wasm2js helper imports
- atomic RMW and wait helpers
- interaction with JS-interface legalization

These families are effectful and module-surface-sensitive. They should not be hidden inside a general “finish the pass” patch.

## Validation ladder

Use the smallest lane that proves the current slice:

1. **Registry lane:** request/category tests prove the pass is not accidentally active.
2. **Analyzer lane:** WAT fixtures classify candidate and unsupported modules without rewriting.
3. **Structural lane:** validation after type/local rewrite; binary encode/decode roundtrip; no helper imports.
4. **Oracle lane:** compare reduced fixtures with `wasm-opt --flatten --i64-to-i32-lowering -S` for supported shapes only.
5. **Negative lane:** imported `i64` globals, `i64` result `return_call`, atomic cmpxchg, and assumed-gone arithmetic families remain explicit errors or unsupported diagnostics.
6. **Helper lane:** only after helper import materialization exists, compare reinterpret and atomic-helper fixtures against Binaryen output.

For fuzzing, start pass-targeted and subset-gated. Do not point arbitrary wasm with every `i64` feature at the pass until unsupported-family diagnostics and helper imports are complete.

## Binaryen-to-Starshine risk map

| Risk | Why it matters | First safe response |
| --- | --- | --- |
| Flatness precondition | Binaryen's official test runs `--flatten --i64-to-i32-lowering` and the owner verifies flatness | require flattened/simple input or run a local flatten-equivalent before mutation |
| Hidden high-half side channel | visible AST carries low half while high half lives in temps | design an explicit Starshine side-channel or structured temp policy before expression lowering |
| Adjacent local slots | Binaryen assumes high local is low index + 1 | rebuild locals centrally through `Locals` helpers and test index remapping |
| Synthetic return global | formerly-`i64` results cross function boundaries | defer i64 result support until global creation and call-result reads are implemented together |
| Helper imports | reinterpret and atomic families are not pure pair lowering | defer to a dedicated helper-import slice |
| Unsupported Binaryen shapes | imported i64 globals and i64 return-call still fail upstream | keep explicit negative tests, not silent no-ops |

## Reader checklist

Before implementing anything, a future contributor should be able to answer:

- Which slice is being implemented?
- Which `i64` families are still rejected?
- Is the pass still boundary-only, or has a real dispatcher case landed?
- Does the final module validate through Starshine's validator?
- Which Binaryen oracle fixtures are in-scope for this slice?
- Did the patch accidentally claim JS-interface, helper-import, or atomic parity before those slices exist?

## Sources

- [`../../../raw/binaryen/2026-04-26-i64-to-i32-lowering-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-i64-to-i32-lowering-port-readiness-primary-sources.md)
- [`../../../raw/research/0412-2026-04-26-i64-to-i32-lowering-port-readiness.md`](../../../raw/research/0412-2026-04-26-i64-to-i32-lowering-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./abi-surface-and-opcode-coverage.md`](./abi-surface-and-opcode-coverage.md)
- [`./flatness-helpers-and-boundaries.md`](./flatness-helpers-and-boundaries.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
