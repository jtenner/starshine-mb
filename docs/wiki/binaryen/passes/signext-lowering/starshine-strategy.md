---
kind: strategy
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-signext-lowering-implementation-test-map-source-correction.md
  - ../../../raw/binaryen/2026-04-25-signext-lowering-primary-sources.md
  - ../../../raw/research/0359-2026-04-25-signext-lowering-implementation-test-map.md
  - ../../../raw/research/0349-2026-04-25-signext-lowering-source-dossier.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/wast/types.mbt
  - ../../../../../src/wast/keywords.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/passes/pick_load_signs.mbt
  - ../../../../../src/lib/show.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../pick-load-signs/starshine-hot-ir-strategy.md
  - ../optimize-instructions/starshine-hot-ir-strategy.md
---

# Starshine strategy for `signext-lowering`

Starshine currently has sign-extension **instruction support**, but no `signext-lowering` **pass**.

This page maps what exists today, what is missing, and how a faithful future port should differ from neighboring sign-extension-aware optimizations.

## Current public-pass status

As of 2026-04-25:

- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) does not include `signext-lowering` in active, module, boundary-only, removed, or preset registry lists.
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) has no module or HOT dispatcher case for `signext-lowering`.
- A user request for `--pass signext-lowering` should therefore behave like an unknown pass, not like a known-but-rejected boundary-only pass.
- There is no `src/passes/signext_lowering.mbt` owner file and no dedicated backlog slice found during this run.

## Existing local instruction surfaces

These files are prerequisites a future pass can reuse:

| Surface | Current code location | Why it matters |
| --- | --- | --- |
| WAT opcode enum | [`src/wast/types.mbt:454-458`](../../../../../src/wast/types.mbt) | Declares `I32Extend8S`, `I32Extend16S`, `I64Extend8S`, `I64Extend16S`, and `I64Extend32S`. |
| WAT keywords | [`src/wast/keywords.mbt:328-332`](../../../../../src/wast/keywords.mbt) | Maps textual mnemonics such as `i32.extend8_s` to opcode enum cases. |
| Parser coverage | [`src/wast/parser.mbt:4987-4994`](../../../../../src/wast/parser.mbt) | Has a focused `parse sign extension` test for all five opcodes. |
| WAT-to-lib lowering | [`src/wast/lower_to_lib.mbt:1284-1288`](../../../../../src/wast/lower_to_lib.mbt) | Converts WAT opcode cases to `@lib.Instruction` constructors. |
| Library IR | [`src/lib/types.mbt:715-719`](../../../../../src/lib/types.mbt), [`src/lib/types.mbt:3940-3961`](../../../../../src/lib/types.mbt), [`src/lib/types.mbt:5882-5903`](../../../../../src/lib/types.mbt) | Provides instruction cases, unary-op cases, and constructor helpers like `Instruction::i32_extend8s()`. |
| Binary encoding | [`src/binary/encode.mbt:2561-2565`](../../../../../src/binary/encode.mbt) | Emits sign-extension opcode bytes `0xC0` through `0xC4`. |
| Type checking | [`src/validate/typecheck.mbt:3464-3468`](../../../../../src/validate/typecheck.mbt), [`src/validate/typecheck.mbt:5482-5521`](../../../../../src/validate/typecheck.mbt) | Treats and tests sign-extension as unary same-type operations: `i32 -> i32` and `i64 -> i64`. |
| HOT lifting | [`src/ir/hot_lift.mbt:847-851`](../../../../../src/ir/hot_lift.mbt) | Classifies all five sign-extension instructions as unary HOT ops. |
| Neighboring pass logic | [`src/passes/pick_load_signs.mbt:437-441`](../../../../../src/passes/pick_load_signs.mbt) | Recognizes sign-extension consumers when deciding whether narrow loads should become signed loads. |

These surfaces are necessary but not sufficient. None of them rewrites sign-extension opcodes into shifts or clears a target-feature requirement.

## Local caveats found during source mapping

- [`src/lib/show.mbt:1317-1321`](../../../../../src/lib/show.mbt) currently prints sign-extension mnemonics without underscores, such as `i32.extend8s`. Binaryen and WAT syntax use `i32.extend8_s`. Treat this as WAT-output hygiene to verify before writing any roundtrip-oriented `signext-lowering` tests.
- The repository search did not find a Binaryen-like `FeatureSet::SignExt` model. Starshine preserves opaque custom sections in the binary layer, so a faithful port must decide whether feature removal means deleting or rewriting a `target_features` custom section, adding a feature model, or documenting instruction-only lowering as an intentional divergence.

## Future implementation shape

A source-faithful Starshine port should be a small whole-function or HOT unary rewrite pass:

1. Walk function bodies.
2. Match the five sign-extension instructions.
3. Replace each matched node with the corresponding `shl` + arithmetic `shr_s` tree.
4. Preserve the original child expression exactly once.
5. Validate the function/module after rewriting.
6. Remove or update sign-extension feature metadata if Starshine exposes it.

The pass should probably be separate from `optimize-instructions` and `pick-load-signs`. Those passes already reason about sign-extension as an optimization fact. Binaryen `signext-lowering` has the opposite purpose: remove sign-extension opcodes even if the lowered shift pairs are less compact.

## Candidate code landing zone

A future port would likely add:

- `src/passes/signext_lowering.mbt` for the transform;
- `src/passes/signext_lowering_test.mbt` for the five opcode families and effectful-child cases;
- a registry entry in `src/passes/optimize.mbt` only after behavior is implemented;
- a dispatcher hook in `src/passes/pass_manager.mbt` or the module-pass lane, depending on whether feature metadata cleanup becomes module-owned;
- CLI/registry tests if the pass becomes a known public name.

If feature metadata cleanup is required, the pass should be module-owned even though instruction rewriting itself can be function-local.

## Validation plan for a future port

Minimum focused tests:

- `i32.extend8_s` -> `i32.shl` / `i32.shr_s` with shift count `24`;
- `i32.extend16_s` -> shift count `16`;
- `i64.extend8_s` -> shift count `56`;
- `i64.extend16_s` -> shift count `48`;
- `i64.extend32_s` -> shift count `32`;
- effectful child appears once;
- `i64.extend_i32_s` remains unchanged;
- output validates;
- feature metadata is removed or explicitly documented as unsupported.

Then compare against Binaryen:

```sh
wasm-opt --signext-lowering input.wasm -o expected.wasm
starshine --pass signext-lowering input.wasm -o actual.wasm
```

Use the repo-standard pass parity harness only after the pass is wired as a known pass name.

## Relationship to existing Starshine passes

- [`../pick-load-signs/starshine-hot-ir-strategy.md`](../pick-load-signs/starshine-hot-ir-strategy.md) should continue to own load-sign selection based on sign-extension consumers.
- [`../optimize-instructions/starshine-hot-ir-strategy.md`](../optimize-instructions/starshine-hot-ir-strategy.md) should continue to own simplification of sign-extension-related arithmetic patterns.
- `signext-lowering` should own only feature removal: replacing direct sign-extension opcodes with MVP-compatible arithmetic shift pairs.
