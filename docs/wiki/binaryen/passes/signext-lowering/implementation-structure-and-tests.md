---
kind: concept
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
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `signext-lowering` implementation structure and tests

This page maps the concrete Binaryen and Starshine source surfaces for `signext-lowering`. It is deliberately separate from [`binaryen-strategy.md`](binaryen-strategy.md): strategy explains what the pass does; this page explains which files prove it and which local files a future Starshine port should read.

## Upstream Binaryen owner files

| File | Role | What to learn from it |
| --- | --- | --- |
| `src/passes/SignExtLowering.cpp` | Transform owner | Defines the function-parallel postwalk pass, matches the five sign-extension unary opcodes, builds same-width `shl` + arithmetic `shr_s` replacements, reuses the original child once, replaces the current root, and disables `FeatureSet::SignExt`. |
| `src/passes/pass.cpp` | Public registration | Exposes the public `signext-lowering` pass name and help text. |
| `src/passes/passes.h` | Factory declaration | Declares the `createSignExtLoweringPass()` factory used by pass registration. |
| `test/lit/passes/signext-lowering.wast` | Dedicated proof fixture | Checks the five opcode-to-shift-pair output families. |

There is no hidden second owner file for this pass in the reviewed sources. The implementation does not depend on Binaryen CFG utilities, local graphs, effect analysis, type graphs, module reachability, or profitability scoring.

## Implementation shape

The core owner file has three responsibilities:

1. **Walk functions independently.** Each function body can be rewritten without looking at other functions, globals, tables, memories, or types.
2. **Rewrite matched unary roots.** The five matched operators are `ExtendS8Int32`, `ExtendS16Int32`, `ExtendS8Int64`, `ExtendS16Int64`, and `ExtendS32Int64`. Each replacement is the corresponding storage-width `Shl` followed by signed `ShrS` with shift counts `24`, `16`, `56`, `48`, and `32`.
3. **Clear the feature bit.** After function rewriting, Binaryen disables `FeatureSet::SignExt` on the module.

The child expression is moved into the new left-shift operand. It is not copied into both shifts. This is why the pass does not need an effect analysis to preserve calls, loads, traps, or other effectful children.

## Dedicated Binaryen test surface

`test/lit/passes/signext-lowering.wast` is narrow and useful:

- it runs the pass with sign-extension enabled;
- it includes all five sign-extension opcodes;
- it checks that each output uses the expected `shl` / `shr_s` pair and shift count;
- it keeps i32 and i64 lanes separate.

Evidence caveat: the implementation source proves feature-bit clearing, but this run did not find an explicit target-feature custom-section or printed feature-annotation assertion in the dedicated lit file. Do not cite that fixture alone as proof of feature-section removal. Cite the owner source for the feature side effect and the lit file for instruction-shape output.

## Local Starshine code map

Starshine currently has prerequisite instruction support, not a `signext-lowering` pass.

| Local file | Current evidence | Port relevance |
| --- | --- | --- |
| [`src/passes/optimize.mbt:96-117`](../../../../../src/passes/optimize.mbt) | Boundary-only and removed pass lists omit `signext-lowering`; a repo search also found no `signext` registry entry. | A future port needs a new registry entry only after behavior lands. |
| [`src/passes/optimize.mbt:458-460`](../../../../../src/passes/optimize.mbt) | Unknown pass names fail before expansion. | Today `--pass signext-lowering` should be unknown, not boundary-only. |
| [`src/passes/pass_manager.mbt:8685-8705`](../../../../../src/passes/pass_manager.mbt) | HOT dispatcher lists active HOT passes and has no `signext-lowering` case. | A future instruction-only port could dispatch here; feature cleanup may require module ownership. |
| [`src/wast/types.mbt:454-458`](../../../../../src/wast/types.mbt) | WAT opcode enum includes the five sign-extension opcodes. | Parser-facing prerequisite. |
| [`src/wast/keywords.mbt:328-332`](../../../../../src/wast/keywords.mbt) | Text mnemonics map to those opcode cases. | WAT input prerequisite. |
| [`src/wast/parser.mbt:4987-4994`](../../../../../src/wast/parser.mbt) | Parser test covers all five mnemonics. | Baseline input coverage for future pass tests. |
| [`src/wast/lower_to_lib.mbt:1284-1288`](../../../../../src/wast/lower_to_lib.mbt) | WAT opcodes lower to library instructions. | Bridge from parsed WAT to lib IR. |
| [`src/lib/types.mbt:715-719`](../../../../../src/lib/types.mbt), [`src/lib/types.mbt:3940-3961`](../../../../../src/lib/types.mbt), [`src/lib/types.mbt:5882-5903`](../../../../../src/lib/types.mbt) | Lib instruction and unary-op cases plus constructors exist. | Likely transform-building surface. |
| [`src/binary/encode.mbt:2561-2565`](../../../../../src/binary/encode.mbt) | Binary encoder emits opcode bytes `0xC0` through `0xC4`. | Confirms current binaries can still contain direct sign-extension opcodes. |
| [`src/validate/typecheck.mbt:3464-3468`](../../../../../src/validate/typecheck.mbt), [`src/validate/typecheck.mbt:5482-5521`](../../../../../src/validate/typecheck.mbt) | Typechecker handles and tests the unary same-type stack behavior. | Validation baseline for before/after tests. |
| [`src/ir/hot_lift.mbt:847-851`](../../../../../src/ir/hot_lift.mbt) | HOT lifting classifies all five as unary HOT ops. | Makes a HOT rewrite feasible if feature cleanup is separate. |
| [`src/passes/pick_load_signs.mbt:437-441`](../../../../../src/passes/pick_load_signs.mbt) | Neighboring pass recognizes sign-extension consumers for load-sign selection. | Confirms this should stay separate from `pick-load-signs`. |
| [`src/lib/show.mbt:1317-1321`](../../../../../src/lib/show.mbt) | Pretty-printer currently emits no-underscore spellings like `i32.extend8s`. | Future WAT-golden tests should handle or fix this hygiene issue. |

## Future Starshine test plan

A local port should add focused tests before implementation:

1. one positive for each of the five direct opcode rewrites;
2. effectful-child preservation: a load or call child must appear once in the output;
3. nested sign-extension preservation: the pass may create nested shift pairs and must not pretend to simplify them;
4. negative `i64.extend_i32_s` coverage;
5. validation after rewrite;
6. target-feature metadata behavior if Starshine adds a feature model or target-feature custom-section editing.

The expected Binaryen parity command is still `wasm-opt --signext-lowering`, but local pass-harness comparison only makes sense after Starshine registers a public `signext-lowering` pass name.
