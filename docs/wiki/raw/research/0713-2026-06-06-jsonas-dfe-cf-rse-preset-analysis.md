# 0713 - json-as DFE / Code-Folding / RSE Preset Analysis

Date: 2026-06-06

## Scope

Analyze the proposed `json-as` size-parity suffix after the current public `--optimize -O4` lane:

```text
--duplicate-function-elimination -> --remove-unused-module-elements ->
--code-folding -> --redundant-set-elimination ->
--remove-unused-module-elements
```

This note uses the existing fresh-clone debug artifacts in `.tmp/json-as-f707d68/build/starshine-debug/` and the local native Starshine binary at `target/native/release/build/cmd/cmd.exe`. It does not modify the untracked restored wasm artifacts under `examples/modules/`.

## Inputs

Fresh-clone debug inputs:

- `.tmp/json-as-f707d68/build/starshine-debug/medium.bench.incremental.naive.debug.wasm`
- `.tmp/json-as-f707d68/build/starshine-debug/medium.bench.incremental.simd.debug.wasm`
- `.tmp/json-as-f707d68/build/starshine-debug/large.bench.incremental.swar.debug.wasm`

Binaryen comparison outputs already present from the same clone:

- `.tmp/json-as-f707d68/build/wasmopt-check/medium.bench.incremental.naive.wasmoptO4.wasm`
- `.tmp/json-as-f707d68/build/wasmopt-check/medium.bench.incremental.simd.wasmoptO4.wasm`
- `.tmp/json-as-f707d68/build/wasmopt-check/large.bench.incremental.swar.wasmoptO4.wasm`

## Commands

Generate current Starshine O4 baseline and candidate outputs:

```sh
rm -rf .tmp/jsonas-rse-analysis && mkdir -p .tmp/jsonas-rse-analysis
for f in .tmp/json-as-f707d68/build/starshine-debug/{medium.bench.incremental.naive,medium.bench.incremental.simd,large.bench.incremental.swar}.debug.wasm; do
  base=$(basename "$f" .debug.wasm)
  target/native/release/build/cmd/cmd.exe \
    --traps-never-happen --closed-world --optimize -O4 \
    -o ".tmp/jsonas-rse-analysis/$base.starshine-o4.wasm" "$f"
  target/native/release/build/cmd/cmd.exe \
    --traps-never-happen --closed-world --optimize -O4 \
    --duplicate-function-elimination --remove-unused-module-elements \
    -o ".tmp/jsonas-rse-analysis/$base.starshine-o4-dfe.wasm" "$f"
  target/native/release/build/cmd/cmd.exe \
    --traps-never-happen --closed-world --optimize -O4 \
    --duplicate-function-elimination --remove-unused-module-elements \
    --code-folding --redundant-set-elimination --remove-unused-module-elements \
    -o ".tmp/jsonas-rse-analysis/$base.starshine-o4-dfe-cf-rse.wasm" "$f"
done
```

Validate:

```sh
wasm-tools validate --features all .tmp/jsonas-rse-analysis/*.wasm
```

Runtime smoke, using the temporary host shim at `.tmp/jsonas-dfe-cf-rse-smoke/run-smoke.mjs`:

```sh
node .tmp/jsonas-dfe-cf-rse-smoke/run-smoke.mjs \
  .tmp/jsonas-rse-analysis/*.starshine-o4.wasm \
  .tmp/jsonas-rse-analysis/*.starshine-o4-dfe.wasm \
  .tmp/jsonas-rse-analysis/*.starshine-o4-dfe-cf-rse.wasm
```

Direct pass compare evidence used to qualify the candidate passes:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass duplicate-function-elimination \
  --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris \
  --out-dir .tmp/pass-fuzz-dfe-jsonas-signoff-10000 \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe

bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass code-folding \
  --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris \
  --out-dir .tmp/pass-fuzz-code-folding-jsonas-signoff-10000 \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe

bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass redundant-set-elimination \
  --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris \
  --out-dir .tmp/pass-fuzz-rse-loop-entry-fix-10000 \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

## Runtime result

All generated Starshine outputs validated and completed the Node `start` export smoke:

- `*.starshine-o4.wasm`: all three completed.
- `*.starshine-o4-dfe.wasm`: all three completed.
- `*.starshine-o4-dfe-cf-rse.wasm`: all three completed.

A prior run before commit `5ab3b53ae` trapped on `medium.bench.incremental.simd.wasm` when `redundant-set-elimination` was present. The fix keeps raw RSE from treating a loop's default local writes as redundant unless the incoming loop-entry value is already the same default. The focused regression is `rse raw path keeps default reset in loop when entry value may differ` in `src/passes/rse_test.mbt`.

## Section metrics

Section sizes/counts were collected with `wasm-tools objdump`; `file` is the total wasm byte size.

