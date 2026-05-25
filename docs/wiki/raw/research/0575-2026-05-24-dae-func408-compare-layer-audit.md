# DAE Func408 compare-layer audit

Date: 2026-05-24

## Question

After the selected Func408 pair-carrier cleanup, `.tmp/dae-func408-pair-if-final2-artifact` still reported the default direct debug-artifact first diff at `defined=336 abs=353`, while manual inspection suggested the raw Func408/abs425 body had reached Binaryen's shape. This note records whether the remaining Func408-looking drift belonged in the DAE raw rewrite layer or in the compare/acceptance layer.

## Inputs

- Input artifact: `tests/node/dist/starshine-debug-wasi.wasm`
- Baseline artifact: `.tmp/dae-func408-pair-if-final2-artifact`
- Diagnostic artifact: `.tmp/dae-func408-canonical-binaryen-artifact`
- Diagnostic command:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/dae-func408-canonical-binaryen-artifact \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --canonicalize-binaryen-output \
  --dae-optimizing
```

## Raw Func408 evidence

Printing absolute function `425` from the final2 raw Starshine artifact and Binaryen output shows the same raw local/control sequence after the selected pair carrier rewrite:

```text
local.get 0; call 43; local.get 0; i32.const 31480; i32.const 42240; call 457;
local.set 3; local.tee 2; local.set 4; local.get 3; local.set 1;
i32.const 1; local.get 0; local.get 4; if I32 (local.get 1) ...;
call 452; call 440
```

The old accepted/normalized Func408 diff came from comparing Binaryen's raw direct pass output against Starshine after the helper canonicalized Starshine through `wasm-opt --strip-debug`. Running `wasm-opt --strip-debug` over Binaryen's direct output produces the same accepted Func408 local/tuple-lowering shape as Starshine, except for type-index numbering.

## Diagnostic compare mode

Commit `aafc412b` added `--canonicalize-binaryen-output` to `scripts/self-optimize-compare.ts`. The flag preserves `binaryen.raw.wasm`, but writes `binaryen.wasm` through the same `wasm-opt --strip-debug` canonicalization path as `starshine.wasm`. The default mode is unchanged and still keeps Binaryen's direct output as the byte-reference artifact.

Under this both-canonical diagnostic mode:

- `.tmp/dae-func408-canonical-binaryen-artifact/starshine.wasm` validates with `wasm-opt --all-features`.
- Pass-local timing stays within target: `1756.838ms` Starshine versus `925.410ms` Binaryen.
- The first both-canonical function diff is `defined=208 abs=225`, not Func408/abs425.
- Func408/abs425 matches after type-id stripping when both outputs are written through the same strip-debug layer.

## Follow-up nop-roundtrip probe

A one-roundtrip input-normalization probe kept the same both-canonical first diff:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/dae-func408-canonical-binaryen-nop1-artifact \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --canonicalize-binaryen-output \
  --binaryen-nop-roundtrips 1 \
  --dae-optimizing
```

Result:

- first diff: `defined=208 abs=225`
- pass-local timing: `1860.901ms` Starshine versus `886.984ms` Binaryen, outside the 2x target for that probe

Because the nop-roundtrip changes the effective input and worsens timing, it is only diagnostic evidence and not an acceptance path.

## Current interpretation

The selected Func408 pair-carrier frontier is closed at the DAE raw rewrite layer. The remaining default helper first diff at `defined=336 abs=353` remains the known raw type-section/type-index representation drift. The former accepted/normalized Func408 local-numbering/tuple-local mismatch should not drive another DAE rewrite unless a future raw-output comparison reopens it.

The first both-canonical diagnostic frontier was `defined=208 abs=225`, a block/result wrapper representation family around a dropped `call $252` followed by a value-block wrapper. Initial inspection showed Binaryen's canonical writer lowers this region to a void block with an explicit dropped final value, while Starshine's canonicalized output preserves a dropped `block (result i32)` wrapper. This was classified only as representation drift; no semantic-safe claim beyond this inspected local shape is made here.

A follow-up canonical-function normalizer for that exact inspected family, plus the unreachable `drop` before `else` left behind after an unconditional branch, advanced the both-canonical diagnostic frontier to `defined=218 abs=235` in `.tmp/dae-func208-canonical-normalized2-artifact`. That artifact validates and stays inside the pass-local 2x target (`1806.078ms` Starshine versus `937.241ms` Binaryen). The new both-canonical frontier is another block/result wrapper family in Func218, not Func408.

## Validation evidence

Commands run after adding the diagnostic mode:

```sh
bun scripts/test/self-optimize-compare-canonical-binaryen-output.ts
bun scripts/test/self-optimize-compare-command.ts
wasm-opt --all-features .tmp/dae-func408-canonical-binaryen-artifact/starshine.wasm \
  -o /tmp/dae-func408-canonical-check.wasm
moon info && moon fmt && moon test
git diff --check
```

`moon test` reported `3433/3433` passing. The `wasm-opt` validation emitted the known local-limit warning for function 518; this warning is not a DAE-output-only regression because the original debug artifact has the same VM-limit issue.
