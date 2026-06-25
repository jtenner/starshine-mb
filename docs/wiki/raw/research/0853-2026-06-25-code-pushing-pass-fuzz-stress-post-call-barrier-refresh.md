# Code-pushing pass-fuzz-stress refresh after call barrier

Date: 2026-06-25

## Question

Refresh the broad named `pass-fuzz-stress` GenValid lane for direct `code-pushing` after the call/throw ordered-barrier behavior change in [`0850`](0850-2026-06-25-code-pushing-call-barrier.md). The previous broad named lane [`0849`](0849-2026-06-25-code-pushing-pass-fuzz-stress-post-boundary-refresh.md) predated that behavior fix.

## Command

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass code-pushing --gen-valid-profile pass-fuzz-stress --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-pass-fuzz-stress-10000-20260625-post-aaa --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

The native Starshine binary path is the checkout-local `_build/native/release/build/cmd/cmd.exe` produced by the earlier post-call-barrier build.

## Result

Artifact directory: `.tmp/pass-fuzz-code-pushing-pass-fuzz-stress-10000-20260625-post-aaa`

- Requested cases: `10000`
- Compared cases: `10000/10000`
- Normalized matches: `10000`
- Cleanup-normalized matches: `0`
- Raw mismatches: `0`
- Validation failures: `0`
- Generator failures: `0`
- Property failures: `0`
- Command failures: `0`
- Jobs: `16`
- Seed: `0x5555`
- Generator: `gen-valid`
- GenValid profile: `pass-fuzz-stress`
- Selected profile counts: `pass-fuzz-stress: 10000`
- Cache: wasm-smith `0 hits/0 misses`; Binaryen `10000 hits/0 misses`; Binaryen failures `0 hits/0 misses`

## Classification

Green broad named-profile closeout-progress evidence for the post-call-barrier source state. No mismatches or failures were observed, and no cleanup normalization was needed in this lane.

This supersedes [`0849`](0849-2026-06-25-code-pushing-pass-fuzz-stress-post-boundary-refresh.md) as the current `pass-fuzz-stress` lane. It is not final `[O4Z-AUDIT-CP]` closeout by itself: source-backed gaps and accepted boundaries remain open, and final closeout still needs a then-current full matrix plus an explicit stop condition.

## Follow-up

- Keep shrinking remaining source-backed behavior gaps or document narrow Binaryen-stationary boundaries.
- Refresh the regular GenValid `100000` lane near final closeout if no more behavior changes land, because the current regular `100000` lane still predates [`0850`](0850-2026-06-25-code-pushing-call-barrier.md).
