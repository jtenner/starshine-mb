---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1088-2026-06-25-heap-store-optimization-control-context-skip.md
  - ./1087-2026-06-25-heap-store-optimization-post-scan-skip-compare.md
  - ../../../scripts/pass-fuzz-compare.ts
  - ../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../agent-todo.md
---

# HSO post-context-skip direct compare smoke

## Question

After the `1088` straight-line context setup skip, does the direct GenValid HSO lane still match Binaryen behavior on the standard seed smoke?

## Command

Used the explicit native binary rebuilt for the `1088` code change:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-hso-context-skip-20260625-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

No cleanup normalizers were used.

## Result

- Requested cases: `10000`.
- Compared cases: `10000/10000`.
- Normalized matches: `10000`.
- Compare-normalized matches: `0`.
- Raw mismatches: `0`.
- Validation failures: `0`.
- Property failures: `0`.
- Generator failures: `0`.
- Command failures: `0`.
- Jobs: `16` (`--jobs auto`).
- Cache counters: wasm-smith `0` hits / `0` misses; Binaryen `10000` hits / `0` misses; Binaryen failures `0` hits / `0` misses.
- Artifacts: `.tmp/pass-fuzz-hso-context-skip-20260625-10000`.

## Interpretation

This is post-code-change regression evidence for the `1088` context setup skip. The lane is normalized-green without cleanup normalizers, so no output-shape difference was introduced by the change.

This does not close HSO-J. Final closeout still needs source-backed family review, performance disposition, full Moon validation, and backlog cleanup. The required final matrix lanes remain current from `1073`, `1078`, `1080`, `1081`, and `1082`, with this note adding post-`1088` direct smoke evidence.
