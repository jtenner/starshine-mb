# DAE002 Func237 Frontier Classification

Date: 2026-05-18

## Scope

Classify the current `dae-optimizing` direct debug-artifact frontier after `.tmp/dae-parity-selected236-locals-fast-artifact` advanced to first diff `defined=237 abs=254`.

Primary artifact files:

- `.tmp/dae-parity-selected236-locals-fast-artifact/func-defined237-abs254.binaryen.wat`
- `.tmp/dae-parity-selected236-locals-fast-artifact/func-defined237-abs254.starshine.wat`
- `.tmp/dae-parity-selected236-locals-fast-artifact/binaryen.print.wat`
- `.tmp/dae-parity-selected236-locals-fast-artifact/starshine.print.wat`

## Baseline evidence

Baseline kept run:

- Starshine pass runtime: `1633.775ms`
- Binaryen pass runtime: `854.468ms`
- Ratio: about `1.91x`, inside but close to the `Starshine <= 2 * Binaryen` pass-local target.
- First diff: `defined=237 abs=254`.

Current Func237 shape:

- Binaryen Func237 has 11 declared locals (`$4..$14`) and begins with a void `block` that preserves an early trap path while the live path branches out and later materializes a `0` carrier.
- Starshine Func237 has 146 declared locals (`$4..$149`) and starts with `(local.set $79 (block $block2 (result i32) ...))`. The live branch exits the result block with `local.get $6`, which is default `0` on the surviving path; the trap path remains protected by nested `unreachable`s. This is semantically similar to Binaryen's later `local.set $0 (i32.const 0)`, but the local/control representation is very different.
- The mismatch is therefore broad local/coalescing/control-shape drift, not the earlier exact-literal, immutable-global, dropped-result, const-if, or tiny local-retarget families.

## Probe results

### Selected full nested cleanup for Func237

Temporary code forced the DAE nested cleanup lane to run on selected Func237 despite the large touched set.

Artifact: `.tmp/dae-selected237-fullcleanup-probe-artifact`

Result:

- First diff stayed `defined=237 abs=254`.
- Starshine pass runtime `1905.725ms` vs Binaryen `915.815ms`, exceeding the 2x target.
- Func237 collapsed too aggressively toward an `unreachable` shape, so this was both too slow and not a useful parity direction.

### Selected nested cleanup without DCE/coalesce

Temporary code forced Func237 through a reduced nested lane omitting the most destructive cleanup pieces.

Artifact: `.tmp/dae-selected237-no-dce-coalesce-probe-artifact`

Result:

- First diff stayed `defined=237 abs=254`.
- Starshine pass runtime `1827.431ms` vs Binaryen `921.109ms`, still too tight and not advancing parity.
- Func237 retained the broad high-local/control-carrier shape.

### Existing nested lane forced only for Func237

Temporary code kept the existing DAE nested cleanup sequence but narrowed the effective touched set to Func237.

Artifact: `.tmp/dae-selected237-existing-nested-probe-artifact`

Result:

- First diff stayed `defined=237 abs=254`.
- Starshine pass runtime `1926.365ms` vs Binaryen `948.117ms`, over the 2x target.
- The raw-skip path was exercised and did not produce a useful frontier shift.

All probe code was reverted.

### Selected default-result carrier fold attempt

A narrow TDD prototype rewrote a reduced leading `(block (result i32) ... local.get default; br outer)` carrier into a void side-effect block followed by `i32.const 0; local.set carrier`. The reduced test passed, but the original artifact did not change: `.tmp/dae-selected237-carrier2-artifact` and `.tmp/dae-selected237-carrier3-artifact` both stayed at `defined=237 abs=254`, and timings were too tight or over target (`1804.251ms` vs `903.822ms`, then `1836.028ms` vs `925.716ms`). The prototype was reverted because it did not affect the real Func237 shape and consumed runtime headroom.

## Interpretation

Running broader nested cleanup on Func237 is not currently promising:

1. It does not advance the first diff.
2. It consumes or exceeds the already tight runtime headroom.
3. Coalescing alone over-collapses the function relative to Binaryen's 11-local target, while reduced cleanup leaves the high-local carrier shape intact.

The useful next implementation direction is not another whole selected cleanup pass. A smaller candidate is a targeted structural fold for the leading result-carrier block: preserve the side-effect/trap structure, but materialize the known live result as a constant/default local after a void block, matching Binaryen's first region more closely. That would still need a focused reduced test first and may not by itself advance the frontier because local declaration parity remains far away.

## Commands used

- `diff -u .tmp/dae-parity-selected236-locals-fast-artifact/func-defined237-abs254.binaryen.wat .tmp/dae-parity-selected236-locals-fast-artifact/func-defined237-abs254.starshine.wat | head -260`
- `moon build --frozen --target native --release --package jtenner/starshine/cmd`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --dae-optimizing --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/dae-selected237-fullcleanup-probe-artifact`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --dae-optimizing --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/dae-selected237-no-dce-coalesce-probe-artifact`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --dae-optimizing --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/dae-selected237-existing-nested-probe-artifact`
- `moon test --frozen src/passes`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --dae-optimizing --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/dae-selected237-carrier2-artifact`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --dae-optimizing --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/dae-selected237-carrier3-artifact`
