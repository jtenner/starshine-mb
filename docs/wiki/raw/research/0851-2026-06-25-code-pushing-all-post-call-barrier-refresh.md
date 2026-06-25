---
kind: research
status: supported
created: 2026-06-25
sources:
  - ./0850-2026-06-25-code-pushing-call-barrier.md
  - ../../../binaryen/passes/code-pushing/fuzzing.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/validate/gen_valid.mbt
---

# Code Pushing `code-pushing-all` Post-Call-Barrier Refresh

## Question

After the call/throw segment barrier fix in [`0850`](./0850-2026-06-25-code-pushing-call-barrier.md), is the 19-leaf `code-pushing-all` dedicated GenValid lane still green at the ordinary 10000-case closeout-progress scale?

## Command

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-all-10000-20260625-post-yy --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Native binary: `_build/native/release/build/cmd/cmd.exe`, rebuilt after [`0850`](./0850-2026-06-25-code-pushing-call-barrier.md).

## Result

- Requested: `10000`.
- Compared: `10000/10000`.
- Normalized matches: `4769`.
- Cleanup-normalized matches: `5231` under `--normalize local-cleanup-debris`.
- Raw mismatches: `0`.
- Validation failures: `0`.
- Generator failures: `0`.
- Property failures: `0`.
- Command failures: `0`.
- Jobs: `16`.
- Cache: wasm-smith `0 hits/0 misses`; Binaryen `10000 hits/0 misses`; Binaryen failures `0 hits/0 misses`.

Selected 19-leaf profile counts from `result.json`:

| Leaf profile | Count |
| --- | ---: |
| `code-pushing-after-if` | 558 |
| `code-pushing-br-if` | 537 |
| `code-pushing-br-if-value` | 516 |
| `code-pushing-br-on-cast` | 565 |
| `code-pushing-br-on-cast-fail` | 526 |
| `code-pushing-br-on-non-null` | 555 |
| `code-pushing-br-on-non-null-prefix` | 513 |
| `code-pushing-br-on-null` | 524 |
| `code-pushing-dropped-if` | 510 |
| `code-pushing-if-arm` | 504 |
| `code-pushing-loop-br-if` | 511 |
| `code-pushing-multi-set` | 507 |
| `code-pushing-multi-set-br-if` | 511 |
| `code-pushing-multi-set-drop-window` | 504 |
| `code-pushing-multi-set-dropped-if` | 530 |
| `code-pushing-multi-set-global-get-window` | 554 |
| `code-pushing-multi-set-local-copy` | 520 |
| `code-pushing-multi-set-local-get-window` | 515 |
| `code-pushing-multi-set-nop-window` | 540 |

## Decision

This refresh supersedes the pre-call-barrier 10000-case dedicated lane for current closeout-progress purposes. It does not close `[O4Z-AUDIT-CP]` by itself: final closeout still needs all then-current required matrix lanes, source-backed closure or accepted narrow boundaries for the remaining gap families, and an explicit stop condition.

The cleanup-normalized matches remain agent-classified local cleanup/lowering debris covered by the narrow `local-cleanup-debris` normalizer, not harness-proven semantic equivalence for arbitrary drift.

## Reopening criteria

Refresh this lane again if any later behavior/profile/normalizer change lands before final closeout, if any selected leaf gains or loses aggregate-safe status, or if final closeout chooses a different native binary or Binaryen oracle version.
