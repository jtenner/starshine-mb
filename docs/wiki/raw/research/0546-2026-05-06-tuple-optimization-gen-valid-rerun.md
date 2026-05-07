---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/tuple-optimization/parity.md
  - ../../binaryen/passes/tuple-optimization/reduced-repros-and-evidence.md
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/tuple-optimization/parity.md
  - ../../binaryen/passes/tuple-optimization/reduced-repros-and-evidence.md
  - ./0542-2026-05-06-tuple-optimization-direct-revalidation.md
---

# `tuple-optimization` current-head `gen-valid` rerun

## Question

Does current head still pass a fresh `10000`-case `gen-valid` direct compare for `tuple-optimization`, so the stale `[TO]005` rerun TODO can be removed?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 10000 --seed 0x5eed --max-failures 20 --out-dir .tmp/pass-fuzz-tuple-gen-valid-10000-20260506`

Results:

- `moon test`: `2820 / 2820` passed
- compared cases: `10000 / 10000`
- normalized matches: `10000`
- mismatches: `0`
- validation failures: `0`
- generator failures: `0`
- command failures: `0`

## Conclusion

Current head still has clean `10000`-case `gen-valid` direct parity for `tuple-optimization`. This closes the stale `[TO]005` rerun TODO. The remaining `[TO]005` work is still exact-slot proof, pre-lower carrier debt, and debug-artifact/runtime follow-up.
