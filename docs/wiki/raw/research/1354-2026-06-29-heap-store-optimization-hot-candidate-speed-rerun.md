---
kind: research
status: current
last_reviewed: 2026-06-29
sources:
  - ./1139-2026-06-25-heap-store-optimization-hot-candidate-benchmark.md
  - ../../../agent-todo.md
---

# HSO hot-candidate speed rerun after OI work

## Question

After the later `optimize-instructions` work, does the reopened `heap-store-optimization` HOT-path speed blocker still need implementation work?

## Answer

Yes. The same 2000-function plain `struct.new` candidate fixture still runs the HSO HOT path, still produces normalized output equal to Binaryen, and still misses both the user-requested `0.95x` Binaryen speed target and the repo's default `50%` Binaryen-speed pass-local target.

Seven fresh runs on 2026-06-29 with the rebuilt current native binary produced a Starshine pass-local median of `10.350ms` versus Binaryen `1.154ms`. That is `8.969x` Binaryen time, or `0.112x` Binaryen speed. The `0.95x` target for this sample is about `<=1.215ms` Starshine pass-local time, and the repo's default `50%` speed floor would be `<=2.308ms`; current Starshine is still well above both.

## Commands

Rebuilt the current native Starshine binary first, because `target/native/release/build/cmd/cmd.exe` was stale in this checkout while `_build/native/release/build/cmd/cmd.exe` was refreshed by `moon build`:

```sh
moon build --target native --release src/cmd
wasm-tools validate --features all .tmp/hso-hot-plain-struct-new-candidates-2000-20260625.wat
rm -rf .tmp/hso-hot-plain-struct-new-benchmark-rerun-20260629
mkdir -p .tmp/hso-hot-plain-struct-new-benchmark-rerun-20260629
for n in 1 2 3 4 5 6 7; do
  bun scripts/self-optimize-compare.ts \
    .tmp/hso-hot-plain-struct-new-candidates-2000-20260625.wat \
    --starshine-bin _build/native/release/build/cmd/cmd.exe \
    --out-dir .tmp/hso-hot-plain-struct-new-benchmark-rerun-20260629/run-$n \
    --heap-store-optimization
done
```

The build completed with the existing warning set. Fixture validation passed with no output.

## Results

Every run reported:

- `Starshine pass skipped raw: no`
- `Normalized WAT equal: yes`
- `Canonical function compare equal: yes`
- `Starshine pass at least as fast: no`

| Run | Starshine pass ms | Binaryen pass ms | Starshine wall ms | Binaryen wall ms |
|---:|---:|---:|---:|---:|
| 1 | `10.010` | `0.971` | `131.043` | `40.102` |
| 2 | `10.385` | `1.002` | `135.755` | `29.119` |
| 3 | `10.731` | `1.154` | `139.418` | `30.061` |
| 4 | `10.201` | `1.663` | `131.617` | `29.260` |
| 5 | `10.725` | `1.007` | `139.085` | `29.691` |
| 6 | `10.350` | `1.602` | `134.043` | `30.126` |
| 7 | `10.226` | `1.716` | `134.144` | `30.023` |

Medians:

- Starshine pass-local: `10.350ms`
- Binaryen pass-local: `1.154ms`
- Starshine/Binaryen pass-local ratio: `8.969x` slower
- Starshine speed relative to Binaryen: `0.112x`
- `0.95x` speed target for this fixture: about `<=1.215ms` Starshine median
- `50%` speed floor for this fixture: about `<=2.308ms` Starshine median
- Starshine whole-command wall median: `135.755ms`
- Binaryen whole-command wall median: `30.023ms`

## Interpretation

The HSO speed blocker is still real and should remain open. The current result is slightly better than the 2026-06-25 `1139` median (`10.738ms` Starshine vs `1.036ms` Binaryen, `10.365x` slower), but not enough to change actionability. HSO needs a HOT-path candidate performance implementation slice or explicit user approval for a narrower speed target before HSO-J can be reclosed.
