---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1072-2026-06-25-heap-store-optimization-allocation-heavy-performance-refresh.md
  - ./1082-2026-06-25-heap-store-optimization-regular-genvalid-100000.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../agent-todo.md
---

# HSO allocation-heavy scaling profile

## Question

Does the `1072` allocation-heavy slowdown look like a fixed overhead, a candidate-count scaling issue, or a whole-command artifact?

## Fixture family

Generated smaller siblings of the `1072` fixture under `.tmp/`:

- `.tmp/hso-allocation-heavy-scale-250-20260625.wat` (`67,571` bytes)
- `.tmp/hso-allocation-heavy-scale-500-20260625.wat` (`135,161` bytes)
- `.tmp/hso-allocation-heavy-scale-1000-20260625.wat` (`270,341` bytes)

Each function has one fresh `struct.new_default`, three same-local `struct.set` roots, and a final `i32.const 0`. The prior `1072` fixture is the same shape with `2000` functions / `6000` `struct.set` roots.

## Commands

For each size, three Starshine traced runs:

```sh
target/native/release/build/cmd/cmd.exe \
  --heap-store-optimization \
  --tracing pass \
  .tmp/hso-allocation-heavy-scale-<n>-20260625.wat \
  -o .tmp/hso-allocation-heavy-scale-<n>-20260625.star.<r>.wasm
wasm-tools validate --features all .tmp/hso-allocation-heavy-scale-<n>-20260625.star.<r>.wasm
```

For each size, three Binaryen pass-local runs:

```sh
wasm-opt --all-features --heap-store-optimization --debug \
  .tmp/hso-allocation-heavy-scale-<n>-20260625.wat \
  -o .tmp/hso-allocation-heavy-scale-<n>-20260625.bin.<r>.wasm
wasm-tools validate --features all .tmp/hso-allocation-heavy-scale-<n>-20260625.bin.<r>.wasm
```

The Starshine WAT path still prints the incidental `wat2wasm: not found` warning before using the internal fallback parser. All emitted wasm files validated.

## Results

| Functions | Starshine HSO pass-local median | Binaryen HSO pass-local median | Ratio | Starshine lift median | Starshine effects median | Starshine lower median |
|---:|---:|---:|---:|---:|---:|---:|
| 250 | `1.597ms` | `0.186ms` | `8.6x` | `2.015ms` | `0.855ms` | `1.125ms` |
| 500 | `2.962ms` | `0.503ms` | `5.9x` | `3.809ms` | `1.739ms` | `2.215ms` |
| 1000 | `5.904ms` | `0.791ms` | `7.5x` | `7.304ms` | `3.365ms` | `4.334ms` |
| 2000 (`1072`) | `11.988ms` | `2.110ms` | `5.7x` | `15.018ms` | `6.928ms` | `9.036ms` |

Raw Starshine HSO pass-local samples:

- 250 functions: `1.605ms`, `1.597ms`, `1.478ms`
- 500 functions: `2.915ms`, `2.962ms`, `3.145ms`
- 1000 functions: `6.481ms`, `5.904ms`, `5.796ms`
- 2000 functions from `1072`: `11.876ms`, `12.083ms`, `11.988ms`

Raw Binaryen HSO pass-local samples:

- 250 functions: `0.186ms`, `0.209ms`, `0.181ms`
- 500 functions: `0.558ms`, `0.350ms`, `0.503ms`
- 1000 functions: `0.667ms`, `0.791ms`, `1.123ms`
- 2000 functions from `1072`: `1.856ms`, `2.118ms`, `2.110ms`

## Interpretation

The slowdown scales roughly linearly with the number of small candidate functions. Starshine HSO proper stays near `5.9us` per function at 500-2000 functions, while Binaryen stays roughly around `0.8us`-`1.1us` per function at 1000-2000 functions on this shape. This keeps HSO-I open: it is an HSO-owned per-candidate/per-function cost, not just a one-time startup or O4z no-candidate artifact.

The surrounding hot-pipeline costs also scale linearly and are larger than the pass-local timer (`lift`, `analysis:effects`, and `lower`), but HSO-I's pass-local target is still missed without counting those costs.

Likely next investigation targets in `src/passes/heap_store_optimization.mbt`:

- the unconditional pre-rewrite recursive region scan in `hso_process_region` / `hso_process_node_regions`, which traverses every simple root before the actual local-set chain pass;
- per-function `HsoPredicateCache` and `HsoTypeCache` allocation, which is cheap per function but visible on thousands of tiny functions;
- repeated safety predicate calls in `hso_try_fold_into_struct_new` for the simple no-effect `struct.new_default` / constant-store shape.

Do not relax correctness guards to chase this target. A performance fix should keep the current green direct lanes, especially the regular 100000-case lane from `1082` and the dedicated/random/wasm-smith lanes from `1073`, `1078`, and `1080`.
