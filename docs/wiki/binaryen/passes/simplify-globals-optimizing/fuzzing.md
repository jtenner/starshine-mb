---
kind: workflow
status: working
last_reviewed: 2026-07-06
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
---

# `simplify-globals-optimizing` Fuzzing Profile

Recommended ordinary GenValid compare-pass smoke lane with a current native binary:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-simplify-globals-optimizing --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Dedicated GenValid profile: `simplify-globals-optimizing-all`.

The profile is a weighted aggregate over six deterministic validating leaves:

| Leaf | Weight | Intended SGO family |
| --- | ---: | --- |
| `simplify-globals-optimizing-initializer-folding` | 2 | single-use global-initializer folding into later global initializers |
| `simplify-globals-optimizing-same-init-dead-set` | 2 | same-as-init / dead-set removal while preserving operand evaluation |
| `simplify-globals-optimizing-read-only-to-write` | 3 | read-only-to-write guard recognition |
| `simplify-globals-optimizing-startup-propagation` | 2 | startup global propagation into active segment offsets |
| `simplify-globals-optimizing-runtime-propagation` | 3 | runtime single-write global propagation inside function code |
| `simplify-globals-optimizing-nested-cleanup` | 2 | touched-function cleanup payoff after global reads are replaced |

Ordinary dedicated-profile closeout lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-genvalid-simplify-globals-optimizing-all-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

No SGO-specific `--require-feature` floors or compare normalizers are required for the profile. The compare result records aggregate leaf coverage in `genValidSelectedProfileCounts`; use that field to confirm the six leaves were sampled before treating a lane as representative.

Current profile evidence:

- Profile-creation smoke:

  ```sh
  bun scripts/pass-fuzz-compare.ts --count 200 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-genvalid-all-smoke-200 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
  ```

  Result: `200/200` compared, `200` normalized matches, `0` mismatches, `0` validation/generator/property/command failures. `genValidSelectedProfileCounts` sampled all six leaves: same-init/dead-set `28`, runtime propagation `39`, startup propagation `29`, nested cleanup `25`, initializer folding `35`, and read-only-to-write `44`.

- Dedicated-profile closeout-scale lane after the select/value-flow read-only-to-write slice:

  ```sh
  bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-genvalid-simplify-globals-optimizing-all-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
  ```

  Result: `10000/10000` compared, `10000` normalized matches, `0` mismatches, `0` validation/generator/property/command failures, `0` command failures. Binaryen cache: `10000` hits / `0` misses. `genValidSelectedProfileCounts`: same-init/dead-set `1404`, runtime propagation `2206`, startup propagation `1445`, nested cleanup `1427`, initializer folding `1391`, and read-only-to-write `2127`.

- Float-value pure-condition FlowScanner smoke after adding non-trapping `f32` / `f64` value operators:

  ```sh
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-float-value-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-float-value-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  ```

  Result: both lanes compared `1000/1000`, normalized `1000/1000`, and had `0` mismatches, `0` validation/generator/property failures, and `0` command failures. Binaryen cache hit `1000/1000` in both lanes. The dedicated manifest sampled all six leaves: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

- Numeric-conversion pure-condition FlowScanner smoke after adding non-trapping numeric conversions, reinterprets, sign-extension, and `trunc_sat` operators while keeping trapping float-to-int truncs excluded:

  ```sh
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-conversion-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-conversion-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  ```

  Result: both lanes compared `1000/1000`, normalized `1000/1000`, and had `0` mismatches, `0` validation/generator/property failures, and `0` command failures. Binaryen cache hit `1000/1000` in both lanes. The dedicated manifest sampled all six leaves: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

- Ref-predicate pure-condition FlowScanner smoke after adding non-trapping `ref.is_null` / `ref.eq` operators while preserving the `local.tee` value-flow guardrail:

  ```sh
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-ref-pure-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-ref-pure-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  ```

  Result: both lanes compared `1000/1000`, normalized `1000/1000`, and had `0` mismatches, `0` validation/generator/property failures, and `0` command failures. Binaryen cache hit `1000/1000` in both lanes.

- Block-prefix void-call FlowScanner smoke after adding the zero-parameter/zero-result independent-call condition form for guarded-write and if-return tails:

  ```sh
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-void-call-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-void-call-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  ```

  Result: both lanes compared `1000/1000`, normalized `1000/1000`, and had `0` mismatches, `0` validation/generator/property failures, and `0` command failures. Binaryen cache hit `1000/1000` in both lanes. The dedicated manifest sampled all six leaves: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.


- Independent constant `local.tee` compare-operand FlowScanner smoke after adding direct/reverse compare operands for guarded-write and if-return tails while keeping guarded-value-to-`local.tee` flow excluded:

  ```sh
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-localtee-compare-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-localtee-compare-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  ```

  Result: both lanes compared `1000/1000`, normalized `1000/1000`, and had `0` mismatches, `0` validation/generator/property failures, and `0` command failures. Binaryen cache hit `1000/1000` in both lanes. The dedicated manifest sampled all six leaves: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

- Independent constant `local.set` compare-operand FlowScanner smoke after adding direct/reverse block compare operands for guarded-write and if-return tails while keeping guarded-value-to-`local.set` flow excluded:

  ```sh
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-localset-compare-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-localset-compare-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  ```

  Result: both lanes compared `1000/1000`, normalized `1000/1000`, and had `0` mismatches, `0` validation/generator/property failures, and `0` command failures. Binaryen cache hit `1000/1000` in both lanes. The dedicated manifest sampled all six leaves: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

- Independent constant `global.set` compare-operand FlowScanner smoke after adding result-block compare operands for guarded-write and if-return tails while keeping guarded-value-to-`global.set` flow excluded:

  ```sh
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-globalset-compare-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-globalset-compare-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  ```

  Result: both lanes compared `1000/1000`, normalized `1000/1000`, and had `0` mismatches, `0` validation/generator/property failures, and `0` command failures. Binaryen cache hit `1000/1000` in both lanes. The dedicated manifest sampled all six leaves: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

- Independent local-fed `global.set` compare-operand FlowScanner smoke after widening the `global.set` result-block subset from constant-only values to constants or `local.get`s while still keeping guarded-value-to-`global.set` flow excluded:

  ```sh
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-local-globalset-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-local-globalset-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  ```

  Result: both lanes compared `1000/1000`, normalized `1000/1000`, and had `0` mismatches, `0` validation/generator/property failures, and `0` command failures. Binaryen cache hit `1000/1000` in both lanes. The dedicated manifest sampled all six leaves: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

- Independent local-fed local-write compare-operand FlowScanner smoke after widening the direct `local.tee` and block `local.set` compare subsets from constant-only values to constants or `local.get`s while still keeping guarded-value-to-local-write flow excluded:

  ```sh
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-local-localwrite-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-local-localwrite-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  ```

  Result: both lanes compared `1000/1000`, normalized `1000/1000`, and had `0` mismatches, `0` validation/generator/property failures, and `0` command failures. Binaryen cache hit `1000/1000` in both lanes.

- Independent local-fed `table.grow` compare-operand FlowScanner smoke after widening the table-grow compare subset from constant-only ref/delta operands to constants or `local.get`s while still keeping guarded-value-to-`table.grow` flow excluded:

  ```sh
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-local-tablegrow-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-local-tablegrow-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
  ```

  Result: both lanes compared `1000/1000`, normalized `1000/1000`, and had `0` mismatches, `0` validation/generator/property failures, and `0` command failures. Binaryen cache hit `1000/1000` in both lanes.

- Independent local-fed `table.grow` select-operand FlowScanner smoke after widening the table-grow select subset from constant-only ref/delta operands to constants or `local.get`s while still keeping guarded-value-to-`table.grow` flow excluded:

  ```sh
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-local-tablegrow-select-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-local-tablegrow-select-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  ```

  Result: both lanes compared `1000/1000`, normalized `1000/1000`, and had `0` mismatches, `0` validation/generator/property failures, and `0` command failures. Binaryen cache hit `1000/1000` in both lanes. The dedicated manifest sampled all six leaves: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

- Independent local-fed `memory.grow` compare/select FlowScanner smoke after widening the memory-grow compare and select subsets from constant-only deltas to constants or `local.get`s while still keeping guarded-value-to-`memory.grow` flow excluded:

  ```sh
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-local-memgrow-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-local-memgrow-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
  ```

  Result: both lanes compared `1000/1000`, normalized `1000/1000`, and had `0` mismatches, `0` validation/generator/property failures, and `0` command failures. Binaryen cache hit `1000/1000` in both lanes.

- Independent constant memory-store compare-operand FlowScanner smoke after adding result-block compare operands for guarded-write and if-return tails while keeping guarded-value-to-`i32.store` address/value flow excluded:

  ```sh
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-memstore-compare-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-memstore-compare-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  ```

  Result: both lanes compared `1000/1000`, normalized `1000/1000`, and had `0` mismatches, `0` validation/generator/property failures, and `0` command failures. Binaryen cache hit `1000/1000` in both lanes. The dedicated manifest sampled all six leaves: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

- Independent local-fed memory-store compare-operand FlowScanner smoke after widening the memory-store result-block subset from constant-only address/value operands to constants or `local.get`s while still keeping guarded-value-to-`i32.store` address/value flow excluded:

  ```sh
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-local-memstore-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-local-memstore-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
  ```

  Result: both lanes compared `1000/1000`, normalized `1000/1000`, and had `0` mismatches, `0` validation/generator/property failures, and `0` command failures. Binaryen cache hit `1000/1000` in both lanes. The dedicated manifest sampled all six leaves: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

## Direct pass-local timing probe

The 2026-07-06 timing slice added a temporary representative fixture generator at `.tmp/sgo-timing/measure_sgo_timing.py` and measured Starshine with `_build/native/release/build/cmd/cmd.exe --tracing pass --simplify-globals-optimizing` against Binaryen `BINARYEN_PASS_DEBUG=1 wasm-opt --all-features --simplify-globals-optimizing`. Each fixture used `15` repeats with `3` warmups discarded after rebuilding native `src/cmd`.

| Fixture | Starshine median | Binaryen median | Ratio | Status |
| --- | ---: | ---: | ---: | --- |
| `const-read-1000f` | `0.565 ms` | `1.528 ms` | `0.370x` | passes 1x after SGO-owned cheap cleanup and the latest local-fed `table.grow` select FlowScanner slice |
| `runtime-set-get-1000f` | `0.637 ms` | `2.724 ms` | `0.234x` | passes 1x after final runtime set/get shape pruning and the latest local-fed `table.grow` select FlowScanner slice |
| `read-only-select-1000f` | `2.157 ms` | `3.349 ms` | `0.644x` | passes 1x after select/empty-if cleanup, block-prefix/table-op/call/global-set/local-write/memory-store cleanup, and local-fed `table.grow` select cleanup |
| `initializer-fold-1000g` | `0.457 ms` | `1.012 ms` | `0.451x` | passes 1x after the latest SGO recognizer changes |
| `startup-offsets-1000e` | `1.014 ms` | `1.220 ms` | `0.832x` | passes 1x after the latest SGO recognizer changes |

