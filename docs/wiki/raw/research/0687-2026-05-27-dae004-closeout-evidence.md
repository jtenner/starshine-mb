# DAE004 closeout evidence

Date: 2026-05-27

## Scope

Close `[DAE]004` / selected result-removal broadening after notes `0662` through `0686` retired the large-artifact handpicked selected dropped-result fallback list. This was a recovery/closeout slice: no optimizer behavior changed in this run.

## Evidence

- Focused pass suite: `moon test src/passes --target native` passed (`1474/1474`).
- Default debug-artifact replay: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing --out-dir .tmp/dae004-closeout-default-20260527` completed. Starshine output validated with `wasm-opt --all-features .tmp/dae004-closeout-default-20260527/starshine.wasm -o /tmp/dae004-closeout-default-validated.wasm` with only the existing large-local-count VM warning.
- Both-canonical debug-artifact replay: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --canonicalize-binaryen-output --dae-optimizing --out-dir .tmp/dae004-closeout-canonical-20260527` completed.
- Timing-only repeats stayed inside the project pass-local target (`Starshine <= 2x Binaryen`):
  - `.tmp/dae004-closeout-timing1-20260527`: Starshine pass `1334.819ms`, Binaryen pass `861.787ms`.
  - `.tmp/dae004-closeout-timing2-20260527`: Starshine pass `1344.274ms`, Binaryen pass `846.053ms`.
- Standard direct compare refresh with DAE normalizers: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --max-failures 1000 --out-dir .tmp/pass-fuzz-dae004-closeout-20260527-full` reported `9975/10000` compared, `6078` exact normalized matches, `3824` cleanup-normalized matches, `73` remaining mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures (`22` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, `1` `binaryen-invalid-tag-index`).

## Classification

- The default and both-canonical artifact first diff is now `defined=198 abs=215`. The inspected diff is Starshine materializing a uniform `i32.const 10000` into callee `216` and removing that dead constant actual from caller `215`, while Binaryen keeps the parameterized form. This is a semantic-safe, size-winning DAE003-style constant-actual materialization difference, not a dropped-result scheduling or selected-fallback gap.
- The 73 remaining direct compare mismatches are classified as semantic-safe/size-winning cleanup drift. Sampled gen-valid mismatches such as `case-000086-gen-valid` and `case-001920-gen-valid` are Starshine deleting large dropped pure/nontrapping constant/comparison debris that Binaryen preserves; this is the same accepted raw-cleanup family covered by the DAE normalizer policy, with no validation failures.
- The 25 command failures are Binaryen/parser/tool failures, not Starshine semantic failures.

## Conclusion

`[DAE004-H]` and `[DAE004-I]` are closed for the current v0.1.0 surface. The handpicked selected dropped-result fallback list is empty/gated off for the debug-artifact DAE004 surface, formerly selected fixtures continue to pass through the fact/core path, artifact timing remains within target, and no remaining artifact or fuzz mismatch is attributable to a true dropped-result scheduling/fallback coverage gap.
