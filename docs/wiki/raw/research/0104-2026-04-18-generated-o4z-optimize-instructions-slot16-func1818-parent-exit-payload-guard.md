# 0104 - Generated `-O4z` slot 16 `optimize-instructions` `Func 1818` split parent-exit payload guard

## Status

- Date: 2026-04-18
- Type: One-off raw investigation
- Resolves: [0095 - slot 16 early `optimize-instructions` final-validate underflow](./0095-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-stack-underflow.md)
- Follows: [0103 - slot 16 `Func 652` carrier-wrapper guard follow-up](./0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md)
- Related later blocker: [0100 - slot 44 later `optimize-instructions` `Func 1818` stack underflow](./0100-2026-04-18-generated-o4z-optimize-instructions-slot44-func1818-stack-underflow.md)

## Scope

- Selected backlog item: `[O4Z]002`
- Replay input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm`
- Reduced witness: extracted `Func 1818` from that predecessor
- Implemented fix: `src/ir/hot_lower.mbt`
- Focused regressions:
  - `src/cmd/cmd_wbtest.mbt`
  - `src/ir/hot_lower_test.mbt`

## Binaryen / oracle behavior

Authoritative intent still comes from Binaryen's `OptimizeInstructions` pass plus direct oracle replay:

- Binaryen source oracle: `src/passes/OptimizeInstructions.cpp` in the upstream Binaryen repository (`version_129` tag is the local toolchain version reported by `wasm-opt --version`) - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp>
- Local oracle replay:
  - `bun scripts/self-optimize-compare.ts .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .artifacts/o4z002-slot16-compare --optimize-instructions`

Observed oracle result:

- Binaryen's `optimize-instructions` replay on the full slot-16 predecessor stays valid.
- The saved compare after the fix reports `Normalized WAT equal: yes` and `Canonical function compare equal: yes` for the full slot-16 replay.
- The relevant peephole is still the expected `if (x == 0)` / `eqz`-style arm flip, not a larger structural rewrite. The invalidity came from Starshine's post-pass HOT lowering, not from Binaryen wanting an extra typed carrier block.

## Reproduction before the fix

### Full slot-16 replay

- `_build/native/release/build/cmd/cmd.exe --optimize-instructions --out .artifacts/tmp-direct-optimize-instructions-failure.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm > .artifacts/tmp-direct-optimize-instructions-failure.log 2>&1`
- `grep -E 'final module validate|Offending function idx' .artifacts/tmp-direct-optimize-instructions-failure.log`

Pre-fix result after [0103]:

- `error: final module validate: stack underflow`
- `Offending function idx=(Func 1818)`

### Extracted `Func 1818` witness

- `_build/native/release/build/cmd/cmd.exe --extract-functions 1818 --out .artifacts/o4z002-f1818-input.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm`
- `_build/native/release/build/cmd/cmd.exe --optimize-instructions --dump .artifacts/o4z002-f1818-after.wat .artifacts/o4z002-f1818-input.wasm`
- `wasm-tools validate .artifacts/o4z002-f1818-after.wat`

Pre-fix validator result on the extracted witness:

- `func 15 failed to validate`
- `type mismatch: expected i32 but nothing on stack`

## Root cause

The remaining slot-16 `Func 1818` failure was another HOT-lower carrier-wrapper bug, but in a different helper from [0103].

The bad rewrite was in `hot_lower_impl_try_pack_split_parent_exit_payload(...)` in `src/ir/hot_lower.mbt`.

That helper packs this valid lowered shape:

- typed parent block body containing one void wrapper root
- wrapper body shaped as:
  - `block (Void) { <prefix-body> }`
  - `<payload>`
  - `br 1`

into a more compact form that inserts a new inner `block (result T)` around `<prefix-body>` plus `<payload>`.

That packing is only safe when `<prefix-body>` does **not** still branch to the wrapper label one level out.

In the slot-16 `Func 1818` witness, `optimize-instructions` flipped an `if (x == 0)` condition into the direct-`if` form with swapped arms. That left the lowered prefix body with nested branches that still targeted the wrapper label one level out. `hot_lower_impl_try_pack_split_parent_exit_payload(...)` then inserted a fresh typed carrier block without rebasing those deeper relative branch depths. One nested `br 3` that used to land on the void wrapper now landed on the newly inserted typed block, but carried no `i32` payload, which caused the final stack-underflow validation failure.

## Fix

Added the same safety condition used for the earlier slot-16 carrier bug, but at the split-parent-exit packing site:

- refuse the pack when `hot_lower_impl_body_targets_removed_label(prefix_body, 1)` is true

That keeps the original valid unpacked wrapper shape whenever child exits still target the wrapper label that the pack would shadow with a new typed block.

## Validation after the fix

Focused regressions:

- `moon test --target native --package jtenner/starshine/ir --file hot_lower_test.mbt --filter '*parent-exit*'`
- `moon test --target native --package jtenner/starshine/cmd --file cmd_wbtest.mbt --index 114-116`

Direct slot replay and extracted witness:

- `moon build --target native --release --package jtenner/starshine/cmd`
- `_build/native/release/build/cmd/cmd.exe --optimize-instructions --out .artifacts/o4z002-slot16-fixed.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm`
- `wasm-tools validate .artifacts/o4z002-slot16-fixed.wasm`
- `_build/native/release/build/cmd/cmd.exe --extract-functions 1818 --out .artifacts/o4z002-f1818-input.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm`
- `_build/native/release/build/cmd/cmd.exe --optimize-instructions --out .artifacts/o4z002-f1818-fixed.wasm .artifacts/o4z002-f1818-input.wasm`
- `wasm-tools validate .artifacts/o4z002-f1818-fixed.wasm`

Oracle parity replay:

- `bun scripts/self-optimize-compare.ts .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .artifacts/o4z002-slot16-compare --optimize-instructions`

Observed post-fix result:

- the full slot-16 replay exits `0`
- the emitted wasm validates successfully
- the compare harness reports `Normalized WAT equal: yes`
- `[O4Z]002` is retired

## Durable takeaways

- The slot-16 `Func 1818` failure was not the later slot-44 `Func 1818` family resurfacing unchanged; it was an earlier, separate HOT-lower split-payload packing bug that only happened to crash in the same function family.
- `hot_lower_impl_try_pack_split_parent_exit_payload(...)` needs the same "child exits still target the parent" conservatism that already proved necessary in `hot_lower_impl_stackify_wrapped_struct_set_prefixes(...)`.
- The ordered-audit lesson is broader than this one slot: any HOT-lower optimization that inserts a new typed carrier between an existing prefix body and its former wrapper must first prove that nested branches do not still target the wrapper label being shadowed.

## Files changed in this slice

- `src/ir/hot_lower.mbt`
- `src/ir/hot_lower_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

## Supporting evidence

- Saved audit input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm`
- Saved compare output: `.artifacts/o4z002-slot16-compare/`
- Extracted witness input: `.artifacts/o4z002-f1818-input.wasm`
- Fixed extracted witness output: `.artifacts/o4z002-f1818-fixed.wasm`
- Fixed full slot-16 output: `.artifacts/o4z002-slot16-fixed.wasm`
