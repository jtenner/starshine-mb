---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1092-2026-06-25-heap-store-optimization-simple-skip-fast-path.md
  - ../../../scripts/pass-fuzz-compare.ts
  - ../../../docs/wiki/binaryen/passes/heap-store-optimization/fuzzing.md
  - ../../../agent-todo.md
---

# HSO post-simple-skip direct compare smoke

## Question

Does the simple no-control skip-local-set fast path from `1092` preserve direct HSO Binaryen behavior on the ordinary GenValid lane?

## Command

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-hso-simple-skip-20260625-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

No cleanup normalizers were used.

## Result

- Requested: `10000`.
- Compared: `10000/10000`.
- Normalized matches: `10000`.
- Compare-normalized matches: `0`.
- Mismatches: `0`.
- Validation failures: `0`.
- Property failures: `0`.
- Generator failures: `0`.
- Command failures: `0`.
- Jobs: `16`.
- Cache: wasm-smith `0` hits / `0` misses; Binaryen `10000` hits / `0` misses; Binaryen failures `0` hits / `0` misses.
- Artifact directory: `.tmp/pass-fuzz-hso-simple-skip-20260625-10000`.

## Interpretation

This is post-change regression evidence for the `1092` performance fast path. It does not close HSO-J by itself because final closeout still needs source-backed residual family review, performance disposition, full Moon validation, and backlog cleanup.
