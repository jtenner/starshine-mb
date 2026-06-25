---
kind: research
status: supported
created: 2026-06-25
sources:
  - ./0850-2026-06-25-code-pushing-call-barrier.md
  - ./0851-2026-06-25-code-pushing-all-post-call-barrier-refresh.md
  - ../../../binaryen/passes/code-pushing/fuzzing.md
  - ../../../../src/passes/code_pushing.mbt
---

# Code Pushing `wasm-smith` Post-Call-Barrier Refresh

## Question

After the call/throw segment barrier fix in [`0850`](./0850-2026-06-25-code-pushing-call-barrier.md), does the explicit external-generator `wasm-smith` lane remain free of Starshine mismatches/failures at 10000 requested cases?

## Command

```sh
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass code-pushing --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-wasm-smith-10000-20260625-post-zz --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Native binary: `_build/native/release/build/cmd/cmd.exe`, rebuilt after [`0850`](./0850-2026-06-25-code-pushing-call-barrier.md).

## Result

- Requested: `10000`.
- Compared: `9956/10000`.
- Normalized matches: `9956`.
- Cleanup-normalized matches: `0`.
- Raw mismatches: `0`.
- Validation failures: `0`.
- Generator failures: `0`.
- Property failures: `0`.
- Command failures: `44`.
- Jobs: `16`.
- Cache: wasm-smith `10000 hits/0 misses`; Binaryen `9956 hits/0 misses`; Binaryen failures `44 hits/0 misses`.

Command failure classes from `result.json`:

| Class | Count |
| --- | ---: |
| `binaryen-rec-group-zero` | 39 |
| `binaryen-bad-section-size` | 3 |
| `binaryen-invalid-tag-index` | 1 |
| `binaryen-table-index-out-of-range` | 1 |

## Decision

Agent classification: the 44 command failures are Binaryen/tool failures carried by the oracle lane, not Starshine mismatches or validation failures. The compared cases all normalized directly with no cleanup-normalized residue and no raw mismatches.

This supersedes the earlier same-day wasm-smith lane for current closeout-progress purposes after the call-barrier behavior change. It is not final `[O4Z-AUDIT-CP]` closeout by itself because remaining source-backed gap families and the full then-current matrix/stop condition are still open.

## Reopening criteria

Refresh this lane again if later behavior/profile/normalizer changes land before final closeout, if the wasm-smith cache or Binaryen oracle version changes, if command failure classes change in a way that may mask Starshine behavior, or if final closeout needs a single synchronized matrix run.
