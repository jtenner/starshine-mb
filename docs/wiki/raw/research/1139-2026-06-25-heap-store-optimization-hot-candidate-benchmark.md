---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1138-2026-06-25-heap-store-optimization-final-closeout.md
  - ./1137-2026-06-25-heap-store-optimization-final-compare-matrix.md
  - ./1135-2026-06-25-heap-store-optimization-post-raw-complete-validation.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# HSO hot-candidate benchmark reopening

## Question

Does the raw complete-default-chain speed evidence from `1135` prove that the `heap-store-optimization` pass itself is fast enough on inputs that actually run the HOT HSO path?

## Answer

No. The `1135` raw-skip evidence was too narrow to close HSO-I/HSO-J on speed parity. A proper hot-candidate benchmark that bypasses the raw complete-default-chain path shows Starshine direct HSO remains much slower than Binaryen pass-local time.

On a 2000-function plain `struct.new` fixture with two same-local `struct.set` folds per function, Starshine did not raw-skip, normalized output matched Binaryen on every run, but Starshine pass-local median was `10.738ms` versus Binaryen median `1.036ms`. That is about `10.365x` Binaryen time, or only `0.096x` Binaryen speed. Under the user's `0.95x` speed target, the Starshine target for this fixture is about `<=1.091ms`, so HSO-I must be reopened for HOT-path candidate performance and HSO-J final closeout must be rescinded/deferred.

## Fixture

Generated local fixture:

```text
.tmp/hso-hot-plain-struct-new-candidates-2000-20260625.wat
```

Shape:

- one mutable 4-field GC struct type;
- `2000` functions;
- each function allocates a plain `struct.new` into a local;
- each function performs two same-local `struct.set` writes that Binaryen and Starshine fold into the constructor;
- the fixture intentionally uses plain `struct.new`, not `struct.new_default`, so the narrow raw complete-default-chain path from `1134` does not apply.

Generation sketch:

```py
for i in range(2000):
    local.set $x (struct.new $S (i32.const 0) (i32.const 1) (i32.const 2) (i32.const 3))
    struct.set $S 0 (local.get $x) (i32.const i)
    struct.set $S 2 (local.get $x) (i32.const (i * 3))
```

Validation:

```sh
wasm-tools validate --features all .tmp/hso-hot-plain-struct-new-candidates-2000-20260625.wat
```

Result: passed.

## Benchmark command

Seven independent `self-optimize-compare` runs used the explicit native Starshine binary and direct Binaryen HSO oracle:

```sh
bun scripts/self-optimize-compare.ts \
  .tmp/hso-hot-plain-struct-new-candidates-2000-20260625.wat \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/hso-hot-plain-struct-new-benchmark-20260625/run-<n> \
  --heap-store-optimization
```

Every run reported:

- `Starshine pass skipped raw: no`
- `Normalized WAT equal: yes`

## Results

| Run | Starshine pass ms | Binaryen pass ms | Starshine wall ms | Binaryen wall ms |
|---:|---:|---:|---:|---:|
| 1 | `10.084` | `1.036` | `132.413` | `29.547` |
| 2 | `10.249` | `0.977` | `133.133` | `28.551` |
| 3 | `10.819` | `1.112` | `136.116` | `28.509` |
| 4 | `10.227` | `1.531` | `135.369` | `30.667` |
| 5 | `10.856` | `1.047` | `140.105` | `29.390` |
| 6 | `11.077` | `0.976` | `141.896` | `29.150` |
| 7 | `10.738` | `1.010` | `137.373` | `28.423` |

Medians:

- Starshine pass-local: `10.738ms`
- Binaryen pass-local: `1.036ms`
- Starshine/Binaryen pass-local ratio: `10.365x` slower
- Starshine speed relative to Binaryen: `0.096x`
- `0.95x` speed target for this fixture: `<=1.091ms` Starshine median
- Starshine whole-command wall median: `136.116ms`
- Binaryen whole-command wall median: `29.150ms`

## Interpretation

The `1135` raw complete-default-chain fixture is still useful evidence for that exact lowered allocation pattern and for no-candidate/raw-skip accounting, but it is not a sufficient speed-parity benchmark for the pass. HSO-I is reopened for HOT-path candidate performance. HSO-J final closeout is rescinded until a proper candidate-running benchmark meets the user's `0.95x` Binaryen speed target or the user explicitly accepts a narrower speed scope.

The current behavior-parity and validation evidence from `1113`, `1136`, and `1137` remains useful: this benchmark found a performance gap, not a semantic mismatch. The next implementation slice should profile and optimize the HOT path for plain `struct.new` candidate chains, then rerun this benchmark plus the required compare validation.
