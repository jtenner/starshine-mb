---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1110-2026-06-25-heap-store-optimization-post-exact-refcast-compare.md
  - ./1109-2026-06-25-heap-store-optimization-exact-ref-cast-closure.md
  - ./1092-2026-06-25-heap-store-optimization-simple-skip-fast-path.md
  - ./1084-2026-06-25-heap-store-optimization-allocation-heavy-scaling.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# HSO post-refcast allocation-heavy performance refresh

## Question

Did the exact `ref.cast` surface work from `1109` change the current HSO-I allocation-heavy performance disposition?

## Answer

No. The exact-cast work did not target the allocation-heavy path, and the refreshed 1000/2000-function synthetic fixtures still miss the pass-local target (`starshine_time <= 2 * binaryen_time`). Starshine remains roughly `5.3x` slower than Binaryen on the 2000-function fixture, so HSO-I stays open.

The rerun is still useful as current post-`1109` evidence: all Starshine and Binaryen outputs validated, and Starshine's 2000-function HSO median is slightly lower than the last documented `1092` median but not enough to alter the classification.

## Commands

Reused the existing allocation-heavy fixtures:

- `.tmp/hso-allocation-heavy-scale-1000-20260625.wat`
- `.tmp/hso-allocation-heavy-candidates-2000-20260625.wat`

For each fixture and each of three runs:

```sh
target/native/release/build/cmd/cmd.exe \
  --heap-store-optimization \
  --tracing pass \
  <fixture.wat> \
  -o .tmp/hso-post-refcast-perf-<n>.star.<r>.wasm
wasm-tools validate --features all .tmp/hso-post-refcast-perf-<n>.star.<r>.wasm

wasm-opt --all-features --heap-store-optimization --debug \
  <fixture.wat> \
  -o .tmp/hso-post-refcast-perf-<n>.bin.<r>.wasm
wasm-tools validate --features all .tmp/hso-post-refcast-perf-<n>.bin.<r>.wasm
```

The Starshine WAT input path still prints the incidental `wat2wasm: not found` warning before falling back to internal parsing.

## Results

| Functions | Starshine HSO samples | Starshine HSO median | Binaryen HSO samples | Binaryen HSO median | Ratio |
|---:|---:|---:|---:|---:|---:|
| 1000 | `5.561ms`, `5.451ms`, `5.465ms` | `5.465ms` | `0.761ms`, `0.820ms`, `0.640ms` | `0.761ms` | `~7.2x` |
| 2000 | `10.969ms`, `10.765ms`, `10.615ms` | `10.765ms` | `1.352ms`, `2.028ms`, `2.028ms` | `2.028ms` | `~5.3x` |

Starshine surrounding phase medians:

| Functions | lift median | effects median | lower median |
|---:|---:|---:|---:|
| 1000 | `7.305ms` | `3.412ms` | `4.379ms` |
| 2000 | `14.266ms` | `6.716ms` | `8.384ms` |

## Comparison to latest documented performance slice

`1092` measured:

- 1000-function Starshine HSO median `5.436ms`;
- 2000-function Starshine HSO median `11.201ms`; and
- 2000-function ratio `~5.3x` Binaryen.

The new 2000-function median (`10.765ms`) is a small local improvement/noise-range movement, not a structural fix. HSO-I remains open until the pass-local target is met, the slowdown is explicitly accepted with rationale, or broader artifact/neighborhood timing supersedes this synthetic candidate-heavy fixture with reopening criteria.
