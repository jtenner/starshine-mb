# Heap Store Optimization Descriptor `br_on_non_null` Profile Blocker

Date: 2026-06-25

## Summary

Attempted to add a deterministic generated HSO profile root for the still-open descriptor branch-result / `br_on_non_null` surface. The candidate shape used an exact descriptor-producing block as the descriptor operand of `struct.new_desc`:

```wat
i32.const 127
ref.null eq
block (result (ref (exact 12)))
  ref.null (exact 12)
  br_on_non_null 0
  unreachable
end
struct.new_desc 11
local.set 3
local.get 3
i32.const 128
struct.set 11 0
```

The local GenValid artifact validated and Binaryen `version_130` accepted `--heap-store-optimization`, but Starshine's direct pass command aborted on every generated candidate in the 20-case smoke. The generated profile root was therefore not committed; it remains a blocker rather than covered generated profile surface.

## Evidence

- Red/probe test: temporarily strengthened `src/fuzz/main_wbtest.mbt` to require `br_on_non_null`; the focused fuzz test failed before the generator attempt because the profile artifact lacked that surface.
- Generator attempt: temporarily added the descriptor block-result root above to `src/validate/gen_valid.mbt`. The first implementation used a non-exact descriptor block result and failed GenValid selection with `type mismatch`; changing the block result to non-null exact descriptor and using `ref.null (exact descriptor)` made the focused fuzz test pass locally.
- Dedicated profile smoke with the generated root failed as Starshine command failures, so the root was reverted before commit:
  - `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-desc-branch-result-20-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`
  - Result: compared `0/20`; command failures `20`; command failure class `starshine-command-failed=20`; validation, property, generator, and mismatch counts were `0`.
- Manual replay on the first failure input reproduced the Starshine abort:
  - `target/native/release/build/cmd/cmd.exe --heap-store-optimization --out .tmp/hso-desc-branch-result-repro.wasm .tmp/pass-fuzz-heap-store-optimization-profile-desc-branch-result-20-rerun/failures/case-000001-gen-valid/input.wasm; echo exit:$?`
  - Result: process aborted with exit `134`.
- The same input is a valid Binaryen oracle input:
  - `wasm-opt --version` reported `wasm-opt version 130 (version_130)`.
  - `wasm-opt --all-features --heap-store-optimization .tmp/pass-fuzz-heap-store-optimization-profile-desc-branch-result-20-rerun/failures/case-000001-gen-valid/input.wasm -o .tmp/hso-desc-branch-binaryen.wasm` succeeded.
  - `wasm-tools validate --features all .tmp/hso-desc-branch-binaryen.wasm` succeeded.

## Classification

This is a Starshine command-failure blocker for generated profile coverage, not a semantic-safe output difference and not a Binaryen/tool failure. The branch-result descriptor surface remains open for HSO-D/F/H/G until Starshine can run direct HSO over the candidate without aborting and the resulting transform family is classified against Binaryen behavior.

## Reopening Criteria

Reopen this profile slice when the direct Starshine command no longer aborts on `.tmp/pass-fuzz-heap-store-optimization-profile-desc-branch-result-20-rerun/failures/case-000001-gen-valid/input.wasm` or an equivalent reduced descriptor `br_on_non_null` / `struct.new_desc` fixture. Then re-add the profile root test-first, rerun focused fuzz tests, rebuild the explicit native compare binary, and run the 20-case dedicated-profile smoke plus a direct smoke before documenting it as generated coverage.