| Artifact | Variant | File | Types | Funcs | Globals | Code bytes | Data bytes | Custom bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| medium naive | Starshine O4 | 168703 | 29 | 276 | 38 | 127998 | 25312 | 14541 |
| medium naive | O4 + DFE + RUME | 152589 | 29 | 211 | 38 | 126499 | 25312 | 0 |
| medium naive | O4 + DFE + RUME + CF + RSE + RUME | 152193 | 29 | 211 | 38 | 126103 | 25312 | 0 |
| medium naive | Binaryen O4 | 112097 | 17 | 66 | 36 | 86249 | 25314 | 0 |
| medium simd | Starshine O4 | 159778 | 29 | 279 | 38 | 134843 | 24088 | 0 |
| medium simd | O4 + DFE + RUME | 158214 | 29 | 214 | 38 | 133345 | 24088 | 0 |
| medium simd | O4 + DFE + RUME + CF + RSE + RUME | 157815 | 29 | 214 | 38 | 132946 | 24088 | 0 |
| medium simd | Binaryen O4 | 114249 | 17 | 67 | 36 | 89624 | 24090 | 0 |
| large swar | Starshine O4 | 379023 | 28 | 314 | 35 | 320801 | 41617 | 15735 |
| large swar | O4 + DFE + RUME | 358826 | 28 | 261 | 35 | 316400 | 41617 | 0 |
| large swar | O4 + DFE + RUME + CF + RSE + RUME | 357809 | 28 | 261 | 35 | 315383 | 41617 | 0 |
| large swar | Binaryen O4 | 251672 | 17 | 63 | 34 | 209532 | 41619 | 0 |

## Incremental deltas

Against Starshine O4 baseline, the full candidate suffix wins:

- medium naive: `168703 -> 152193` (`-16510` bytes), function count `276 -> 211`, code `-1895` bytes, custom `-14541` bytes.
- medium simd: `159778 -> 157815` (`-1963` bytes), function count `279 -> 214`, code `-1897` bytes, no custom-section change.
- large swar: `379023 -> 357809` (`-21214` bytes), function count `314 -> 261`, code `-5418` bytes, custom `-15735` bytes.

The incremental CF+RSE contribution after `O4 + DFE + RUME` is smaller but consistent:

- medium naive: `152589 -> 152193` (`-396` bytes), code `-396` bytes.
- medium simd: `158214 -> 157815` (`-399` bytes), code `-399` bytes.
- large swar: `358826 -> 357809` (`-1017` bytes), code `-1017` bytes.

DFE is the large suffix contributor here because it removes duplicate functions and currently strips the `name` custom section as part of its metadata/name canonicalization. That means this suffix partially covers the debug custom-section gap for these artifacts, but it is not a substitute for an explicit `strip-debug` pass when DFE is not otherwise scheduled.

## Remaining gap versus Binaryen O4

Even after the suffix, Starshine remains far from Binaryen's O4 output on function/type/code counts:

- medium naive candidate versus Binaryen: `211` vs `66` functions, `29` vs `17` types, `126103` vs `86249` code bytes.
- medium simd candidate versus Binaryen: `214` vs `67` functions, `29` vs `17` types, `132946` vs `89624` code bytes.
- large swar candidate versus Binaryen: `261` vs `63` functions, `28` vs `17` types, `315383` vs `209532` code bytes.

The suffix is therefore a safe incremental win, not a closure of `[JSON-AS]003`. The next large size gap is still function/type liveness and inlining-derived cleanup, with the known direct `inlining-optimizing` compare blocker and large-module cleanup guards still needing separate work.

## Direct-pass status

- `duplicate-function-elimination`: `.tmp/pass-fuzz-dfe-jsonas-signoff-10000`, `6768` compared, `6768` normalized, `0` mismatches, `20` Binaryen/tool command failures.
- `code-folding`: `.tmp/pass-fuzz-code-folding-jsonas-signoff-10000`, `6761` compared, `6761` normalized, `0` mismatches, `20` Binaryen/tool command failures.
- `redundant-set-elimination`: `.tmp/pass-fuzz-rse-loop-entry-fix-10000`, `6771` compared, `6771` normalized, `0` mismatches, `20` Binaryen/tool command failures.

Agent classification: these command failures are Binaryen/tool decode classes separated by the harness. No semantic mismatches remain in these direct lanes under the scoped normalizers.

## Scheduling recommendation

The suffix is a credible preset candidate only as a dedicated preset-widening slice with tests and a full gate. Required follow-up before landing a preset change:

1. Add preset-order tests for the exact suffix placement and repeated `remove-unused-module-elements` cleanup slot.
2. Rerun `moon test src/cmd` if CLI/preset public behavior tests live there or are touched.
3. Rerun `moon info`, `moon fmt`, and full `moon test`; note that `moon info` previously crashed locally with a Moon internal index-out-of-bounds panic in this workspace.
4. Rerun the fresh-clone artifact generation/validation/Node-smoke commands above after any preset code change.
5. Decide whether DFE's name-section stripping is acceptable as an incidental suffix behavior or whether `[JSON-AS]008` should provide explicit `strip-debug` first.

## Bottom line

`DFE + RUME + CF + RSE + RUME` is runtime-green and direct-pass-green on the analyzed artifacts. It gives a modest code-size win after DFE and a larger total byte win where DFE strips debug names. It should not be represented as Binaryen O4 parity: the remaining function/type/code gap is still large and belongs to the inlining/type-cleanup follow-up work.
