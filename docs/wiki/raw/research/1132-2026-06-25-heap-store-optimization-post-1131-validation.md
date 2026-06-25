---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1131-2026-06-25-heap-store-optimization-complete-chain-array-reuse.md
  - ./1130-2026-06-25-heap-store-optimization-inplace-heap-mutation.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# HSO post-1131 validation refresh

## Question

After the `1130` in-place heap mutation and `1131` complete-chain child-array reuse performance changes, does the current direct HSO implementation still pass broader focused package validation and the standard 10000-case direct GenValid smoke?

## Answer

Yes. The current direct HSO implementation remains green on `moon test src/passes` and a 10000-case direct GenValid compare with no cleanup normalizers.

This is validation evidence for the performance changes, not final HSO-J closeout. Speed-target refresh `1133` now supersedes the older `1116` `<=2x` fixture threshold: HSO-J remains explicitly deferred because HSO-I still has not met the `0.95x` Binaryen-speed target, been superseded with stronger artifact/neighborhood evidence plus reopening criteria, or been user-accepted.

## Evidence

Pass package tests:

```sh
moon test src/passes
```

Result: `3045/3045` passed.

Direct GenValid compare:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-post-1131-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result:

- requested/compared: `10000/10000`
- normalized matches: `10000`
- compare-normalized matches: `0`
- mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `0`
- cache: wasm-smith `0` hits / `0` misses; Binaryen `10000` hits / `0` misses; Binaryen failures `0` hits / `0` misses

## Interpretation

The two performance changes do not introduce direct-compare drift in the ordinary GenValid lane. The current best committed HSO-I timing remains `1131`'s `6.972ms` 2000-function Starshine median, still above the now-current `<=1.357ms` target derived from `0.95x` Binaryen speed and the `1120` Binaryen median. Therefore final closeout remains blocked on the HSO-I decision.
