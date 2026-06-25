---
kind: research
status: supported
created: 2026-06-25
sources:
  - ./0855-2026-06-25-code-pushing-throw-ref-movement.md
  - ../../../binaryen/passes/code-pushing/fuzzing.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/passes/code_pushing_test.mbt
---

# Code Pushing `code-pushing-all` Refresh After `throw_ref`

## Question

Does the 19-leaf dedicated `code-pushing-all` GenValid lane remain clean after the source-backed `throw_ref` / later-`br_if` movement refinement in [`0855`](./0855-2026-06-25-code-pushing-throw-ref-movement.md)?

This is a closeout-progress evidence refresh only. It does not close `[O4Z-AUDIT-CP]`; remaining source gaps and the other final matrix lanes still need then-current evidence and an explicit stop condition.

## Command

Native binary: `_build/native/release/build/cmd/cmd.exe`, rebuilt in [`0855`](./0855-2026-06-25-code-pushing-throw-ref-movement.md).

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass code-pushing \
  --gen-valid-profile code-pushing-all \
  --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-code-pushing-all-10000-20260625-post-throw-ref \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

## Result

Output directory: `.tmp/pass-fuzz-code-pushing-all-10000-20260625-post-throw-ref`.

- Requested cases: `10000`.
- Compared cases: `10000/10000`.
- Normalized matches: `4769`.
- Cleanup-normalized matches: `5231` under `--normalize local-cleanup-debris`.
- Raw mismatches/failures: `0`.
- Validation failures: `0`.
- Generator failures: `0`.
- Property failures: `0`.
- Command failures: `0`.
- Jobs: `16`.
- Cache: wasm-smith `0` hits / `0` misses; Binaryen `10000` hits / `0` misses; Binaryen failure cache `0` hits / `0` misses.

Selected profile counts from `summary.json`:

| Leaf | Count |
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

## Classification

The lane is green dedicated-profile closeout-progress evidence for the post-`throw_ref` source state. Cleanup-normalized matches are still agent-classified local cleanup/lowering debris under the documented narrow normalizer, not a harness proof of broad semantic equivalence.

Because [`0855`](./0855-2026-06-25-code-pushing-throw-ref-movement.md) changed behavior after the previous four-lane refresh, the post-call-barrier regular 100000, wasm-smith 10000, and broad named `pass-fuzz-stress` 10000 lanes remain useful historical progress evidence but are no longer final-current closeout evidence. Rerun them if final closeout becomes plausible.

## Follow-up

Keep `[O4Z-AUDIT-CP]` active. Next high-leverage work should either resolve/narrow another source-backed behavior gap or refresh the remaining matrix lanes only after source-gap work reaches a plausible final stop condition.