The final structured/local-cleanup review reran development lanes after rebuilding native Starshine:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-localfix-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-localfix-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Both requested/compared/normalized `1000/1000`, with zero mismatches, validation/generator/property failures, or command failures and Binaryen cache `1000` hits / `0` misses. The same rebuilt binary matched Binaryen's one-use local fixture at `44` stripped bytes and retained strict timing headroom (`0.474x`, `0.328x`, `0.429x`, `0.430x`, `0.879x`). These are development smokes; final closure still requires fresh full-count regular, wasm-smith, dedicated, and random-all lanes.

The same slice added a direct `1000`-case regular GenValid smoke after the timing changes:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-perf-skip-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: `1000/1000` compared, `1000` normalized matches, `0` mismatches, `0` validation/generator/property/command failures, and `0` command failures; Binaryen cache `1000` hits / `0` misses.

The cheap-cleanup/perf slice reran the dedicated profile after code changes:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-genvalid-simplify-globals-optimizing-all-cheap-cleanup-10000b --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: `10000/10000` compared, `10000` normalized matches, `0` mismatches, `0` validation/generator/property/command failures, `0` command failures. Binaryen cache: `10000` hits / `0` misses. `genValidSelectedProfileCounts`: same-init/dead-set `1404`, runtime propagation `2206`, startup propagation `1445`, nested cleanup `1427`, initializer folding `1391`, and read-only-to-write `2127`.

Regular GenValid closeout lane after the same slice:

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-genvalid-100000-cheap-cleanup --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: `100000/100000` compared, `100000` normalized matches, `0` mismatches, `0` validation/generator/property/command failures, and `0` command failures. Binaryen cache: `1314` hits / `98686` misses.

The explicit wasm-smith closeout lane was rerun after adding a narrow no-global unreachable-debris cleanup:

```sh
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-wasm-smith-10000-unreachable-block-cleanup --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: `9956/10000` compared, `9956` normalized matches, `0` raw mismatches, `44` Binaryen/tool command failures, `0` validation/generator/property failures. Command-failure classes remain the cached/tool classes from the previous lane: `binaryen-rec-group-zero` `39`, `binaryen-invalid-tag-index` `1`, `binaryen-table-index-out-of-range` `1`, and `binaryen-bad-section-size` `3`. The fixed mismatch was `.tmp/pass-fuzz-sgo-wasm-smith-10000-cheap-cleanup/failures/case-009332-wasm-smith`, a no-globals module where Binaryen removes result-block / `drop (unreachable)` debris before a final `unreachable`; Starshine now matches that lane without needing compare normalizers. The remaining wasm-smith non-compares are classified as Binaryen/tool failures, not SGO transform-family mismatches.

Before the safe trunc-prefix follow-up below, random-all closeout was still open. A `10000` attempt at `.tmp/pass-fuzz-sgo-genvalid-random-all-profiles-10000-unreachable-block-cleanup` timed out after `900s` with partial artifacts. A smaller triage lane with cleanup normalizers completed:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5555 --pass simplify-globals-optimizing --gen-valid-profile random-all-profiles --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-sgo-genvalid-random-all-profiles-1000-cleanup-normalized --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches
```

Result: `1000/1000` compared, `907` normalized matches, `28` cleanup-normalized matches, `65` mismatches, `0` validation/generator/property/command failures. All `65` mismatches came from `selected_profile: coverage-forced-portable` and were classified as generic unreachable/pure-debris cleanup parity gaps exposed by SGO's Binaryen-default nested optimizer behavior, not as global transform-family semantic mismatches.

The next slice added a focused large touched dead-tail regression and SGO-only large-function vacuum escape hatch, then reran the same random-all triage shape:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5555 --pass simplify-globals-optimizing --gen-valid-profile random-all-profiles --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-sgo-genvalid-random-all-profiles-1000-large-unreachable-vacuum --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches
```

Result: still `1000/1000` compared, `907` normalized matches, `28` cleanup-normalized matches, `65` mismatches, and zero failures. The explicit `case-000002-gen-valid` diff is narrower: Starshine no longer preserves the dead call/tail suffix after the unreachable block for SGO-large touched functions, but it still preserves const-trunc/pure-prefix debris before the unreachable block where Binaryen reduces the function to one `unreachable`. Closeout must either implement/classify that remaining owner or get explicit approval for a documented exception; do not treat random-all as green yet.

The same slice reran representative direct timing after the pass-manager change; all fixtures still meet 1x: `const-read-1000f` `0.462/1.461 ms` (`0.316x`), `runtime-set-get-1000f` `0.477/2.647 ms` (`0.180x`), `read-only-select-1000f` `1.502/3.757 ms` (`0.400x`), `initializer-fold-1000g` `0.417/0.978 ms` (`0.426x`), and `startup-offsets-1000e` `0.708/0.963 ms` (`0.736x`).

The safe trunc-prefix follow-up then added a focused generated `coverage-forced-portable`-style regression for the remaining in-range const float-to-int trunc drops before a guaranteed unreachable block, plus a negative for a potentially trapping NaN trunc prefix. `src/passes/pass_manager.mbt` now collapses only SGO-large touched functions when their remaining leading prefix is the exact safe generated `12` trunc/drop batch followed by a void block that exits to a guaranteed `unreachable`, and it also drops now-unused locals to match Binaryen's one-`unreachable` function shape. Validation for that slice:

```sh
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*trunc prefix*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-safe-trunc-prefix-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass simplify-globals-optimizing --gen-valid-profile random-all-profiles --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-sgo-genvalid-random-all-profiles-10000-safe-trunc-prefix-locals --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches
```

Results: focused trunc-prefix tests `3/3`, full SGO tests `173/173`, `moon test src/passes` `4322/4322`, native `src/cmd` build with the pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-safe-trunc-prefix-genvalid-1000` `1000/1000` normalized with zero failures, and random-all closeout `.tmp/pass-fuzz-sgo-genvalid-random-all-profiles-10000-safe-trunc-prefix-locals` `10000/10000` normalized with zero mismatches/failures (`Binaryen` cache `5222` hits / `4778` misses). Full `moon info` and `moon test` also passed after the slice (`7761/7761`) with only the repository's pre-existing warnings.

The same follow-up reran representative direct timing after rebuilding native `src/cmd`; all fixtures still meet 1x: `const-read-1000f` `0.474/1.664 ms` (`0.285x`), `runtime-set-get-1000f` `0.492/3.004 ms` (`0.164x`), `read-only-select-1000f` `1.585/3.755 ms` (`0.422x`), `initializer-fold-1000g` `0.790/2.271 ms` (`0.348x`), and `startup-offsets-1000e` `1.228/1.929 ms` (`0.637x`).

A later FlowScanner slice added the official side-effecting `select` result through `i32.eqz` before the guarded write. Red-first focused coverage failed before implementation because the global remained mutable, then passed after `src/passes/simplify_globals_optimizing.mbt` allowed pure post-`select` value flow to the final `if` and extended the SGO-created select/empty-if cleanup to the `select; i32.eqz; if` shell. Validation after rebuilding native `src/cmd`:

```sh
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select eqz*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-select-eqz-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-select-eqz-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: focused select-eqz `1/1`, select-focused `3/3`, full SGO tests `174/174`, `moon test src/passes` `4323/4323`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-select-eqz-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-select-eqz-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.483/1.625 ms` (`0.297x`), `runtime-set-get-1000f` `0.492/2.847 ms` (`0.173x`), `read-only-select-1000f` `1.591/3.393 ms` (`0.469x`), `initializer-fold-1000g` `0.455/0.996 ms` (`0.456x`), and `startup-offsets-1000e` `0.981/1.096 ms` (`0.895x`).

A later FlowScanner slice added Binaryen's official nested-thrice `read-only-to-write` positive: a block condition whose prefix is itself a same-global read-only-to-write guard and whose final yielded value is a same-global `global.get` that flows through the next guarded write. Red-first focused coverage failed before implementation because the global remained mutable, then passed after `src/passes/simplify_globals_optimizing.mbt` learned to count that nested guard prefix plus final read as the source-backed nested carveout. Validation after rebuilding native `src/cmd`:

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-official-nested-thrice.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*nested-thrice*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*nested*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-nested-thrice-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-nested-thrice-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: the local Binaryen probe reduced the official-style fixture to immutable `$once` plus `nop`; focused nested-thrice `1/1`, nested-focused `24/24`, full SGO tests `175/175`, `moon test src/passes` `4324/4324`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-nested-thrice-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-nested-thrice-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.489/1.662 ms` (`0.294x`), `runtime-set-get-1000f` `0.500/3.108 ms` (`0.161x`), `read-only-select-1000f` `1.633/3.866 ms` (`0.423x`), `initializer-fold-1000g` `0.454/1.039 ms` (`0.437x`), and `startup-offsets-1000e` `0.962/1.138 ms` (`0.845x`).

A later FlowScanner/body-effect slice added Binaryen's official multi-global nested `read-only-to-write` positive: an outer guarded write may contain exactly one constant write to the guarded global plus nested different-global read-only-to-write guard pairs in its body. A local Binaryen probe reduced the official-style `$a` / `$b` / `$c` fixture to immutable globals plus `nop`; before implementation Starshine left `$a` and `$b` mutable. Red-first focused coverage failed before implementation, then passed after `src/passes/simplify_globals_optimizing.mbt` learned the narrow nested different-global body matcher.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-official-nested-multiglobal.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*multi-global nested*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*nested*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-multiglobal-nested-genvalid-1000b --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-multiglobal-nested-dedicated-1000b --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: focused multi-global nested `1/1`, mutual nested guardrail `1/1`, nested-focused `26/26`, full SGO tests `177/177`, `moon test src/passes` `4326/4326`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-multiglobal-nested-genvalid-1000b` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-multiglobal-nested-dedicated-1000b` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.477/1.598 ms` (`0.298x`), `runtime-set-get-1000f` `0.494/2.659 ms` (`0.186x`), `read-only-select-1000f` `1.561/3.467 ms` (`0.450x`), `initializer-fold-1000g` `0.449/0.998 ms` (`0.450x`), and `startup-offsets-1000e` `1.014/1.096 ms` (`0.925x`).

