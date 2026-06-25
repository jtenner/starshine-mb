---
kind: research
status: active
created: 2026-06-25
sources:
  - ./0870-2026-06-20-heap-store-optimization-allocation-heavy-performance.md
  - ./1071-2026-06-25-heap-store-optimization-direct-o4z-refresh.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# `heap-store-optimization` allocation-heavy performance refresh

## Question

Refresh HSO-I candidate-heavy performance evidence after the old-field generator coverage through `1070` and the explicit native binary rebuild from `1071`.

## Answer

The candidate-heavy synthetic fixture still validates and still removes all fresh-struct `struct.set` roots, but Starshine HSO remains slower than Binaryen pass-local on this allocation-heavy shape. The gap narrowed from the older `0870` run because local Binaryen measured slower this time, but the refreshed median still misses the pass-local target (`~11.99ms` Starshine HSO vs `~2.11ms` Binaryen HSO, about `5.7x` slower; target is at most `2x`). HSO-I remains open.

This result does not conflict with the no-candidate O4z slot evidence from `1071`: generated O4z predecessor artifacts raw-fast-skip HSO at `0.000ms`, while this fixture intentionally creates 2000 fresh candidates and 6000 same-local `struct.set` roots.

## Fixture

Regenerated temporary fixture:

- `.tmp/hso-allocation-heavy-candidates-2000-20260625.wat`
- 2000 functions
- one mutable 3-field struct type
- each function performs `local.set $x (struct.new_default $s)`, then three same-local `struct.set` roots, then returns `i32.const 0`
- WAT size: `541758` bytes

Generation command shape:

```sh
python3 - <<'PY'
from pathlib import Path
n=2000
p=Path('.tmp/hso-allocation-heavy-candidates-2000-20260625.wat')
with p.open('w') as f:
    f.write('(module\\n')
    f.write('  (type $s (struct (field (mut i32)) (field (mut i32)) (field (mut i32))))\\n')
    for i in range(n):
        f.write(f'  (func $f{i} (result i32) (local $x (ref null $s))\\n')
        f.write('    (local.set $x (struct.new_default $s))\\n')
        f.write(f'    (struct.set $s 0 (local.get $x) (i32.const {i & 127}))\\n')
        f.write(f'    (struct.set $s 1 (local.get $x) (i32.const {(i+1) & 127}))\\n')
        f.write(f'    (struct.set $s 2 (local.get $x) (i32.const {(i+2) & 127}))\\n')
        f.write('    (i32.const 0))\\n')
    f.write(')\\n')
print(p, p.stat().st_size)
PY
```

## Starshine traced timings

Command shape, run three times:

```sh
target/native/release/build/cmd/cmd.exe \
  --heap-store-optimization \
  --tracing pass \
  .tmp/hso-allocation-heavy-candidates-2000-20260625.wat \
  -o .tmp/hso-allocation-heavy-candidates-2000-20260625.star.<n>.wasm
```

Each emitted wasm validated with `wasm-tools validate --features all`.

| Run | `lift` total | `analysis:effects` total | `pass:heap-store-optimization` total | `lower` total |
|---|---:|---:|---:|---:|
| 1 | `15001us` | `6928us` | `11876us` | `8893us` |
| 2 | `15200us` | `7046us` | `12083us` | `9189us` |
| 3 | `15018us` | `6880us` | `11988us` | `9036us` |
| median | `15018us` | `6928us` | `11988us` | `9036us` |

Starshine's WAT input path still prints the incidental `wat2wasm: not found` shell warning before falling back to internal parsing; the emitted wasm files validate.

## Binaryen pass-local timings

Command shape, run three times:

```sh
wasm-opt --all-features --heap-store-optimization --debug \
  .tmp/hso-allocation-heavy-candidates-2000-20260625.wat \
  -o .tmp/hso-allocation-heavy-candidates-2000-20260625.bin.<n>.wasm
```

Each emitted wasm validated with `wasm-tools validate --features all`.

| Run | Binaryen HSO pass time |
|---|---:|
| 1 | `1.856ms` |
| 2 | `2.118ms` |
| 3 | `2.110ms` |
| median | `2.110ms` |

## Coarse whole-command wall timings

Command shape used Bash `time` because `/usr/bin/time` is not available in this container.

Starshine:

```sh
TIMEFORMAT='elapsed %R user %U sys %S'
time target/native/release/build/cmd/cmd.exe \
  --heap-store-optimization \
  .tmp/hso-allocation-heavy-candidates-2000-20260625.wat \
  -o .tmp/hso-wall-20260625-star.<n>.wasm
```

Binaryen:

```sh
TIMEFORMAT='elapsed %R user %U sys %S'
time wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-allocation-heavy-candidates-2000-20260625.wat \
  -o .tmp/hso-wall-20260625-bin.<n>.wasm
```

| Tool | Run 1 | Run 2 | Run 3 | Median elapsed |
|---|---:|---:|---:|---:|
| Starshine | `0.079s` | `0.080s` | `0.078s` | `0.079s` |
| Binaryen | `0.030s` | `0.031s` | `0.032s` | `0.031s` |

## Interpretation

- Correctness smoke: both tools emitted wasm that validates on each run.
- Candidate-heavy pass-local performance remains an HSO-owned follow-up: refreshed Starshine HSO proper is about `5.7x` slower than Binaryen on this synthetic candidate-heavy fixture, above the pass workflow target of `<=2x` Binaryen pass-local time.
- Whole-command elapsed time remains slower as well: median `0.079s` Starshine vs `0.031s` Binaryen.
- The refreshed O4z slot replay in `1071` remains important release evidence for current generated no-candidate slots, but it does not supersede this candidate-heavy slowdown.

## Follow-up

Keep HSO-I open until at least one of these happens:

- candidate-heavy pass-local performance improves to within the pass workflow target;
- the user explicitly accepts the candidate-heavy slowdown with rationale;
- broader artifact/neighborhood timing proves this synthetic slowdown is not release-relevant and records reopening criteria.
