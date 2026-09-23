---
kind: workflow
status: working
last_reviewed: 2026-09-22
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `local-cse` Fuzzing Profile

The September 22 shared-memory repair passed red-first direct and nested DAE
regressions, the full 12,053-test suite, and a verified-v132 regular GenValid
lane at `.tmp/pass-safety-final-local-cse-10000`: 10,000/10,000 canonical
matches, zero failures. The native binary and full validation matrix are
recorded in the [safety audit](../../../ir2/architecture-rules.md#september-22-eight-agent-pass-safety-audit).
The directed shared-memory tests cover concurrency-sensitive observations
that this regular profile does not generate.

Recommended smoke lane: run the dedicated GenValid profile for this pass:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --gen-valid-profile local-cse --out-dir .tmp/pass-fuzz-local-cse --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

The bounded `local-cse` profile emits one validating function with two identical
local-fed `i32.add`, `i32.sub`, or `i32.xor` trees. Every generated case therefore
reaches the pass's core repeated-expression candidate path. The selected case is
recorded as `local-cse:repeated-{add,sub,xor}` in `profile_case_label`, and the
profile participates in `random-all-profiles`.

This scalar trigger profile does not replace the directed shared-memory, GC,
descriptor, SIMD, exception, or continuation tests. Those proposal families
still need their own feature floors or wider trigger leaves before a dedicated
lane can claim representative proposal coverage. No fuzz campaign was run when
this profile was added.