A later source-backed FlowScanner slice extended the safe-side-effect result-`if` arm subset: the global-derived value may now flow through pure operators inside the selected arm before reaching the final guarded write condition. A local Binaryen positive probe reduced `.tmp/sgo-if-arm-pure.wat` to immutable `$global` plus `drop (call $foo)`, while a paired `local.tee` arm probe kept the global mutable. Red-first focused coverage failed before implementation, then passed after `src/passes/simplify_globals_optimizing.mbt` added `sgo_block_condition_safe_arm_read_idx(...)`.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-if-arm-pure.wat -o -
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-if-arm-tee.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*if-arm*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-if-arm-pure-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-if-arm-pure-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: focused if-arm tests `3/3`, full SGO tests `179/179`, `moon test src/passes` `4328/4328`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-if-arm-pure-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-if-arm-pure-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.486/1.982 ms` (`0.245x`), `runtime-set-get-1000f` `0.509/3.162 ms` (`0.161x`), `read-only-select-1000f` `1.656/4.046 ms` (`0.409x`), `initializer-fold-1000g` `0.474/1.045 ms` (`0.453x`), and `startup-offsets-1000e` `0.996/1.139 ms` (`0.875x`).

A later source-backed FlowScanner slice extended the same result-`if` arm subset through pure post-`if` operators: the global-derived arm value may leave the side-effecting result `if`, flow through pure operators such as `i32.eqz`, and then reach only the final guarded-write condition. Local Binaryen probes reduced `.tmp/sgo-if-arm-eqz.wat` to immutable `$global` plus `drop (call $foo)`, while `.tmp/sgo-if-arm-post-tee.wat` kept `$global` mutable when the result flowed into `local.tee` before the pure operator. Red-first focused coverage failed before implementation because `$once` stayed mutable, then passed after `src/passes/simplify_globals_optimizing.mbt` taught `sgo_count_if_arm_condition_read_only_to_write_read(...)` to scan pure post-result operators before the final guarded write.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-if-arm-eqz.wat -o -
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-if-arm-post-tee.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*if-arm*post*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-if-arm-post-pure-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-if-arm-post-pure-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: focused post-if-arm tests `2/2`, focused if-arm tests `5/5`, full SGO tests `181/181`, `moon test src/passes` `4330/4330`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-if-arm-post-pure-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-if-arm-post-pure-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.530/1.757 ms` (`0.301x`), `runtime-set-get-1000f` `0.556/3.096 ms` (`0.179x`), `read-only-select-1000f` `1.732/3.955 ms` (`0.438x`), `initializer-fold-1000g` `0.500/1.071 ms` (`0.467x`), and `startup-offsets-1000e` `1.011/1.158 ms` (`0.873x`).

A later source-backed FlowScanner slice added a select-operand positive with an independent call: the guarded global may be the first `select` operand while a following zero-parameter/result call supplies the second operand independently, then the selected value reaches only the final same-global guarded write. A local Binaryen probe reduced `.tmp/sgo-select-operand-call.wat` to immutable `$guard` plus `drop (call $foo)`, while `.tmp/sgo-select-operand-call-neg.wat` kept `$guard` mutable when the global-derived value flowed into `call $sink`. Red-first focused coverage failed before implementation because `$guard` stayed mutable; the paired negative stayed mutable after the narrow recognizer was added.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-operand-call.wat -o -
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-operand-call-neg.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select operand*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-select-call-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-select-call-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: focused select-operand tests `2/2`, focused select tests `5/5`, full SGO tests `183/183`, `moon test src/passes` `4332/4332`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-select-call-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-select-call-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.569/2.090 ms` (`0.272x`), `runtime-set-get-1000f` `0.591/4.171 ms` (`0.142x`), `read-only-select-1000f` `2.669/4.780 ms` (`0.558x`), `initializer-fold-1000g` `0.581/1.133 ms` (`0.513x`), and `startup-offsets-1000e` `0.907/1.214 ms` (`0.747x`).


A later source-backed FlowScanner slice added select-operand positives with independent memory operations: `memory.size` may be removed with the now-empty select/if shell, and constant-delta `memory.grow` is preserved as `memory.grow; drop`; if the guarded global flows into the `memory.grow` delta, Binaryen and Starshine both keep the global mutable. Local Binaryen probes covered positive `memory.size` / `memory.grow` and negative global-to-`memory.grow` shapes. Red-first focused coverage failed before implementation because `$guard` stayed mutable; the paired negative stayed mutable after the narrow recognizer was added.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-operand-memory-size.wat -o -
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-operand-memory-grow.wat -o -
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-operand-memory-grow-neg.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select operand*memory*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-select-memory-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-select-memory-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: focused select-operand memory tests `2/2`, focused select tests `7/7`, full SGO tests `185/185`, `moon test src/passes` `4334/4334`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-select-memory-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-select-memory-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.522/1.855 ms` (`0.281x`), `runtime-set-get-1000f` `0.531/3.326 ms` (`0.160x`), `read-only-select-1000f` `1.830/4.279 ms` (`0.428x`), `initializer-fold-1000g` `0.519/1.069 ms` (`0.485x`), and `startup-offsets-1000e` `0.873/1.183 ms` (`0.738x`).

A later source-backed FlowScanner cleanup slice covered the symmetric independent-call operand order where the zero-parameter/result call is the first `select` operand and the guarded global is the second operand. Local Binaryen reduced `.tmp/sgo-select-operand-call-second.wat` to immutable `$guard` plus `drop (call $foo)`. Starshine already counted the read as safe through the generic post-read `select` scan, but preserved an inert `call; if {}` shell; the slice added red-first focused coverage and SGO cheap cleanup to rewrite that shell to `call; drop`, matching Binaryen's effect-preserving output.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-operand-call-second.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select second operand*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-select-second-call-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-select-second-call-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: the red-first focused test failed before cleanup because the effect-preserving `drop` was missing; after implementation, focused select-second `1/1`, focused select tests `8/8`, full SGO tests `186/186`, `moon test src/passes` `4335/4335`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-select-second-call-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-select-second-call-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.512/1.692 ms` (`0.303x`), `runtime-set-get-1000f` `0.524/3.091 ms` (`0.169x`), `read-only-select-1000f` `1.723/4.230 ms` (`0.407x`), `initializer-fold-1000g` `0.480/1.057 ms` (`0.455x`), and `startup-offsets-1000e` `0.782/1.120 ms` (`0.698x`).

A later source-backed FlowScanner cleanup slice covered the symmetric independent memory-op operand order where `memory.size` or constant-delta `memory.grow` supplies the first `select` operand and the guarded global is the second operand. Local Binaryen reduced `.tmp/sgo-select-operand-memory-size-second.wat` to immutable `$guard` plus `nop`, and `.tmp/sgo-select-operand-memory-grow-second.wat` to immutable `$guard` plus `drop (memory.grow (i32.const 0))`. Starshine already counted these reads as safe through the generic post-read `select` scan, but preserved inert `memory.size` / `memory.grow` select-if shells; the slice added red-first focused coverage and SGO cheap cleanup to remove `memory.size` and preserve `memory.grow; drop`.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-operand-memory-size-second.wat -o -
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-operand-memory-grow-second.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select second operand*memory*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-select-second-memory-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-select-second-memory-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: the red-first focused test failed before cleanup because `memory.size` and an empty `if` remained; after implementation, focused select-second-memory `1/1`, focused select tests `9/9`, full SGO tests `187/187`, `moon test src/passes` `4336/4336`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-select-second-memory-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-select-second-memory-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.496/1.515 ms` (`0.327x`), `runtime-set-get-1000f` `0.518/2.665 ms` (`0.194x`), `read-only-select-1000f` `1.664/3.625 ms` (`0.459x`), `initializer-fold-1000g` `0.440/1.012 ms` (`0.434x`), and `startup-offsets-1000e` `0.779/1.164 ms` (`0.669x`).

A later source-backed FlowScanner slice covered a block-condition subset where an independent zero-parameter/result call is evaluated and dropped before a final guarded global read inside a result block. Local Binaryen reduced `.tmp/sgo-block-independent-call-before-get.wat` to immutable `$g` plus `drop (call $foo)`, while `.tmp/sgo-block-prefix-call-neg.wat` kept `$g` mutable when a global-derived value flowed into a call parameter. Starshine now counts only the narrow `call; drop; global.get` block body as safe and adds SGO cheap cleanup for the resulting `block { call; drop; const } ; empty-if` shell.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-block-independent-call-before-get.wat -o -
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-block-prefix-call-neg.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*block prefix*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-block-prefix-call-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-block-prefix-call-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: the red-first focused positive failed before implementation because `$once` stayed mutable; after implementation, focused block-prefix tests `2/2`, full SGO tests `189/189`, `moon test src/passes` `4338/4338`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-block-prefix-call-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-block-prefix-call-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.882/2.115 ms` (`0.417x`), `runtime-set-get-1000f` `0.930/4.035 ms` (`0.231x`), `read-only-select-1000f` `3.018/4.773 ms` (`0.632x`), `initializer-fold-1000g` `0.661/1.439 ms` (`0.459x`), and `startup-offsets-1000e` `0.871/1.399 ms` (`0.622x`).


