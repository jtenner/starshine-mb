# 0103 - Generated `-O4z` slot 16 `optimize-instructions` `Func 652` carrier-wrapper guard follow-up

## Status

- Date: 2026-04-18
- Type: One-off raw investigation
- Resolves the `Func 652` portion of: [0095 - slot 16 early `optimize-instructions` final-validate underflow](./0095-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-stack-underflow.md)
- Related later blocker: [0100 - slot 44 later `optimize-instructions` `Func 1818` stack underflow](./0100-2026-04-18-generated-o4z-optimize-instructions-slot44-func1818-stack-underflow.md)
- Related paired pass note: [0097 - slot 23 `vacuum` `Func 652` stack underflow](./0097-2026-04-18-generated-o4z-vacuum-slot23-func652-stack-underflow.md)

## Scope

- Selected backlog item: `[O4Z]002`
- Replay input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm`
- Reduced witness extracted from that input: `.artifacts/o4z002-f652-input.wasm`
- Implemented fix: `src/ir/hot_lower.mbt`
- Focused regressions:
  - `src/ir/hot_lower_test.mbt`
  - `src/passes/optimize_instructions_test.mbt`

## Binaryen / oracle behavior

Authoritative Binaryen intent for this slot still comes from the `OptimizeInstructions` pass itself plus the actual `wasm-opt version 125` replay:

- Source oracle: `OptimizeInstructions.cpp` in Binaryen `version_125` (`visitIf` / condition canonicalization in the upstream pass source) - <https://github.com/WebAssembly/binaryen/blob/version_125/src/passes/OptimizeInstructions.cpp>
- Local oracle replay used here:
  - `wasm-opt .artifacts/o4z002-f652-input.wasm --optimize-instructions --all-features -o .artifacts/o4z002-f652-binaryen.wasm`

Observed oracle result on the extracted `Func 652` witness:

- Binaryen simplified the `i32.eqz`-style condition to a direct `if` by swapping arms.
- Binaryen **did not** wrap the surrounding void carrier block in a new `block (result i32)`.
- The carrier path stayed valid because branches that still targeted the parent exit block kept the same relative depth and never had to synthesize an `i32` payload.

That matters because Starshine's failing native replay was not an `optimize-instructions` peephole mismatch in the rewritten `if` itself. The invalidity came later during HOT lowering / stackification after the pass mutation.

## Reproduction before the fix

### Original saved-slot replay

- `_build/native/release/build/cmd/cmd.exe --optimize-instructions --out .artifacts/tmp-direct-optimize-instructions-failure.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm`
- Original failure from [0095]: `error: final module validate: stack underflow`, `Offending function idx=(Func 652)`.

### Reduced extracted witness

- Extract the offender:
  - `_build/native/release/build/cmd/cmd.exe --extract-functions 652 --out .artifacts/o4z002-f652-input.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm`
- Reproduce the failure on the isolated module:
  - `_build/native/release/build/cmd/cmd.exe --optimize-instructions --dump .artifacts/o4z002-f652-after.wat .artifacts/o4z002-f652-input.wasm`
- `wasm-tools validate .artifacts/o4z002-f652-after.wat` then failed with:
  - `func 0 failed to validate`
  - `type mismatch: expected i32 but nothing on stack`

### Minimal in-tree reduction

The extracted witness reduced to this pass-level shape, now checked in as a regression:

```wat
(module
  (func (param i32 i32) (result i32)
    (local i32)
    (block $outer
      (block $mid
        (local.get 0)
        (i32.const 0)
        (i32.eq)
        (if
          (then (br $outer))
          (else
            (local.get 1)
            (if
              (then (i32.const 7) (local.set 2) (br $mid))
              (else (br $outer)))
            unreachable))
        unreachable)
      (local.get 2)
      (local.set 1)
      (local.get 1)
      return)
    (i32.const 0)))
```

Before the fix, `optimize-instructions` rewrote the condition and then HOT lowering re-emitted the carrier as:

- `block (result i32)` containing the old void wrapper plus `local.get 2`
- followed by `local.set 1`

That new typed block sat between the child control and the original parent exit target. One branch that still intended to exit the parent block now landed on the newly typed carrier instead, without an `i32` payload, which caused the final stack-underflow validation failure.

## Root cause

The bad rewrite was in `hot_lower_impl_stackify_wrapped_struct_set_prefixes(...)` in `src/ir/hot_lower.mbt`.

That helper opportunistically stackified this lowering pattern:

- `block (Void) { <prefix> unreachable }`
- `local.get <source>`
- `local.set <target>`

into a typed wrapper block feeding `local.set` directly.

The pre-fix guard only checked:

- source local differs from target local
- the source local is not read again later

That was too weak. It missed the case where the prefix body still contained branches that targeted the **parent** label one depth out. Inserting a new typed wrapper changes those relative label depths unless the rewrite is proven safe. In the reduced slot-16 witness, the branch depths were no longer equivalent after stackification, so the new `block (result i32)` demanded a payload from a branch that originally exited a void parent.

## Fix

Added one more safety guard before stackifying wrapped `local.set` prefixes:

- `!hot_lower_impl_body_targets_removed_label(prefix_body, 1)`

This keeps the old non-stackified form whenever the prefix body still branches to the parent label that would be shadowed by the inserted typed wrapper.

## Validation after the fix

Focused red/green regressions:

- `moon test src/ir --filter 'hot lower keeps wrapped local.set prefixes void when child exits still target the parent'`
- `moon test src/passes --filter 'optimize-instructions keeps wrapped local.set prefixes void when child exits still target the parent'`

Extracted witness replay:

- `moon build --target native --release --package jtenner/starshine/cmd`
- `_build/native/release/build/cmd/cmd.exe --optimize-instructions --out .artifacts/o4z002-f652-fixed.wasm .artifacts/o4z002-f652-input.wasm`
- `wasm-tools validate .artifacts/o4z002-f652-fixed.wasm`

Observed post-fix result:

- the extracted `Func 652` witness now exits `0`
- the emitted wasm validates successfully
- the earlier slot-16 `Func 652` underflow is retired

## Remaining blocker on the full slot-16 replay

The full slot-16 input is **not** green yet.

After fixing the `Func 652` carrier-wrapper bug, the same direct replay now advances further and fails later with:

- `error: final module validate: stack underflow`
- `Offending function idx=(Func 1818)`

That means `[O4Z]002` is no longer blocked by the original `Func 652` bug from [0095]. It is now blocked by the same deeper `Func 1818` underflow family already documented later in [0100], and possibly shared with the later `vacuum` / `optimize-instructions` `Func 1818` failures.

Inference from the current evidence:

- the `Func 652` failure was a real HOT-lower stackification bug, not just a symptom of a generally broken slot-16 predecessor state
- fixing it surfaces a second independent failure family rather than making slot 16 fully green
- the next correct follow-up is to reduce the newly surfaced slot-16 `Func 1818` path and reconcile it against the existing later `Func 1818` notes before retiring `[O4Z]002`

## Files changed in this slice

- `src/ir/hot_lower.mbt`
- `src/ir/hot_lower_test.mbt`
- `src/passes/optimize_instructions_test.mbt`

## Supporting evidence

- Saved audit input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm`
- Reduced extracted witness: `.artifacts/o4z002-f652-input.wasm`
- Pre-fix failing dump: `.artifacts/o4z002-f652-after.wat`
- Fixed extracted replay output: `.artifacts/o4z002-f652-fixed.wasm`
- Full post-fix slot-16 replay log: `.artifacts/o4z002-replay-fixed.log`
