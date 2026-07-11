---
kind: concept
status: supported
last_reviewed: 2026-07-10
sources:
  - ../../../raw/binaryen/2026-07-10-signext-lowering-current-main-refresh.md
  - ../../../raw/binaryen/2026-05-06-signext-lowering-current-main-line-anchor-refresh.md
  - ../../../raw/research/0510-2026-05-06-signext-lowering-current-main-line-anchor-refresh.md
  - ../../../raw/binaryen/2026-05-05-signext-lowering-current-main-recheck.md
  - ../../../raw/research/0466-2026-05-05-signext-lowering-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-signext-lowering-port-readiness-primary-sources.md
  - ../../../raw/research/0396-2026-04-26-signext-lowering-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-signext-lowering-implementation-test-map-source-correction.md
  - ../../../raw/binaryen/2026-04-25-signext-lowering-primary-sources.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/wast/types.mbt
  - ../../../../../src/wast/keywords.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/passes/pick_load_signs.mbt
  - ../../../../../src/lib/show.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../pick-load-signs/index.md
  - ../optimize-instructions/index.md
---

# `signext-lowering` Starshine port readiness and validation

This page is the implementation bridge for a future Starshine `signext-lowering` port. It assumes the reader has the overview in [`index.md`](index.md), the upstream mechanics in [`binaryen-strategy.md`](binaryen-strategy.md), and the concrete before/after shapes in [`wat-shapes.md`](wat-shapes.md).

## Current local state

Starshine currently supports sign-extension instructions but does **not** expose Binaryen's `signext-lowering` pass.

- [`src/passes/optimize.mbt:126-153`](../../../../../src/passes/optimize.mbt) lists boundary-only and removed passes; `signext-lowering` is absent.
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) contains no `signext-lowering` dispatcher case.
- There is no `src/passes/signext_lowering.mbt` owner file and no dedicated `signext-lowering` test file in `src/passes/`.
- A request for `--pass signext-lowering` should therefore still be treated as an unknown pass until a real transform lands.

The important positive news is that the opcode substrate already exists:

| Surface | Current code location | Port use |
| --- | --- | --- |
| WAT opcode enum | [`src/wast/types.mbt:471-475`](../../../../../src/wast/types.mbt) | The five direct opcodes are representable. |
| Text keywords | [`src/wast/keywords.mbt:345-349`](../../../../../src/wast/keywords.mbt) | WAT input uses canonical underscore spellings. |
| Parser classification | [`src/wast/parser.mbt:2149-2153`](../../../../../src/wast/parser.mbt) | Parsed direct opcodes are unary operations. |
| WAT-to-lib lowering | [`src/wast/lower_to_lib.mbt:1306-1310`](../../../../../src/wast/lower_to_lib.mbt) | Parsed opcodes enter lib IR. |
| Lib instruction cases | [`src/lib/types.mbt:771-775`](../../../../../src/lib/types.mbt) | A pass can build or match the opcode families. |
| Binary encode/decode | [`src/binary/encode.mbt:2563-2567`](../../../../../src/binary/encode.mbt), [`src/binary/decode.mbt:3019-3023`](../../../../../src/binary/decode.mbt) | Direct opcodes roundtrip today. |
| Validation | [`src/validate/typecheck.mbt:4033-4037`](../../../../../src/validate/typecheck.mbt) | Before and after forms are same-width integer operations. |
| HOT lifting | [`src/ir/hot_lift.mbt:900-904`](../../../../../src/ir/hot_lift.mbt) | A HOT rewrite is feasible for instruction lowering. |
| Neighboring analysis | [`src/passes/pick_load_signs.mbt:437-441`](../../../../../src/passes/pick_load_signs.mbt) | Confirms sign-extension consumers already matter to other passes, but do not belong to this pass. |

## Recommended first slice

Implement the first Starshine slice as an instruction-lowering pass with an explicit feature-admission decision:

1. Define the enabled-path admission rule. Binaryen returns without rewriting when `FeatureSet::SignExt` is absent; Starshine cannot claim full parity while silently applying a different policy.
2. Match only `I32Extend8S`, `I32Extend16S`, `I64Extend8S`, `I64Extend16S`, and `I64Extend32S` on that enabled path.
3. Replace each with the exact Binaryen shift pair from [`wat-shapes.md`](wat-shapes.md).
4. Move the original child expression under the new left shift exactly once.
5. Use signed right shift (`shr_s`), never logical right shift.
6. Validate the rewritten function/module.
7. Keep target-feature metadata unchanged only if the first slice explicitly documents that instruction-only policy; otherwise add a real local feature model and cleanup.

That first slice is useful because it removes direct sign-extension opcodes from executable code, which is the highest-risk behavior. It should not be described as full Binaryen parity until the feature side effect is either implemented or intentionally documented as unsupported.

## Tests to write first

Add reduced tests before implementation:

| Test | Expected output |
| --- | --- |
| `i32.extend8_s` | `i32.shl` + `i32.shr_s` with `i32.const 24`. |
| `i32.extend16_s` | `i32.shl` + `i32.shr_s` with `i32.const 16`. |
| `i64.extend8_s` | `i64.shl` + `i64.shr_s` with `i64.const 56`. |
| `i64.extend16_s` | `i64.shl` + `i64.shr_s` with `i64.const 48`. |
| `i64.extend32_s` | `i64.shl` + `i64.shr_s` with `i64.const 32`. |
| Effectful child | The child appears once under the left shift. |
| Nested sign extension | Both opcodes lower; no cleanup is required in this pass. |
| `i64.extend_i32_s` / `i64.extend_i32_u` negative | Numeric width conversions remain unchanged. |
| Validation | Rewritten output validates after the pass. |
| Feature metadata | Either no claim of metadata parity, or an explicit target-feature cleanup assertion. |

Prefer structural lib/HOT assertions for the first red tests. If tests compare printed WAT, account for the current pretty-printer hygiene issue in [`src/lib/show.mbt:1317-1321`](../../../../../src/lib/show.mbt), which prints no-underscore spellings such as `i32.extend8s`.

## Binaryen oracle comparison

Once the pass is public locally, compare against upstream with:

```sh
wasm-opt --signext-lowering input.wasm -o expected.wasm
starshine --pass signext-lowering input.wasm -o actual.wasm
```

For fuzz/parity harness use, treat this as a narrow feature-lowering pass. Do not combine it with `optimize-instructions` or `pick-load-signs` in the first signoff, because those neighbors may erase or introduce nearby sign-extension patterns for different reasons.

## Full-parity checklist

Before calling the port Binaryen-complete, verify:

- every direct sign-extension opcode is gone from transformed reachable and unreachable bodies alike;
- no child expression is duplicated or reordered;
- generated shift pairs use same-width constants and signed right shifts;
- width-changing numeric conversions remain untouched;
- output validates;
- the pass is registered only after behavior exists;
- target-feature metadata handling is either implemented or documented as an intentional Starshine divergence.

## Cross-page map

- [`binaryen-strategy.md`](binaryen-strategy.md) explains why Binaryen needs only local expression context plus module feature clearing.
- [`wat-shapes.md`](wat-shapes.md) lists the concrete before/after shapes.
- [`implementation-structure-and-tests.md`](implementation-structure-and-tests.md) maps upstream owner/test files and local prerequisite surfaces.
- [`starshine-strategy.md`](starshine-strategy.md) records the current local non-implementation status and future landing zones.
- [`../pick-load-signs/index.md`](../pick-load-signs/index.md) and [`../optimize-instructions/index.md`](../optimize-instructions/index.md) own adjacent optimization behavior, not feature lowering.