A later source-backed FlowScanner slice extended the block-prefix independent-call condition subset to Binaryen's function-level `if return; set` matcher: a result block condition evaluates an independent zero-parameter/result call, drops it, then yields the guarded `global.get`; the yielded value reaches only the guard-return decision before the final same-global constant write. Local Binaryen reduced `.tmp/sgo-ifreturn-block-prefix-call.wat` to immutable `$once` plus `drop (call $foo)`, while `.tmp/sgo-ifreturn-block-prefix-call-neg.wat` kept `$once` mutable when the global-derived value flowed into a call parameter. Starshine now counts only the narrow `block { call; drop; global.get }; if return; const; global.set` shape as safe and adds SGO cheap cleanup for the resulting `block { call; drop; const }; if return; const; drop` shell.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-ifreturn-block-prefix-call.wat -o -
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-ifreturn-block-prefix-call-neg.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*if-return block prefix*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*block prefix*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-ifreturn-block-prefix-call-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-ifreturn-block-prefix-call-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: the red-first focused positive failed before implementation because `$once` stayed mutable; after implementation, focused if-return block-prefix tests `2/2`, focused block-prefix tests `4/4`, full SGO tests `191/191`, `moon test src/passes` `4340/4340`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-ifreturn-block-prefix-call-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-ifreturn-block-prefix-call-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.498/1.517 ms` (`0.328x`), `runtime-set-get-1000f` `0.517/2.719 ms` (`0.190x`), `read-only-select-1000f` `1.694/3.452 ms` (`0.491x`), `initializer-fold-1000g` `0.437/0.981 ms` (`0.445x`), and `startup-offsets-1000e` `0.804/1.087 ms` (`0.740x`).

A later source-backed FlowScanner slice extended the block-prefix independent-effect condition subset from calls to memory operations. Local Binaryen reduced `.tmp/sgo-block-prefix-memory.wat` to immutable `$guard`, deleting `memory.size` guarded-write shells and preserving constant-delta `memory.grow` as `drop (memory.grow (i32.const 0))`; Starshine now counts only `memory.size; drop; global.get` and `const; memory.grow; drop; global.get` result-block conditions as safe for guarded-write and function-level if-return tails. The paired guardrail keeps the global mutable when the guarded value flows into the `memory.grow` delta.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-block-prefix-memory.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*block prefix*memory*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*block prefix*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-block-prefix-memory-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-block-prefix-memory-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: the two red-first focused positives failed before implementation because `$once` stayed mutable; after implementation, focused block-prefix-memory tests `2/2` plus guardrail `1/1`, focused block-prefix tests `7/7`, full SGO tests `202/202`, `moon test src/passes` `4351/4351`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-block-prefix-memory-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-block-prefix-memory-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.550/1.962 ms` (`0.281x`), `runtime-set-get-1000f` `0.589/3.460 ms` (`0.170x`), `read-only-select-1000f` `2.061/4.349 ms` (`0.474x`), `initializer-fold-1000g` `0.520/1.146 ms` (`0.454x`), and `startup-offsets-1000e` `0.859/1.380 ms` (`0.622x`).

A later source-backed FlowScanner slice extended the same block-prefix independent-effect condition subset to table operations. Local Binaryen reduced exported-table positives where a result block does `table.size; drop; global.get $guard` or `ref.null func; i32.const 0; table.grow; drop; global.get $guard`, including the function-level `if return; set` variant, to immutable `$guard`; it deletes the `table.size` shell and preserves `table.grow` as `drop (table.grow ...)`. The paired negative keeps `$guard` mutable when the guarded value flows into the `table.grow` delta. Starshine now counts only those narrow table-op block bodies as safe and cleans the generated shells accordingly.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-prefix-tablesize.wat -o -
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-prefix-tablegrow.wat -o -
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-ifreturn-block-prefix-tablegrow.wat -o -
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-prefix-tablegrow-neg.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*block prefix*table*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*block prefix*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-block-prefix-table-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-block-prefix-table-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: the two red-first focused positives failed before implementation because `$once` stayed mutable; after implementation, focused block-prefix-table tests `3/3`, focused block-prefix tests `16/16`, full SGO tests `211/211`, `moon test src/passes` `4360/4360`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-block-prefix-table-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-block-prefix-table-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.528/1.603 ms` (`0.329x`), `runtime-set-get-1000f` `0.539/2.835 ms` (`0.190x`), `read-only-select-1000f` `1.758/3.953 ms` (`0.445x`), `initializer-fold-1000g` `0.464/1.027 ms` (`0.452x`), and `startup-offsets-1000e` `0.756/1.090 ms` (`0.693x`).

A follow-up table-op slice probed and implemented independent `table.fill` and `table.copy` block-prefix variants. Local Binaryen reduces `block { const dest; ref.null func; const len; table.fill; global.get $guard }; if { const; global.set $guard }`, `block { const dest; const src; const len; table.copy; global.get $guard }; if { const; global.set $guard }`, and the corresponding function-level `if return; set` tails to immutable `$guard`, preserving the table mutation. The paired `table.fill` negative keeps `$guard` mutable when the guarded value flows into the table destination. Starshine now counts only constant-argument `table.fill` / `table.copy` block bodies as safe and cleans the generated guarded-write and if-return shells. Red-first focused positives failed before implementation because `$once` stayed mutable; after implementation, focused table-fill/copy positives passed `2/2`, focused table tests `11/11`, full SGO tests `214/214`, `moon test src/passes` `4363/4363`, native `src/cmd` build passed with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-block-prefix-tablefill-copy-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-block-prefix-tablefill-copy-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still met the user-required 1x bar: `const-read-1000f` `0.506/1.606 ms` (`0.315x`), `runtime-set-get-1000f` `0.530/3.013 ms` (`0.176x`), `read-only-select-1000f` `1.735/3.526 ms` (`0.492x`), `initializer-fold-1000g` `0.455/1.088 ms` (`0.418x`), and `startup-offsets-1000e` `0.992/1.193 ms` (`0.832x`).

A later table-op FlowScanner slice probed and implemented independent `table.set`, `table.init`, and `elem.drop` block-prefix variants. Local Binaryen reduces `block { const dest; ref.null func; table.set; global.get $guard }`, `block { const dest; const src; const len; table.init; global.get $guard }`, `block { elem.drop; global.get $guard }`, and the corresponding function-level `if return; set` tails to immutable `$guard`, preserving the table/element mutation. The paired `table.set` and `table.init` negatives keep `$guard` mutable when the guarded value flows into the table operation. Starshine now counts only constant-argument `table.set` / `table.init` and argument-free `elem.drop` block bodies as safe and cleans the generated guarded-write and if-return shells. Red-first focused positives failed before implementation because `$once` stayed mutable; after implementation, focused `table.set` tests `3/3`, focused `table.init` tests `3/3`, focused table tests `17/17`, full SGO tests `220/220`, `moon test src/passes` `4369/4369`, native `src/cmd` build passed with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-block-prefix-tableset-init-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-block-prefix-tableset-init-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still met the user-required 1x bar: `const-read-1000f` `0.516/1.593 ms` (`0.324x`), `runtime-set-get-1000f` `0.530/2.749 ms` (`0.193x`), `read-only-select-1000f` `1.737/3.437 ms` (`0.505x`), `initializer-fold-1000g` `0.450/1.044 ms` (`0.431x`), and `startup-offsets-1000e` `0.784/1.100 ms` (`0.712x`).

A later source-backed FlowScanner slice extended the result-`if` safe-side-effect arm subset into Binaryen's function-level `if return; set` matcher: the side-effecting result `if` may read the guarded global in one arm, preserve independent effects in the other arm, and feed only the return guard before the final same-global constant write. Local Binaryen reduced `.tmp/sgo-ifarm-ifreturn.wat` to immutable `$once` plus `drop (call $foo)`, while `.tmp/sgo-ifarm-ifreturn-neg.wat` kept `$once` mutable when the global-derived result flowed through `local.tee` before the return guard. Starshine now counts that narrow result-if-arm if-return value-flow as safe without widening arbitrary side-effecting post-result operators.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-ifarm-ifreturn.wat -o -
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-ifarm-ifreturn-neg.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*if-arm if-return*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*if-arm*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-ifarm-ifreturn-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-ifarm-ifreturn-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: the red-first focused positive failed before implementation because `$once` stayed mutable; after implementation, focused if-arm-if-return tests `2/2`, focused if-arm tests `7/7`, full SGO tests `193/193`, `moon test src/passes` `4342/4342`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-ifarm-ifreturn-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-ifarm-ifreturn-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.512/1.564 ms` (`0.327x`), `runtime-set-get-1000f` `0.522/2.877 ms` (`0.181x`), `read-only-select-1000f` `1.703/3.606 ms` (`0.472x`), `initializer-fold-1000g` `0.461/1.049 ms` (`0.439x`), and `startup-offsets-1000e` `0.839/1.190 ms` (`0.706x`).

A later source-backed FlowScanner slice extended the result-`if` arm subset through one nested result-`if` arm. Local Binaryen reduced `.tmp/sgo-nested-ifarm.wat`, where an outer side-effecting result `if` has an `else` arm that is itself a side-effecting result `if` whose `else` arm reads `$once`, to immutable `$once` plus preserved independent calls; the guarded-global value still reaches only the final same-global guarded write. Starshine now accepts only a nested result `if` at the end of an arm after a prefix with no global references, then reuses the existing arm-local safe-read recognizer.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-nested-ifarm.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*nested safe-side-effect if-arm*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*if-arm*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-nested-ifarm-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-nested-ifarm-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: the red-first focused positive failed before implementation because `$once` stayed mutable; after implementation, focused nested-if-arm `1/1`, focused if-arm tests `8/8`, full SGO tests `194/194`, `moon test src/passes` `4343/4343`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-nested-ifarm-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-nested-ifarm-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.522/1.606 ms` (`0.325x`), `runtime-set-get-1000f` `0.519/2.823 ms` (`0.184x`), `read-only-select-1000f` `1.678/3.499 ms` (`0.479x`), `initializer-fold-1000g` `0.443/1.026 ms` (`0.432x`), and `startup-offsets-1000e` `0.861/0.996 ms` (`0.864x`).

A later source-backed FlowScanner slice widened the nested result-`if` arm subset by allowing the nested arm value to flow through pure operators before reaching the final guarded-write condition. Local Binaryen reduced `.tmp/sgo-probe2.wat`, where an outer side-effecting result `if` has an `else` arm that runs an independent call, executes a nested result `if` whose `then` arm reads `$once`, then applies `i32.const 4; i32.add`, to immutable `$once` while preserving independent effects. Starshine now accepts a no-global prefix before the nested result `if` and pure suffix operators after it; global-dependent prefixes, `local.tee`, calls consuming the guarded-global value, and other side-effecting suffixes remain outside this narrow subset.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe2.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*nested if-arm values through pure operators*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*if-arm*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-nested-ifarm-pure-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-nested-ifarm-pure-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: the red-first focused positive failed before implementation because `$once` stayed mutable; after implementation, focused nested-if-arm pure-suffix `1/1`, focused if-arm tests `9/9`, full SGO tests `195/195`, `moon test src/passes` `4344/4344`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-nested-ifarm-pure-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-nested-ifarm-pure-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.544/1.728 ms` (`0.315x`), `runtime-set-get-1000f` `0.556/3.269 ms` (`0.170x`), `read-only-select-1000f` `1.800/3.850 ms` (`0.467x`), `initializer-fold-1000g` `0.512/1.161 ms` (`0.441x`), and `startup-offsets-1000e` `1.408/1.544 ms` (`0.912x`).

