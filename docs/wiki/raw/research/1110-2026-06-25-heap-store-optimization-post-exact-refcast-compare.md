---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1109-2026-06-25-heap-store-optimization-exact-ref-cast-closure.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# HSO post-exact-refcast direct compare

## Question

After adding exact `ref.cast` decode/encode/HOT support and focused HSO coverage in `1109`, does the ordinary direct GenValid HSO lane still compare cleanly without cleanup normalizers?

## Command

The explicit native binary was rebuilt during `1109` with:

```sh
moon build --target-dir target --target native --release src/cmd
```

Then the direct lane was run with no cleanup normalizers:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-exact-refcast-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

## Result

- requested cases: `10000`
- compared cases: `10000/10000`
- normalized matches: `10000`
- compare-normalized matches: `0`
- mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `0`
- jobs: `16`
- cache: wasm-smith `0` hits / `0` misses; Binaryen `10000` hits / `0` misses; Binaryen failures `0` hits / `0` misses

## Classification

Post-change regression evidence for the exact `ref.cast` surface slice. This does not replace final HSO-J closeout: the final pass closeout still needs full Moon validation, the full required compare matrix decisions/reruns, O4z slot/neighborhood replay, performance disposition, docs/log updates, and backlog cleanup.
