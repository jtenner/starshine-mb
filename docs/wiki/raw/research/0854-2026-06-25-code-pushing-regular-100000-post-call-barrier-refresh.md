# Code-pushing regular GenValid 100000 refresh after call barrier

Date: 2026-06-25

## Question

Refresh the required large regular GenValid lane for direct `code-pushing` after the call/throw ordered-barrier behavior change in [`0850`](0850-2026-06-25-code-pushing-call-barrier.md). The previous regular 100000 lane [`0845`](0845-2026-06-25-code-pushing-regular-100000-current.md) predated that behavior fix.

## Command

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass code-pushing --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-regular-100000-20260625-post-bbb --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

The native Starshine binary path is the checkout-local `_build/native/release/build/cmd/cmd.exe` produced by the earlier post-call-barrier build.

## Result

Artifact directory: `.tmp/pass-fuzz-code-pushing-regular-100000-20260625-post-bbb`

- Requested cases: `100000`
- Compared cases: `100000/100000`
- Normalized matches: `100000`
- Cleanup-normalized matches: `0`
- Raw mismatches: `0`
- Validation failures: `0`
- Generator failures: `0`
- Property failures: `0`
- Command failures: `0`
- Jobs: `16`
- Seed: `0x5eed`
- Generator: `gen-valid`
- GenValid profile: none / regular oracle lane
- Selected profile counts: `binaryen-oracle-portable: 100000`
- Cache: wasm-smith `0 hits/0 misses`; Binaryen `100000 hits/0 misses`; Binaryen failures `0 hits/0 misses`

## Classification

Green large regular GenValid closeout-progress evidence for the post-call-barrier source state. No mismatches or failures were observed, and no cleanup normalization was needed in this lane.

This supersedes [`0845`](0845-2026-06-25-code-pushing-regular-100000-current.md) as the current regular 100000 lane. It is not final `[O4Z-AUDIT-CP]` closeout by itself: source-backed gaps and accepted boundaries remain open, and final closeout still needs a then-current full matrix plus an explicit stop condition.

## Follow-up

- Keep shrinking remaining source-backed behavior gaps or document narrow Binaryen-stationary boundaries.
- If no more behavior changes land, the four closeout-progress compare lanes are now current after [`0850`](0850-2026-06-25-code-pushing-call-barrier.md): regular 100000 (`0854`), explicit wasm-smith 10000 (`0852`), dedicated `code-pushing-all` 10000 (`0851`), and broad named `pass-fuzz-stress` 10000 (`0853`).