A later source-backed FlowScanner slice extended the side-effecting `select; i32.eqz` subset into Binaryen's function-level `if return; set` matcher. Local Binaryen reduced `.tmp/sgo-select-ifreturn.wat`, where an independent `i32.load` / unused `local.tee` supplies a `select` operand and the guarded-global value flows only through the `select` condition, `i32.eqz`, and return guard before the final same-global constant write, to immutable `$guard` plus `drop (i32.load ...)`. Starshine now counts this narrow `select; i32.eqz; if return; const; global.set` value-flow as safe and adds SGO cheap cleanup for the resulting effect-only load shell; arbitrary values flowing into calls, `memory.grow`, local side effects, or later observable tail effects remain rejected.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-ifreturn.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select eqz if-return*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-select-ifreturn-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-select-ifreturn-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: the red-first focused positive failed before implementation because `$guard` stayed mutable; after implementation, focused select-eqz-if-return `1/1`, focused select tests `10/10`, full SGO tests `196/196`, `moon test src/passes` `4345/4345`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-select-ifreturn-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-select-ifreturn-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.501/1.568 ms` (`0.319x`), `runtime-set-get-1000f` `0.518/2.960 ms` (`0.175x`), `read-only-select-1000f` `1.719/3.537 ms` (`0.486x`), `initializer-fold-1000g` `0.437/1.001 ms` (`0.437x`), and `startup-offsets-1000e` `0.751/1.069 ms` (`0.703x`).

A later source-backed FlowScanner slice extended the independent zero-parameter/result call `select` operand subset into Binaryen's function-level `if return; set` matcher. Local Binaryen reduced `.tmp/sgo-select-call-ifreturn.wat`, where `global.get $guard; call $foo; const; select` feeds only a return guard before the final same-global constant write, to immutable `$guard` plus `drop (call $foo)`. Starshine now counts the first-operand independent-call `select; if return; const; global.set` form as safe and cleans the resulting `const; call; const; select; if return; const; drop` shell to `call; drop`; call-parameter value-flow remains rejected by existing guardrails.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-call-ifreturn.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select operand if-return read with independent call*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-select-call-ifreturn-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-select-call-ifreturn-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: the red-first focused positive failed before implementation because `$guard` stayed mutable; after implementation, focused select-call-if-return `1/1`, focused select tests `11/11`, full SGO tests `197/197`, `moon test src/passes` `4346/4346`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-select-call-ifreturn-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-select-call-ifreturn-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.518/1.593 ms` (`0.325x`), `runtime-set-get-1000f` `0.536/2.843 ms` (`0.188x`), `read-only-select-1000f` `1.770/3.607 ms` (`0.491x`), `initializer-fold-1000g` `0.454/1.075 ms` (`0.422x`), and `startup-offsets-1000e` `0.728/1.061 ms` (`0.686x`).

A later source-backed FlowScanner slice extended the independent memory-op `select` operand subset into the same function-level `if return; set` matcher. Local Binaryen reduced `.tmp/sgo-select-memory-ifreturn.wat` for all four direct operand forms (`global.get` with `memory.size` or constant-delta `memory.grow`, and the symmetric order) to immutable `$guard`, removing `memory.size` shells and preserving `memory.grow` as `drop (memory.grow (i32.const 0))`. Starshine now counts those narrow forms as safe and cleans the resulting SGO-created shells while keeping global-derived `memory.grow` deltas rejected by the existing negative.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-memory-ifreturn.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select operand if-return read with independent memory ops*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-select-memory-ifreturn-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-select-memory-ifreturn-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: the red-first focused positive failed before implementation because `$guard` stayed mutable; after implementation, focused select-memory-if-return `1/1`, focused select tests `12/12`, full SGO tests `198/198`, `moon test src/passes` `4347/4347`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-select-memory-ifreturn-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-select-memory-ifreturn-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.516/1.655 ms` (`0.312x`), `runtime-set-get-1000f` `0.544/2.813 ms` (`0.193x`), `read-only-select-1000f` `1.724/3.868 ms` (`0.446x`), `initializer-fold-1000g` `0.433/0.990 ms` (`0.437x`), and `startup-offsets-1000e` `0.766/1.057 ms` (`0.725x`).

A later source-backed FlowScanner slice covered the direct side-effecting independent-load `select` if-return form without the `i32.eqz` post-operator. Local Binaryen reduced `.tmp/sgo-select-load-ifreturn.wat`, where an independent `i32.load` / unused local shell supplies a `select` operand and the selected value reaches only `if { return }` before the same-global write, to immutable `$guard` plus `drop (i32.load (i32.const 2))`. Starshine now cleans both the pre-nested local shell and the nested-cleanup residual direct `select; if return` shell back to `i32.load; drop`; trapping load-address and global-derived local side-effect negatives remain rejected.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-load-ifreturn.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*side-effecting select if-return guards*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-select-load-ifreturn-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-select-load-ifreturn-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: the red-first focused positive failed before implementation because the final function still contained `select; if return`; after implementation, focused select-load-if-return `1/1`, focused select tests `13/13`, full SGO tests `199/199`, `moon test src/passes` `4348/4348`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-select-load-ifreturn-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-select-load-ifreturn-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.802/2.764 ms` (`0.290x`), `runtime-set-get-1000f` `0.977/4.412 ms` (`0.221x`), `read-only-select-1000f` `1.865/4.876 ms` (`0.382x`), `initializer-fold-1000g` `0.508/1.165 ms` (`0.436x`), and `startup-offsets-1000e` `1.090/1.557 ms` (`0.700x`).

A later source-backed FlowScanner slice extended block-prefix independent-effect conditions from calls, memory ops, and table ops to local writes whose stored value is independent of the guarded global. Local Binaryen reduced `.tmp/sgo-probe-block-localset.wat` and `.tmp/sgo-probe-ifreturn-block-localset.wat` to immutable `$guard`, while `.tmp/sgo-probe-block-localset-neg.wat` kept `$guard` mutable when the guarded global value flowed into the local write. Starshine now counts the narrow `const; local.set; global.get` and `const; local.tee; drop; global.get` result-block condition forms as safe for guarded-write and if-return tails, and cheap cleanup preserves the independent local write while deleting the fake global guard shell.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-localset.wat -o -
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-ifreturn-block-localset.wat -o -
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-localset-neg.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*block prefix*local*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*block prefix*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-block-prefix-local-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-block-prefix-local-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: the red-first focused positives failed before implementation because `$once` stayed mutable; after implementation, focused block-prefix local tests `3/3`, focused block-prefix tests `10/10`, full SGO tests `205/205`, `moon test src/passes` `4354/4354`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-block-prefix-local-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-block-prefix-local-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.504/1.532 ms` (`0.329x`), `runtime-set-get-1000f` `0.532/2.764 ms` (`0.193x`), `read-only-select-1000f` `1.729/3.285 ms` (`0.526x`), `initializer-fold-1000g` `0.452/1.008 ms` (`0.448x`), and `startup-offsets-1000e` `0.742/1.066 ms` (`0.697x`).

A later source-backed FlowScanner slice extended block-prefix independent-effect conditions to independent global writes whose stored value is independent of the guarded global. Local Binaryen reduced `.tmp/sgo-probe-block-prefix-globalset-export.wat` and `.tmp/sgo-probe-ifreturn-block-prefix-globalset-export.wat` to immutable `$guard` while preserving the exported `$other` write, and `.tmp/sgo-probe-block-prefix-globalset-neg.wat` kept `$guard` mutable when the guarded value flowed into that exported write. Starshine now counts the narrow `const; global.set $other; global.get $guard` result-block condition form as safe for guarded-write and if-return tails when `$other != $guard`, and cheap cleanup preserves the independent global write while deleting the fake guard shell.

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-prefix-globalset-export.wat -o -
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-ifreturn-block-prefix-globalset-export.wat -o -
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-prefix-globalset-neg.wat -o -
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*block prefix*global*'
moon fmt
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*block prefix*'
moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-block-prefix-global-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-block-prefix-global-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py
```

Results: the red-first focused positives failed before implementation because `$once` stayed mutable; after implementation, focused block-prefix global tests `3/3`, focused block-prefix tests `13/13`, full SGO tests `208/208`, `moon test src/passes` `4357/4357`, native `src/cmd` build with pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-block-prefix-global-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-block-prefix-global-dedicated-1000` `1000/1000` normalized with zero failures, and representative timing still under the user-required 1x bar: `const-read-1000f` `0.542/1.842 ms` (`0.295x`), `runtime-set-get-1000f` `0.571/3.160 ms` (`0.181x`), `read-only-select-1000f` `1.857/4.093 ms` (`0.454x`), `initializer-fold-1000g` `0.471/1.038 ms` (`0.454x`), and `startup-offsets-1000e` `0.798/1.143 ms` (`0.698x`).

A later source-backed FlowScanner slice added independent zero-parameter/result call operands flowing through `i32.eq` / `i32.ne` comparisons to both the direct guarded-write and function-level `if return; set` matchers. Local Binaryen probes reduced `global.get $guard; call $foo; i32.eq; if { const; global.set $guard }`, `call $foo; global.get $guard; i32.ne; if { const; global.set $guard }`, and `global.get $guard; call $foo; i32.ne; if { return }; const; global.set $guard` to immutable `$guard` plus `drop (call $foo)`, while the paired call-argument negative kept `$guard` mutable. Starshine now counts only those narrow independent call compare operands as safe and cleans the SGO-created compare/empty-if or compare/if-return shell to `call; drop`.

Validation for that slice: red-first focused positives failed before implementation because `$guard` stayed mutable; after implementation, focused independent-call compare tests `2/2`, the call-argument negative `1/1`, call-focused SGO tests `23/23`, full SGO tests `223/223`, `moon test src/passes` `4372/4372`, native `src/cmd` build passed with the pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-call-compare-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-call-compare-dedicated-1000` `1000/1000` normalized with zero failures, and bounded random-all smoke `.tmp/pass-fuzz-sgo-call-compare-random-all-1000` `1000/1000` normalized with zero failures. Representative timing after rebuilding native `src/cmd` still met 1x: `const-read-1000f` `0.532/1.604 ms` (`0.332x`), `runtime-set-get-1000f` `0.554/2.753 ms` (`0.201x`), `read-only-select-1000f` `1.843/3.528 ms` (`0.522x`), `initializer-fold-1000g` `0.460/1.029 ms` (`0.446x`), and `startup-offsets-1000e` `0.779/1.172 ms` (`0.665x`).

A later source-backed FlowScanner slice added independent memory-op operands flowing through `i32.eq` / `i32.ne` comparisons to both the direct guarded-write and function-level `if return; set` matchers. Local Binaryen probes reduced `global.get $guard; memory.size; i32.eq; if { const; global.set $guard }`, `memory.size; global.get $guard; i32.ne; if { const; global.set $guard }`, `global.get $guard; i32.const 0; memory.grow; i32.ne; if { return }; const; global.set $guard`, and the reverse constant-delta `memory.grow` operand order to immutable `$guard`; `memory.size` shells disappear, while `memory.grow` is preserved as `drop (memory.grow (i32.const 0))`. The paired negative where `$guard` flows into the `memory.grow` delta keeps `$guard` mutable.

