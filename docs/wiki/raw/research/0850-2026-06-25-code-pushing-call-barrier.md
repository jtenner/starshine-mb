---
kind: research
status: supported
created: 2026-06-25
sources:
  - ../../../binaryen/passes/code-pushing/segment-selection-and-barriers.md
  - ../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/passes/code_pushing_test.mbt
---

# Code Pushing Call Barrier Before `br_if`

## Question

Does Binaryen v130 move a pure SFA `local.set` across an intervening call before a later `br_if` push point?

This slice targets the current `version_130` source drift from coarse invalidation toward `effects.orderedBefore(cumulativeEffects)` and the remaining `[O4Z-AUDIT-CP]` ordered-window / EH-call barrier surface.

## Binaryen probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe input: `.tmp/o4z-audit-cp-yy/cannot-push-past-call.wat`.

```wat
(module
  (func $callee)
  (func (local $x i32)
    (block $out
      (local.set $x (i32.const 1))
      (call $callee)
      (drop (i32.const 1))
      (br_if $out (i32.const 2))
      (drop (local.get $x)))))
```

Commands:

```sh
wasm-tools parse .tmp/o4z-audit-cp-yy/cannot-push-past-call.wat -o .tmp/o4z-audit-cp-yy/cannot-push-past-call.wasm
wasm-tools validate --features all .tmp/o4z-audit-cp-yy/cannot-push-past-call.wasm
wasm-opt --version
wasm-opt --all-features .tmp/o4z-audit-cp-yy/cannot-push-past-call.wat --code-pushing -S -o .tmp/o4z-audit-cp-yy/cannot-push-past-call.opt.wat
```

Binaryen accepted and validated the probe, then kept `local.set $x (i32.const 1)` before the intervening `call $callee`; it did not sink the set after the later `br_if` push point.

## Starshine change

This was a focused parity fix, not an accepted boundary. The first focused Starshine test failed red because Starshine moved the pure const set after the `br_if` despite the intervening call.

Starshine now treats call/throw effects in the roots between a single-set candidate and its push point as an ordered segment barrier. This keeps the movement subset aligned with the Binaryen v130 probe while preserving the already source-backed `drop(global.get)` separator families.

While running the full focused `*code-pushing*` filter, an adjacent regression surfaced in the generated-prefix `br_on_non_null` helper: it could move loop-label `br_on_non_null` shapes that are documented as stationary boundaries. The helper now explicitly requires a block-label target, matching the original prefix-payload implementation scope and preserving the loop-label boundary tests.

## Tests

Updated focused coverage in `src/passes/code_pushing_test.mbt`:

- added `code-pushing boundary keeps SFA set before call barrier and br_if push point`;
- extended the local HOT op assertion helper with `call` support;
- reused the existing loop-label `br_on_non_null` boundary test as the regression guard for the generated-prefix helper's block-label gate.

The call-barrier test is commented as intentionally unsupported/Binaryen-stationary at the movement boundary, but the implementation change is a parity fix because the prior Starshine behavior moved across the call where Binaryen v130 did not.

## Validation

- `wasm-tools parse .tmp/o4z-audit-cp-yy/cannot-push-past-call.wat -o .tmp/o4z-audit-cp-yy/cannot-push-past-call.wasm`: passed.
- `wasm-tools validate --features all .tmp/o4z-audit-cp-yy/cannot-push-past-call.wasm`: passed.
- `wasm-opt --version`: `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features .tmp/o4z-audit-cp-yy/cannot-push-past-call.wat --code-pushing -S -o .tmp/o4z-audit-cp-yy/cannot-push-past-call.opt.wat`: passed; Binaryen kept the pure set before the call and later `br_if`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*call barrier*'`: failed before implementation with the set moved after the later `br_if`, then passed after the barrier fix.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*code-pushing*'`: passed `79/79` after also restoring the `br_on_non_null` loop-label boundary.
- `moon build --target native --release src/cmd`: passed with pre-existing unused-function warnings.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-all-call-barrier-1000-20260625 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures`: compared `1000/1000`, normalized `466`, cleanup-normalized `534`, raw mismatches `0`, validation/generator/property failures `0`, command failures `0`, Binaryen cache `1000 hits/0 misses`, and Binaryen failures `0 hits/0 misses`.

No GenValid leaf was added because this slice blocks an over-broad movement and documents a source-backed stationary call barrier. Because behavior changed, the previous 10000-case dedicated `code-pushing-all` lane is now closeout-progress evidence rather than final-current evidence; rerun a full 10000 dedicated lane before final closeout or before relying on a fully refreshed matrix.

## Reopening criteria

Reopen this boundary if a future Binaryen source/lit refresh shows call/throw-crossing segment movement for pure values, if Starshine gains a more precise effect-ordering proof that can demonstrate a narrower safe crossing accepted by Binaryen, or if direct compare exposes call/EH-attributable mismatches. Keep loop-label `br_on_non_null` prefix-payload movement closed unless Binaryen v130-equivalent evidence shows a positive loop-label family.
