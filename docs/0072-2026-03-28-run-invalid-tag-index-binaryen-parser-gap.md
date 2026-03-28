# RUN Invalid Tag Index Binaryen Parser Gap

## Scope

Document the `remove-unused-names` pass-fuzz command failure that currently appears as Binaryen `invalid tag index` parser rejection on a saved `wasm-smith` input, while Starshine completes the direct pass successfully.

## Current Behavior

- Source corpus: `.tmp/pass-fuzz-run-smith-2000`
- Saved failure: `.tmp/pass-fuzz-run-smith-2000/failures/case-000662-wasm-smith`
- Failing Binaryen command:

```text
wasm-opt <input.wasm> --all-features --remove-unused-names -o binaryen.raw.wasm
```

- Observed Binaryen parser failure:

```text
parse exception: invalid tag index (at 0:54)
```

- Starshine side: the pass completes and emits `starshine.raw.wasm` for the same saved input.

## Correctness Constraints

- Do not count this family as a Starshine semantic mismatch unless the saved case replays to a normalized output difference after Binaryen can parse it.
- Keep the saved input replayable from the existing corpus instead of rewriting or mutating the fixture.
- Keep Binaryen parser-family failures visible as separate harness output so larger oracle sweeps do not blur parser gaps into generic command failures.

## Validation Plan

- Replay the exact saved case directly:

```text
bun scripts/pass-fuzz-compare.ts \
  --pass remove-unused-names \
  --replay-failures-from .tmp/pass-fuzz-run-smith-2000 \
  --case-index 662 \
  --out-dir .tmp/pass-fuzz-run-smith-case-662-replay
```

- Replay the whole classified family when needed:

```text
bun scripts/pass-fuzz-compare.ts \
  --pass remove-unused-names \
  --replay-failures-from .tmp/pass-fuzz-run-smith-2000 \
  --failure-class binaryen-invalid-tag-index \
  --out-dir .tmp/pass-fuzz-run-smith-invalid-tag-index-replay
```

## Performance Impact

- None on normal pass execution.
- Minimal harness-only impact from classifying one more Binaryen parser family and allowing precise single-case replay.

## Open Questions

- Whether newer Binaryen builds parse this saved module successfully.
- Whether the saved module reduces to a smaller exception-tag reference pattern that is useful as an upstream Binaryen bug report.