Validation for that slice: red-first focused positives failed before implementation because `$guard` stayed mutable; after implementation, focused independent-memory compare positives `2/2`, the memory.grow-delta negative `1/1`, memory-focused SGO tests `11/11`, full SGO tests `226/226`, `moon test src/passes` `4375/4375`, native `src/cmd` build passed with the pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-memory-compare-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-memory-compare-dedicated-1000` `1000/1000` normalized with zero failures, bounded random-all smoke `.tmp/pass-fuzz-sgo-memory-compare-random-all-1000` `1000/1000` normalized with zero failures, and full `moon test` passed `7814/7814`. Representative timing after rebuilding native `src/cmd` still met 1x: `const-read-1000f` `0.553/2.002 ms` (`0.276x`), `runtime-set-get-1000f` `0.567/3.140 ms` (`0.180x`), `read-only-select-1000f` `1.994/4.037 ms` (`0.494x`), `initializer-fold-1000g` `0.480/1.075 ms` (`0.447x`), and `startup-offsets-1000e` `0.798/1.382 ms` (`0.578x`).

A later source-backed FlowScanner slice added independent table-op operands flowing through `i32.eq` / `i32.ne` comparisons to both the direct guarded-write and function-level `if return; set` matchers. Local Binaryen probes reduced direct and reverse `table.size` comparisons to immutable `$guard` with no remaining table query, and reduced direct and reverse constant-argument `table.grow` comparisons to immutable `$guard` while preserving the observable grow as `drop (table.grow (ref.null func) (i32.const 0))`. The paired negative where `$guard` flows into the `table.grow` delta keeps `$guard` mutable.

Validation for that slice: red-first focused positives failed before implementation because `$guard` stayed mutable; after implementation, focused independent-table compare positives `2/2`, the table.grow-delta negative `1/1`, table-focused SGO tests `20/20`, full SGO tests `229/229`, `moon test src/passes` `4378/4378`, native `src/cmd` build passed with the pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-table-compare-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-table-compare-dedicated-1000` `1000/1000` normalized with zero failures, and bounded random-all smoke `.tmp/pass-fuzz-sgo-table-compare-random-all-1000` `1000/1000` normalized with zero failures. Representative timing after rebuilding native `src/cmd` still met 1x: `const-read-1000f` `0.566/1.797 ms` (`0.315x`), `runtime-set-get-1000f` `0.585/3.151 ms` (`0.185x`), `read-only-select-1000f` `2.114/4.029 ms` (`0.525x`), `initializer-fold-1000g` `0.492/1.283 ms` (`0.384x`), and `startup-offsets-1000e` `0.808/1.199 ms` (`0.674x`).

A later source-backed FlowScanner slice added independent table-op operands flowing through `select` to both the direct guarded-write and function-level `if return; set` matchers. Local Binaryen probes reduced direct and reverse `table.size` select operands to immutable `$guard` with no remaining table query, and reduced direct and reverse constant-argument `table.grow` select operands to immutable `$guard` while preserving the observable grow as `drop (table.grow (ref.null func) (i32.const 0))`. The paired valid negative where `$guard` flows into the `table.grow` delta while a separate guarded read feeds the `select` keeps `$guard` mutable.

Validation for that slice: red-first focused positives failed before implementation because `$guard` stayed mutable; after implementation, focused independent-table select positives `2/2`, the table.grow-delta negative `1/1`, table-focused SGO tests `23/23`, full SGO tests `232/232`, `moon test src/passes` `4381/4381`, native `src/cmd` build passed with the pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-table-select-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-table-select-dedicated-1000` `1000/1000` normalized with zero failures (`same-init/dead-set` `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`), and bounded random-all smoke `.tmp/pass-fuzz-sgo-table-select-random-all-1000` `1000/1000` normalized with zero failures. Representative timing after rebuilding native `src/cmd` still met 1x: `const-read-1000f` `0.544/1.622 ms` (`0.335x`), `runtime-set-get-1000f` `0.568/2.993 ms` (`0.190x`), `read-only-select-1000f` `1.963/3.451 ms` (`0.569x`), `initializer-fold-1000g` `0.456/1.021 ms` (`0.446x`), and `startup-offsets-1000e` `0.762/1.033 ms` (`0.738x`).

A later source-backed FlowScanner slice added independent constant `local.tee` operands flowing through `select` to both the direct guarded-write and function-level `if return; set` matchers. Local Binaryen probes reduced direct and reverse `global.get $guard` / `i32.const 7; local.tee $tmp` select operand orders to immutable `$guard`; the optimizing cleanup removes the unused local write shell. The paired negatives keep `$guard` mutable when the guarded value flows into the `local.tee` value or when an extra guarded read after the select makes the read count unsafe. Starshine now counts only the narrow constant local-tee select operand forms as safe, and its SGO-created cheap cleanup deletes the generated unused `local.tee; select; empty-if` and `local.tee; select; if-return; drop` shells when the local is not referenced outside the matched region.

Validation for that slice: red-first focused positives failed before implementation because `$guard` stayed mutable; after implementation, focused independent-local-tee select positives `2/2`, local-tee select guardrails `2/2`, select-focused SGO tests `20/20`, full SGO tests `236/236`, `moon test src/passes` `4385/4385`, native `src/cmd` build passed with the pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-localtee-select-genvalid-1000` `1000/1000` normalized with zero failures, dedicated-profile smoke `.tmp/pass-fuzz-sgo-localtee-select-dedicated-1000` `1000/1000` normalized with zero failures (`same-init/dead-set` `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`), and bounded random-all smoke `.tmp/pass-fuzz-sgo-localtee-select-random-all-1000` `1000/1000` normalized with zero failures. Representative timing after rebuilding native `src/cmd` still met 1x: `const-read-1000f` `0.556/1.769 ms` (`0.315x`), `runtime-set-get-1000f` `0.585/3.200 ms` (`0.183x`), `read-only-select-1000f` `1.962/3.883 ms` (`0.505x`), `initializer-fold-1000g` `0.463/1.060 ms` (`0.437x`), and `startup-offsets-1000e` `0.780/1.152 ms` (`0.677x`).

A later pure-condition FlowScanner slice added non-trapping `local.get` operands as safe sibling values in guarded-write conditions. Local Binaryen `version_130` reduced `global.get $g; local.get $x; i32.add; if { const; global.set $g }` to immutable `$g` plus `nop`; before implementation Starshine left `$g` mutable. Starshine now treats `LocalGet` as a pure read-only-to-write condition instruction while preserving the existing `local.tee` / `local.set` side-effect guardrails.

Validation for that slice: red-first focused coverage failed before implementation because `$g` stayed mutable; after implementation, focused local-get pure-condition test `1/1`, focused pure-condition tests `28/28`, full SGO tests `247/247`, `moon fmt`, `moon test src/passes` `4396/4396`, native `src/cmd` build passed with the pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-localget-pure-genvalid-1000` `1000/1000` normalized with zero failures, and dedicated-profile smoke `.tmp/pass-fuzz-sgo-localget-pure-dedicated-1000` `1000/1000` normalized with zero failures. Representative timing after rebuilding native `src/cmd` still met 1x: `const-read-1000f` `0.550/1.690 ms` (`0.325x`), `runtime-set-get-1000f` `0.585/2.899 ms` (`0.202x`), `read-only-select-1000f` `1.992/3.472 ms` (`0.574x`), `initializer-fold-1000g` `0.456/1.008 ms` (`0.453x`), and `startup-offsets-1000e` `0.770/1.106 ms` (`0.696x`).

A later source-backed FlowScanner slice added independent constant `local.set` operands inside block conditions flowing through `i32.eq` / `i32.ne` comparisons to both the direct guarded-write and function-level `if return; set` matchers. Local Binaryen probes reduced direct/reverse `block { const; local.set $tmp; global.get $guard; local.get $tmp; i32.eq/ne }` guarded-write variants and the if-return variant to immutable `$guard`; the paired negative where `$guard` flows into the `local.set` kept `$guard` mutable. Starshine now counts only those narrow independent local-set compare operands as safe and cleans the generated block/compare/empty-if or terminal if-return shell while preserving the independent local write.

Validation for that slice: red-first focused positives failed before implementation because `$guard` stayed mutable; after implementation, focused independent-local-set compare positives `2/2`, the local-set value-flow negative `1/1`, local-set-focused SGO tests `3/3`, full SGO tests `255/255`, `moon fmt`, `moon test src/passes` `4404/4404`, native `src/cmd` build passed with the pre-existing `pass_manager.mbt` warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-localset-compare-genvalid-1000` `1000/1000` normalized with zero failures, and dedicated-profile smoke `.tmp/pass-fuzz-sgo-localset-compare-dedicated-1000` `1000/1000` normalized with zero failures. Representative timing after rebuilding native `src/cmd` still met 1x: `const-read-1000f` `0.544/1.778 ms` (`0.306x`), `runtime-set-get-1000f` `0.656/3.084 ms` (`0.213x`), `read-only-select-1000f` `2.275/4.107 ms` (`0.554x`), `initializer-fold-1000g` `0.506/1.103 ms` (`0.459x`), and `startup-offsets-1000e` `0.849/1.114 ms` (`0.763x`).

Full SGO closeout no longer has an open random-all mismatch lane, but it still needs the remaining broad `FlowScanner` transform-family classification/implementation and a final freshness decision on whether to rerun the older regular `100000`, dedicated `10000`, and wasm-smith `10000` lanes after the narrow cleanup and FlowScanner changes.

## 2026-07-06 pure-add grow select FlowScanner smoke

After widening the independent `memory.grow` / `table.grow` select-operand subset to accept nontrapping `i32.add` deltas over constants or `local.get`s, the direct smokes were rerun with the current `_build/native/release/build/cmd/cmd.exe`:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-pure-add-grow-select-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-pure-add-grow-select-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Results: both lanes requested/compared `1000/1000`, normalized `1000`, and had zero mismatches, validation failures, generator failures, property failures, or command failures. Binaryen cache was `1000` hits / `0` misses in both lanes. The dedicated lane selected same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

