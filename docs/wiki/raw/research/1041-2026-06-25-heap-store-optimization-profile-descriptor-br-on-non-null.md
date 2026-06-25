# Heap Store Optimization Descriptor `br_on_non_null` Profile Coverage

Date: 2026-06-25

## Summary

Reopened the descriptor branch-result profile blocker from research note `1040` and fixed the underlying Starshine HOT infrastructure issue so direct `--heap-store-optimization` no longer aborts on the exact descriptor `br_on_non_null` / `struct.new_desc` surface.

The deterministic generated root is now committed in the `heap-store-optimization` GenValid profile:

```wat
i32.const 127
ref.null eq
block (result (ref (exact $descriptor)))
  ref.null (exact $descriptor)
  br_on_non_null 0
  unreachable
end
struct.new_desc $described
local.set $local
local.get $local
i32.const 128
struct.set $described 0
```

Binaryen `version_130` folds the later same-field `struct.set` into the `struct.new_desc` for this surface and leaves only its usual HSO `nop` cleanup debris. Starshine now folds the same behavior family and emits validated output.

## Fix

Two HOT representation bugs blocked the generated profile root before HSO could be evaluated:

- `hot_verify_branch_payload_arity` treated `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` like `br_on_null` by subtracting the guard child from branch payload arity. For payload-bearing branch-on-reference forms, the guard is the value transported to the target on the taken edge, so the verifier must count it as branch payload.
- `hot_lower_impl_const` lowered `HotConstPayload::RefNullConst(rt)` through `Instruction::ref_null(rt.get_heap_type())`, which dropped exact-reference metadata. Exact descriptor branch-result blocks lowered to `ref.null $descriptor`, and final validation rejected `br_on_non_null` because the label requires a non-null exact descriptor reference. Lowering now uses `Instruction::ref_null_type(rt)` and preserves exactness.

## Test And Profile Coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt` for the exact descriptor `br_on_non_null` block used as the descriptor operand of `struct.new_desc`. The regression requires the pass to complete without aborting, keep `br_on_non_null` present, fold the later store into `struct.new_desc`, and leave no `struct.set` in the focused output.

Strengthened the HSO profile artifact test in `src/fuzz/main_wbtest.mbt` to require `br_on_non_null` red-first. It failed before the generator update because the dedicated profile lacked that surface, then passed after adding the deterministic exact descriptor branch-result root in `src/validate/gen_valid.mbt`.

## Evidence

- Red focused HSO regression initially failed in HOT verification before HSO ran.
- After the branch-payload verifier fix, the same regression reached HSO but failed final validation because exact `ref.null` metadata was dropped during HOT lowering.
- After the exact `ref.null` lowering fix:
  - `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` passed (`407/407`).
  - `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` passed (`92/92`).
  - `moon fmt` passed.
  - `moon test src/ir` passed (`309/309`).
  - `moon build --target-dir target --target native --release src/cmd` passed with the existing `src/passes/pass_manager.mbt` unused-function warnings and refreshed `target/native/release/build/cmd/cmd.exe`.
  - Manual replay of the former `1040` failure input succeeded and `wasm-tools validate --features all .tmp/hso-desc-branch-result-repro-fixed.wasm` accepted Starshine output.
  - Dedicated profile smoke:
    - `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-desc-branch-result-20-fixed --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`
    - Compared `20/20`; normalized matches `0`; compare-normalized matches `20`; validation/property/generator/command failures `0`; mismatches `0`; Binaryen cache `0` hits / `20` misses.
  - Direct smoke:
    - `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-branch-result-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures`
    - Compared `1000/1000`; normalized matches `1000`; compare-normalized matches `0`; validation/property/generator/command failures `0`; mismatches `0`; Binaryen cache `1000` hits / `0` misses.

## Classification

The `1040` command-failure blocker is fixed for this exact generated descriptor `br_on_non_null` branch-result surface. This is now generated HSO profile coverage, not an accepted deferral.

The broader HSO audit remains open. This slice does not close arbitrary descriptor branch/control expressions, exact descriptor `ref.cast` decode blockers, mutable descriptor result-wrapper old-field variants, broader generated catchable call/ref-call wrappers, performance, O4z slot closeout, or final full compare lanes.
