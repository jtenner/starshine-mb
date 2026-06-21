# 0870 - Heap Store Optimization Allocation-Heavy Candidate Performance

Date: 2026-06-20

## Question

HSO-I still needed allocation-heavy candidate performance evidence. Existing `0847` evidence covered generated O4z predecessor artifacts where HSO raw-fast-skipped with no candidates, but did not measure a module that forces many fresh-struct `struct.set` folds.

This note records a synthetic allocation-heavy candidate probe. It is performance evidence only: it does not change Starshine behavior, does not close HSO-I, and does not replace final direct compare or O4z closeout evidence.

## Fixture

Generated temporary fixture:

- `.tmp/hso-allocation-heavy-candidates-2000.wat`
- 2000 functions.
- One mutable 3-field struct type.
- Each function does:
  - `local.set $x (struct.new_default $s)`
  - three `struct.set $s <field> (local.get $x) (i32.const ...)` roots
  - `i32.const 0`

Generator command:

```sh
python3 - <<'PY'
from pathlib import Path
n=2000
p=Path('.tmp/hso-allocation-heavy-candidates-2000.wat')
with p.open('w') as f:
    f.write('(module\n')
    f.write('  (type $s (struct (field (mut i32)) (field (mut i32)) (field (mut i32))))\n')
    for i in range(n):
        f.write(f'  (func $f{i} (result i32) (local $x (ref null $s))\n')
        f.write('    (local.set $x (struct.new_default $s))\n')
        f.write(f'    (struct.set $s 0 (local.get $x) (i32.const {i & 127}))\n')
        f.write(f'    (struct.set $s 1 (local.get $x) (i32.const {(i+1) & 127}))\n')
        f.write(f'    (struct.set $s 2 (local.get $x) (i32.const {(i+2) & 127}))\n')
        f.write('    (i32.const 0))\n')
    f.write(')\n')
print(p, p.stat().st_size)
PY
```

The generated WAT size was `541758` bytes.

## Commands and results

### Starshine pass-local trace

Command shape, run three times:

```sh
target/native/release/build/cmd/cmd.exe \
  --heap-store-optimization \
  --tracing pass \
  .tmp/hso-allocation-heavy-candidates-2000.wat \
  -o .tmp/hso-allocation-heavy-candidates-2000.star.<n>.wasm
```

Starshine's WAT path printed the known incidental `wat2wasm: not found` shell warning but still decoded/lowered the text input and emitted wasm.

| Run | `lift` total | `analysis:effects` total | `pass:heap-store-optimization` total | `lower` total |
| --- | ---: | ---: | ---: | ---: |
| 1 | `15638us` | `7223us` | `10968us` | `8727us` |
| 2 | `14974us` | `6944us` | `10167us` | `8801us` |
| 3 | `15460us` | `7147us` | `10996us` | `9068us` |

Pass-local median for Starshine HSO proper: about `10.968ms`.

### Binaryen pass-local debug timing

Command shape, run three times:

```sh
wasm-opt --all-features --heap-store-optimization --debug \
  .tmp/hso-allocation-heavy-candidates-2000.wat \
  -o .tmp/hso-allocation-heavy-candidates-2000.bin.<n>.wasm
```

Binaryen reported:

| Run | `heap-store-optimization` pass time |
| --- | ---: |
| 1 | `0.00130973s` |
| 2 | `0.0012949s` |
| 3 | `0.00210708s` |

Pass-local median for Binaryen HSO: about `1.31ms`.

### Coarse whole-command timing

The container did not have `/usr/bin/time`, so this used Bash `time` with output redirected away from the command.

Starshine command shape:

```sh
TIMEFORMAT='elapsed %R user %U sys %S'
time target/native/release/build/cmd/cmd.exe \
  --heap-store-optimization \
  .tmp/hso-allocation-heavy-candidates-2000.wat \
  -o .tmp/hso-wall-star.<n>.wasm
```

Starshine elapsed wall time: `0.074s`, `0.073s`, `0.074s`.

Binaryen command shape:

```sh
TIMEFORMAT='elapsed %R user %U sys %S'
time wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-allocation-heavy-candidates-2000.wat \
  -o .tmp/hso-wall-bin.<n>.wasm
```

Binaryen elapsed wall time: `0.030s`, `0.030s`, `0.029s`.

## Validation and output-shape note

Validated emitted outputs:

```sh
wasm-tools validate --features all .tmp/hso-allocation-heavy-candidates-2000.star.1.wasm
wasm-tools validate --features all .tmp/hso-allocation-heavy-candidates-2000.bin.1.wasm
```

Both commands passed.

Post-pass Binaryen metrics on Binaryen output:

```text
[funcs] 2000
[vars] 2000
Block 2000
Const 8000
LocalSet 2000
Nop 6000
StructNew 2000
```

Post-pass Binaryen metrics on Starshine output:

```text
[funcs] 2000
[vars] 2000
Block 2000
Const 8000
LocalSet 2000
StructNew 2000
```

This confirms both tools removed the 6000 `StructSet` roots on this synthetic fixture. Starshine also removed/normally avoided the 6000 `Nop` debris that Binaryen left after HSO. That output-shape difference is not classified here as a broad HSO Starshine win; it is a narrow observation on this synthetic fixture and still requires ordinary compare/signoff classification if it appears in pass-fuzz lanes.

## Interpretation

This fills the missing HSO-I allocation-heavy candidate measurement with an intentionally candidate-dense fixture.

Findings:

- Starshine handles the allocation-heavy candidate fixture correctly enough to validate and remove the 6000 `StructSet` roots.
- Starshine HSO proper is substantially slower than Binaryen on this synthetic candidate-heavy module: median about `10.97ms` vs `1.31ms` pass-local.
- Including HOT lift/effects/lower makes the Starshine direct HSO segment roughly `42ms` of traced local pipeline work for this fixture.
- Coarse whole-command elapsed wall time is also slower: about `0.074s` vs Binaryen `0.030s`.
- HSO-I should remain open as a performance follow-up. This evidence is not a closeout.

## Reopening / follow-up criteria

Keep HSO-I open until at least one of these is true:

- candidate-heavy pass-local performance is improved or accepted with rationale;
- a broader artifact/neighborhood measurement shows this synthetic slowdown is not release-relevant;
- final HSO closeout records explicit pass-local and whole-command timing for direct compare and O4z slot/neighborhood evidence.

Potential next performance questions:

- whether per-function HOT lift/lower dominates candidate-heavy HSO more than the fold proof itself;
- whether no-candidate raw-fast-skip remains enough for ordinary O4z slots, while allocation-heavy modules need separate optimization;
- whether Starshine's nop-free output shape gives downstream size/cleanup wins sufficient to justify some pass-local cost on real artifacts.
