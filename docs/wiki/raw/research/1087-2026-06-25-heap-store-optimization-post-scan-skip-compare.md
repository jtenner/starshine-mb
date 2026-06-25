---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1085-2026-06-25-heap-store-optimization-control-scan-skip.md
  - ./1082-2026-06-25-heap-store-optimization-regular-genvalid-100000.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../agent-todo.md
---

# HSO post-scan-skip direct compare smoke

## Question

After the straight-line region-scan skip from `1085`, does a larger direct GenValid compare still match Binaryen behavior without cleanup normalizers?

## Command

The explicit native binary had been rebuilt for `1085` with:

```sh
moon build --target-dir target --target native --release src/cmd
```

Then this slice ran:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-hso-control-skip-20260625-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

No cleanup normalizers were used.

## Result

- Requested cases: `10000`
- Compared cases: `10000/10000`
- Normalized matches: `10000`
- Compare-normalized matches: `0`
- Mismatches: `0`
- Validation failures: `0`
- Property failures: `0`
- Generator failures: `0`
- Command failures: `0`
- Jobs: `16`
- Cache: wasm-smith `0` hits / `0` misses; Binaryen `10000` hits / `0` misses; Binaryen failures `0` hits / `0` misses
- Out dir: `.tmp/pass-fuzz-hso-control-skip-20260625-10000`

## Interpretation

This is post-change regression evidence for the `1085` performance micro-optimization. It does not replace the final closeout matrix: the current regular 100000-case lane remains `1082`, and final HSO closeout still needs source-family completion/disposition, full Moon validation, performance disposition, and backlog cleanup.