Representative pass-local timing after this slice still meets the user-requested `<=1x` Binaryen median target: `const-read` `0.557/1.620 ms` (`0.344x`), runtime propagation `0.621/2.728 ms` (`0.228x`), read-only-select `2.131/3.342 ms` (`0.638x`), initializer-folding `0.450/1.016 ms` (`0.443x`), and startup-offsets `0.780/1.104 ms` (`0.706x`).

## 2026-07-07 pure-add grow compare FlowScanner smoke

After widening the independent `memory.grow` / `table.grow` compare-operand subset to accept nontrapping `i32.add` deltas over constants or `local.get`s, including function-level `if return; set` tails, the direct smokes were rerun with the current `_build/native/release/build/cmd/cmd.exe`:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-pure-add-grow-compare-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-pure-add-grow-compare-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Results: both lanes requested/compared `1000/1000`, normalized `1000`, and had zero mismatches, validation failures, generator failures, property failures, or command failures. Binaryen cache was `1000` hits / `0` misses in both lanes. The dedicated lane selected same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

Representative pass-local timing after this slice still meets the user-requested `<=1x` Binaryen median target: `const-read` `0.452/1.116 ms` (`0.405x`), runtime propagation `0.525/1.809 ms` (`0.290x`), read-only-select `1.832/2.278 ms` (`0.804x`), initializer-folding `0.432/0.972 ms` (`0.444x`), and startup-offsets `0.632/0.849 ms` (`0.744x`).

## 2026-07-07 reverse pure-add grow select FlowScanner smoke

After widening the reverse/second-operand independent `memory.grow` / `table.grow` select subset to accept nontrapping `i32.add` deltas over constants or `local.get`s, including function-level `if return; set` tails, the direct smokes were rerun with the current `_build/native/release/build/cmd/cmd.exe`:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-reverse-pure-add-grow-select-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-reverse-pure-add-grow-select-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Results: both lanes requested/compared `1000/1000`, normalized `1000`, and had zero mismatches, validation failures, generator failures, property failures, or command failures. Binaryen cache was `1000` hits / `0` misses in both lanes. The dedicated lane selected same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

Representative pass-local timing after this slice still meets the user-requested `<=1x` Binaryen median target: `const-read` `0.465/1.092 ms` (`0.426x`), runtime propagation `0.512/1.947 ms` (`0.263x`), read-only-select `1.879/2.455 ms` (`0.765x`), initializer-folding `0.379/0.863 ms` (`0.439x`), and startup-offsets `0.637/0.889 ms` (`0.717x`).

## 2026-07-07 independent call `i32.add` FlowScanner smoke

After adding the source-backed parent/child FlowScanner subset where an independent zero-parameter/result call is the sibling operand of the guarded global under a pure `i32.add`, including reverse operand order and function-level `if return; set` tails, the direct smokes were rerun with the current `_build/native/release/build/cmd/cmd.exe`:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-call-add-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-call-add-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Results: both lanes requested/compared `1000/1000`, normalized `1000`, and had zero mismatches, validation failures, generator failures, property failures, or command failures. Binaryen cache was `1000` hits / `0` misses in both lanes. The dedicated lane selected same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

Representative pass-local timing after this slice still meets the user-requested `<=1x` Binaryen median target: `const-read` `0.478/1.121 ms` (`0.426x`), runtime propagation `0.556/1.895 ms` (`0.293x`), read-only-select `1.858/2.281 ms` (`0.815x`), initializer-folding `0.373/0.826 ms` (`0.452x`), and startup-offsets `0.628/0.875 ms` (`0.718x`).


## 2026-07-07 independent call nontrapping `i32` binary FlowScanner smoke

After probing broader parent/child `FlowScanner` behavior, Starshine widened the independent call sibling subset from only `i32.add` to the nontrapping pure `i32` binary operators accepted by local Binaryen `version_130`: `i32.add`, `i32.sub`, `i32.mul`, `i32.and`, `i32.or`, `i32.xor`, shifts, and rotates. Local `i32.div_s` / `i32.rem_u` probes kept `$guard` mutable and remain excluded.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-call-binary-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-call-binary-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Results: both lanes requested/compared `1000/1000`, normalized `1000`, and had zero mismatches, validation failures, generator failures, property failures, or command failures. Binaryen cache was `1000` hits / `0` misses in both lanes. The dedicated lane selected same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

Representative pass-local timing after this slice still meets the user-requested `<=1x` Binaryen median target: `const-read` `0.473/1.113 ms` (`0.425x`), runtime propagation `0.540/1.810 ms` (`0.298x`), read-only-select `1.893/2.168 ms` (`0.873x`), initializer-folding `0.373/0.879 ms` (`0.425x`), and startup-offsets `0.610/0.883 ms` (`0.691x`).

## 2026-07-07 independent call nontrapping `i32` binary `i32.eqz` suffix FlowScanner smoke

After probing the next pure-parent chain above independent call sibling operands, Starshine now accepts a narrow source-backed suffix where the nontrapping `i32` binary result flows through `i32.eqz` before the same-global guarded write or function-level `if return; set` tail. The independent call is still zero-parameter/one-result and preserved as `call; drop`; trapping `i32.div_s; i32.eqz` remains excluded.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-call-binary-eqz-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-call-binary-eqz-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Results: both lanes requested/compared `1000/1000`, normalized `1000`, and had zero mismatches, validation failures, generator failures, property failures, or command failures. Binaryen cache was `1000` hits / `0` misses in both lanes. The dedicated lane selected same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

Representative pass-local timing after this slice still meets the user-requested `<=1x` Binaryen median target: `const-read` `0.522/1.213 ms` (`0.430x`), runtime propagation `0.594/1.996 ms` (`0.298x`), read-only-select `2.057/2.550 ms` (`0.807x`), initializer-folding `0.399/0.919 ms` (`0.433x`), and startup-offsets `0.647/0.908 ms` (`0.713x`).

## 2026-07-07 independent call nontrapping `i32` binary unary-suffix FlowScanner smoke

After probing the next source-backed pure-parent step above independent call sibling operands, Starshine now accepts a single nontrapping integer-unary suffix where the nontrapping `i32` binary result flows through `i32.clz`, `i32.ctz`, or `i32.popcnt` before the same-global guarded write or function-level `if return; set` tail. The independent call is still zero-parameter/one-result and preserved as `call; drop`; trapping `i32.div_s; i32.clz` remains excluded.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-call-binary-unary-suffix-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-call-binary-unary-suffix-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Results: both lanes requested/compared `1000/1000`, normalized `1000`, and had zero mismatches, validation failures, generator failures, property failures, or command failures. Binaryen cache was `1000` hits / `0` misses in both lanes. The dedicated lane selected same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

Representative pass-local timing after this slice still meets the user-requested `<=1x` Binaryen median target: `const-read` `0.469/1.096 ms` (`0.428x`), runtime propagation `0.526/1.925 ms` (`0.273x`), read-only-select `1.941/2.298 ms` (`0.845x`), initializer-folding `0.379/0.862 ms` (`0.439x`), and startup-offsets `0.621/1.048 ms` (`0.593x`).

## 2026-07-07 independent call binary constant-fed comparison FlowScanner smoke

After local Binaryen `version_130` probes accepted one constant-fed `i32.eq` / `i32.ne` parent above the independent-call/nontrapping-`i32` binary result, Starshine added that narrow direct/reverse and guarded-write/if-return subset. The call remains zero-parameter/one-result and is preserved as `call; drop`; trapping `i32.div_s` plus the same comparison remains excluded.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-call-binary-compare-const-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-call-binary-compare-const-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures
```

Both lanes requested/compared `1000/1000`, normalized `1000`, and had zero mismatches, validation failures, generator failures, property failures, or command failures. Binaryen cache was `1000` hits / `0` misses in both lanes. The dedicated lane selected same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

Representative pass-local timing remained `<=1x` Binaryen median: `const-read` `0.506/1.136 ms` (`0.446x`), runtime propagation `0.569/1.845 ms` (`0.308x`), read-only-select `1.953/2.279 ms` (`0.857x`), initializer-folding `0.417/0.885 ms` (`0.471x`), and startup-offsets `0.669/0.937 ms` (`0.714x`).

## 2026-07-07 independent `i64` call binary suffix FlowScanner smoke

After local Binaryen probes accepted direct `i64.add; i64.eqz`, constant-first reverse `i64.mul; i64.eq`, and reverse if-return `i64.xor; i64.eqz`, Starshine added that narrow family and retained a trapping `i64.div_s; i64.eqz` negative.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-call-i64-binary-suffix-genvalid-1000-final --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-call-i64-binary-suffix-dedicated-1000-final --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Both lanes requested/compared `1000/1000`, normalized `1000`, and had zero mismatches, validation failures, generator failures, property failures, or command failures. Binaryen cache was `1000` hits / `0` misses in both lanes. Dedicated selections: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`.

Final post-fix timing remained `<=1x`: const-read `0.553/1.321 ms` (`0.419x`), runtime propagation `0.581/2.020 ms` (`0.287x`), read-only-select `2.162/2.577 ms` (`0.839x`), initializer folding `0.431/0.896 ms` (`0.481x`), startup offsets `0.769/0.957 ms` (`0.803x`).

## 2026-07-07 independent float call binary-comparison FlowScanner smoke

After local Binaryen `version_130` probes accepted independent `f32` / `f64` calls under IEEE float binary parents followed by one same-typed constant-fed float comparison, Starshine implemented direct/reverse binary operands, result-first/constant-first comparison order, guarded-write and if-return tails, including NaN-sensitive and float-divide shapes.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-call-float-binary-compare-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-call-float-binary-compare-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Both lanes requested/compared `1000/1000`, normalized `1000`, and had zero mismatches, validation failures, generator failures, property failures, or command failures. Binaryen cache was `1000` hits / `0` misses in both lanes. Dedicated selections: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`.

Representative pass-local timing remained `<=1x` Binaryen median: const-read `0.480/1.070 ms` (`0.448x`), runtime propagation `0.568/1.869 ms` (`0.304x`), read-only-select `2.265/3.314 ms` (`0.684x`), initializer folding `0.441/0.963 ms` (`0.458x`), and startup offsets `0.752/0.981 ms` (`0.766x`). The full four-lane closeout matrix remains stale relative to this narrow implementation and must be refreshed before declaring the audit complete.

## 2026-07-07 generic scalar parent-chain smoke

After replacing the one-suffix independent-call ceiling with a typed scalar straight-line parser, the ordinary and dedicated development lanes were rerun against the rebuilt native CLI:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-generic-scalar-parent-chain-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-generic-scalar-parent-chain-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Both lanes requested/compared `1000/1000`, normalized `1000`, and reported zero cleanup-normalized matches, mismatches, validation failures, generator failures, property failures, or command failures. Binaryen cache was `1000` hits / `0` misses in each lane. Dedicated selections: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`.

