# 1398 - remove-unused-brs post-RUB-X perf metrics

Date: 2026-06-29

## Scope

After closing `[O4Z-AUDIT-RUB-R]` through `[O4Z-AUDIT-RUB-X]`, this note records bounded direct `remove-unused-brs` performance metrics against Binaryen.

This is a perf sample, not a new semantic closeout lane. The accepted note-`1392` dead-shell cleanup remains intentionally preserved as a Starshine win; this perf check does not require restoring Binaryen's dead shells.

## Setup

Built current native Starshine before timing:

```sh
moon build --target native --release src/cmd
```

Result: passed. The build reported existing unused-function warnings in `src/passes/pass_manager.mbt`; no build errors.

Timing command shape:

```sh
bun scripts/self-optimize-compare.ts <input.wasm> \
  --out-dir .tmp/perf-rub-<case>-<run> \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --timing-only \
  --remove-unused-brs
```

Each input used five timing-only runs. Starshine skipped the raw RUB path in every sampled run (`Starshine pass skipped raw: yes`).

## Results

### `tests/repros/o4z-debug-startup-map-init-repro.wasm`

| Metric | Starshine median | Binaryen median | Starshine / Binaryen |
| --- | ---: | ---: | ---: |
| Whole command runtime | `8.681 ms` | `9.020 ms` | `0.949x` |
| Pass-local runtime | `0.715 ms` | `0.686 ms` | `1.039x` |

Per-run pass-local ratios: `0.918x`, `1.039x`, `0.728x`, `1.099x`, `1.215x`.

Interpretation: whole-command median is slightly faster than Binaryen, and pass-local runtime is effectively at parity on this sample. Mean pass-local ratio was `1.000x` across the five runs.

A later non-timing normalized check for this input reported `Normalized WAT equal: no` and `Canonical function compare equal: no`, so use this input as a timing stress sample rather than parity evidence.

### `tests/repros/o4z-slot42-merge-blocks-f1355-nodata.wasm`

| Metric | Starshine median | Binaryen median | Starshine / Binaryen |
| --- | ---: | ---: | ---: |
| Whole command runtime | `11.005 ms` | `6.841 ms` | `1.609x` |
| Pass-local runtime | `1.154 ms` | `0.930 ms` | `1.255x` |

Per-run pass-local ratios: `1.028x`, `1.255x`, `1.516x`, `1.568x`, `1.096x`.

Interpretation: pass-local runtime is slower than Binaryen but within the repo target of `<= 2x` Binaryen. Whole-command runtime is slower too; median Starshine non-pass overhead dominated the delta, with `5.483 ms` other traced runtime and `4.396 ms` untraced/runtime overhead.

A non-timing normalized check for this input reported `Normalized WAT equal: yes` and `Canonical function compare equal: yes`, so this is the better correctness-aligned perf sample.

## Validation commands

- `moon build --target native --release src/cmd`: passed with existing unused-function warnings.
- Five timing-only `self-optimize-compare` runs each for `o4z-debug-startup-map-init-repro.wasm` and `o4z-slot42-merge-blocks-f1355-nodata.wasm`: completed and wrote artifacts under `.tmp/perf-rub-*`.
- Non-timing normalized checks for both inputs: startup sample not normalized-equal; slot42 sample normalized-equal and canonical-function-equal.

## Takeaways

- Current direct `remove-unused-brs` pass-local performance remains within the repository target on both sampled repros.
- The slot42 sample is slower than Binaryen but still `1.255x` median pass-local, below the `2x` ceiling.
- Whole-command timing can diverge from pass-local timing because Starshine still reports substantial non-pass traced and untraced overhead on the slot42 sample.
- No behavior changes were made for this perf note.