Post-change representative direct timing remained `<=1x`: const-read `0.497/1.138 ms` (`0.437x`), runtime propagation `0.601/1.870 ms` (`0.321x`), read-only-select `2.126/2.233 ms` (`0.952x`), initializer folding `0.405/0.896 ms` (`0.451x`), startup offsets `0.667/0.874 ms` (`0.762x`). The full regular, wasm-smith, dedicated, and random-all closeout lanes still require a final freshness rerun after the generic FlowScanner audit is finished.

## 2026-07-07 multiple constant-first parent-depth smoke

After adding LIFO constant-prefix consumption to the scalar parent parser and cleanup path:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-constant-first-parent-depth-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-constant-first-parent-depth-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Both lanes requested/compared `1000/1000`, normalized `1000`, and reported zero cleanup-normalized matches, mismatches, validation failures, generator failures, property failures, or command failures. Binaryen cache was `1000` hits / `0` misses. Dedicated selections: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`.

Representative timing remained `<=1x`: const-read `0.514/1.116 ms` (`0.461x`), runtime propagation `0.661/2.015 ms` (`0.328x`), read-only-select `2.271/2.455 ms` (`0.925x`), initializer folding `0.428/0.917 ms` (`0.467x`), startup offsets `0.673/0.975 ms` (`0.690x`). Final four-lane freshness remains outstanding.

## 2026-07-07 reverse pre-parent scalar fragment smoke

After cleanup learned to remove pure call-result unary/conversion fragments and replay trapping float-to-int conversions:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-reverse-preparent-unary-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-reverse-preparent-unary-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Both lanes requested/compared/normalized `1000/1000` and reported zero cleanup-normalized matches, mismatches, validation failures, generator failures, property failures, or command failures. Binaryen cache was `1000` hits / `0` misses. Dedicated selections: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`.

Post-change timing remained `<=1x`: const-read `0.512/1.143 ms` (`0.448x`), runtime propagation `0.617/1.937 ms` (`0.318x`), read-only-select `2.274/2.328 ms` (`0.977x`), initializer folding `0.423/0.893 ms` (`0.473x`), startup offsets `0.693/0.890 ms` (`0.778x`). The final regular `100000`, explicit wasm-smith `10000`, dedicated `10000`, and random-all `10000` lanes remain stale until the broader FlowScanner classification is complete.

## 2026-07-07 generic independent scalar producer smoke

After local Binaryen probes classified removable `memory.size`, replay-required constant-address scalar loads, and guarded-load-address dependence, the shared scalar fragment parser was widened beyond calls. The three positive regressions failed before implementation; focused pre-parent tests now pass `6/6`, full SGO passes `295/295`, and direct Binaryen/Starshine probe WAT matches exactly.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-generic-scalar-producer-post-rebase-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-generic-scalar-producer-post-rebase-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Both lanes requested/compared/normalized `1000/1000`, with zero cleanup-normalized matches, mismatches, validation failures, generator failures, property failures, or command failures. Binaryen cache was `1000` hits / `0` misses. Dedicated selections: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`.

After rebasing onto local `main` `c24acc74a`, rebuilding native `src/cmd`, and removing rejected-path replay allocations, the final 15-repeat timing remained `<=1x`: const-read `0.549/1.182 ms` (`0.465x`), runtime propagation `0.637/2.028 ms` (`0.314x`), read-only-select `2.417/2.465 ms` (`0.981x`), initializer folding `0.415/0.893 ms` (`0.465x`), startup offsets `0.875/0.877 ms` (`0.997x`). The tight read-only/startup margins require immediate timing after any further widening.

## 2026-07-07 bounded structured producer smoke

Direct v130 probes and red-first tests added bounded single-result numeric block/`if` producer coverage, including load/call replay and the guarded-result-if-condition negative. Post-change lanes:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-structured-producers-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-structured-producers-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Both requested/compared/normalized `1000/1000`, with zero compare-normalized matches, mismatches, validation/generator/property failures, or command failures. Binaryen cache was `1000/0` in both. Dedicated selections: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`. Fifteen-repeat timing remained `<=1x`: const-read `0.550/1.270 ms` (`0.433x`), runtime propagation `0.639/1.950 ms` (`0.327x`), read-only-select `2.404/2.428 ms` (`0.990x`), initializer folding `0.380/0.868 ms` (`0.438x`), startup offsets `0.833/0.896 ms` (`0.930x`). Final full four-lane freshness remains outstanding.

## 2026-07-07 structured memory-grow smoke

After adding bounded independent `memory.grow` result-block producers, the post-change lanes were:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-structured-grow-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-structured-grow-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Both requested/compared/normalized `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property failures, or command failures. Binaryen cache was `1000/0` in both. Dedicated selections were same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`. Fifteen-repeat timing remained `<=1x`; the tightest fixture was read-only-select at `2.331/2.425 ms` (`0.961x`).

## 2026-07-07 structured local-write and table-grow smoke

After adding one-use observable local-write cleanup and independent structured `table.grow` replay:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-structured-local-table-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-structured-local-table-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Both requested/compared/normalized `1000/1000`, with zero compare-normalized matches, mismatches, validation/generator/property failures, or command failures. Binaryen cache was `1000/0` in both. Dedicated selections were same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`. The first 15-repeat timing sample had read-only-select noise at `1.013x`; the immediate 31-repeat/5-warmup rerun met the strict target on all fixtures: const-read `0.516/1.177 ms` (`0.438x`), runtime `0.625/1.930 ms` (`0.324x`), read-only-select `2.342/2.357 ms` (`0.993x`), initializer `0.384/0.891 ms` (`0.431x`), startup `0.839/0.925 ms` (`0.907x`). The final four full-count lanes remain stale after this change.

## 2026-07-07 repeated-local and structured-control smoke

After adding exact repeated-constant local cleanup plus conservative replay for independent scalar loops and branchful result blocks:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-structured-control-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-structured-control-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Both requested/compared/normalized `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property failures, or command failures. Binaryen cache was `1000/0` in both. Dedicated selections were same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`. The accepted 31-repeat/5-warmup timing ratios were const-read `0.423x`, runtime `0.298x`, read-only-select `0.906x`, initializer `0.480x`, and startup `0.966x`.

## 2026-07-07 guarded structured value-flow smoke

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-guarded-structured-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-guarded-structured-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Both lanes requested/compared/normalized `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property failures, or command failures. Binaryen cache was `1000/0`; dedicated selections were `132/210/129/148/154/227`. The accepted 51-repeat/10-warmup timing ratios were const-read `0.470x`, runtime `0.340x`, read-only-select `0.977x`, initializer `0.450x`, and startup `0.932x`. Full-count final lanes remain stale after this code change.

## 2026-07-07 effectful result-if cleanup smoke

After the red-first `result-if; empty guarded-write if` cleanup fix, the regular lane `.tmp/pass-fuzz-sgo-effectful-result-if-genvalid-1000` and dedicated lane `.tmp/pass-fuzz-sgo-effectful-result-if-dedicated-1000` each requested, compared, and normalized `1000/1000`, with `0` cleanup-normalized matches, mismatches, validation/generator/property failures, or command failures. Binaryen cache was `1000` hits / `0` misses for each lane. Dedicated selected-profile counts were same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

These are bounded post-change smokes, not replacements for the stale final `100000` regular, `10000` wasm-smith, `10000` dedicated, and `10000` random-all matrix. Fresh timing also remains unresolved: the best unpinned 51-repeat/10-warmup post-change run measured read-only-select at `1.031x`, above the strict `<=1x` requirement.

## 2026-07-07 pure structured-parent and timing-recovery smoke

After adding red-first pure result-loop, nested pure structured-parent, and pure `try_table` carrier coverage, and after adding the exact whole-body read-only-select cleanup fast path, the final development lanes were rerun with `_build/native/release/build/cmd/cmd.exe`:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-structured-parent-final-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-structured-parent-final-dedicated-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Both lanes requested/compared/normalized `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property failures, or command failures. Binaryen cache was `1000/0` in both. Dedicated selections were same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

Fresh unpinned 51-repeat/10-warmup timing is green with significant margin: const-read `0.438x`, runtime propagation `0.327x`, read-only-select `0.430x`, initializer folding `0.444x`, and startup offsets `0.915x`. Artifact: `.tmp/sgo-current-audit/structured-parent-next/timing-final-51x.txt`.

## Final v130 closeout matrix

The final matrix used the rebuilt `_build/native/release/build/cmd/cmd.exe`, `--jobs auto`, persistent `.tmp/pass-fuzz-cache`, and no compare normalizers.

| Lane | Seed / profile | Requested / compared | Normalized / cleanup-normalized / mismatches | Failures and cache |
| --- | --- | ---: | ---: | --- |
| Regular GenValid | `0x5eed`, default | `100000 / 100000` | `100000 / 0 / 0` | zero validation/generator/property/command failures; Binaryen `100000/0` |
| Dedicated | `0x5eed`, `simplify-globals-optimizing-all` | `10000 / 10000` | `10000 / 0 / 0` | zero failures; Binaryen `10000/0` |
| wasm-smith | `0x5eed`, explicit `--wasm-smith` | `10000 / 9956` | `9956 / 0 / 0` | zero Starshine/validation/generator/property failures; `44` Binaryen/tool failures; wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failure `44/0` |
| Random all-profiles | `0x5555`, `random-all-profiles` | `10000 / 10000` | `10000 / 0 / 0` | zero failures; Binaryen `10000/0` |

Artifacts are `.tmp/pass-fuzz-sgo-final-genvalid-100000`, `.tmp/pass-fuzz-sgo-final-dedicated-10000`, `.tmp/pass-fuzz-sgo-final-wasm-smith-10000`, and `.tmp/pass-fuzz-sgo-final-random-all-10000`. The dedicated lane selected all six leaves: same-init/dead-set `1404`, runtime propagation `2206`, startup propagation `1445`, nested cleanup `1427`, initializer folding `1391`, and read-only-to-write `2127`. The random-all lane selected all 15 aggregate leaves; exact counts are preserved in `result.json` and research note `1555`.

The `44` wasm-smith non-compares are agent-classified Binaryen/tool failures: `binaryen-rec-group-zero` `39`, `binaryen-invalid-tag-index` `1`, `binaryen-table-index-out-of-range` `1`, and `binaryen-bad-section-size` `3`. They are not SGO semantic or output mismatches. Final closeout has zero raw mismatches, zero true semantic mismatches, zero Starshine command failures, and no unclassified comparison family.
