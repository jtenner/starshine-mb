# DAE011 timing-only helper

Date: 2026-05-26

## Scope

This recovery slice continued `[DAE]011 - Performance Stabilization` from research note `0592`. The previous run showed that `self-optimize-compare` could produce and validate DAE debug artifacts but timed out in the normalized-WAT comparison/reporting phase before writing pass-local timing data.

## Change

Added a `--timing-only` mode to `scripts/self-optimize-compare.ts` / `scripts/lib/self-optimize-compare-task.ts`.

The mode still:

- builds or uses the requested Starshine binary;
- validates the input with the existing acceptance path;
- runs Starshine and Binaryen with the requested pass flags;
- parses Starshine and Binaryen pass-local timing;
- canonicalizes output wasm through `wasm-opt --strip-debug` so output validation is preserved;
- writes `commands.txt` and `result.json`.

The mode skips only the expensive normalized-WAT text printing, canonical-function comparison, and first-diff extraction. In `result.json`, `timingOnly` is `true`, and normalized-WAT / first-diff fields are `null`.

Focused script coverage lives in `scripts/test/self-optimize-compare-command.ts` and asserts that `--timing-only --dae-optimizing` does not invoke `wasm-opt -S`, still records pass timings, and still writes a timing summary.

## DAE artifact timing evidence

Command:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --canonicalize-binaryen-output \
  --timing-only \
  --dae-optimizing \
  --out-dir .tmp/dae011-timing-only-20260526
```

Result: completed and wrote `result.json`.

Reported timings:

- Starshine whole-command runtime: `3148.883ms`
- Binaryen whole-command runtime: `1138.266ms`
- Starshine pass-local runtime: `2785.602ms`
- Binaryen pass-local runtime: `836.627ms`
- Starshine pass-local parity flag: `no`

The pass-local ratio is about `3.33x` Binaryen, so `[DAE]011` remains open. This run completes the helper/reporting prerequisite and confirms the next step is DAE-owned profiling or a narrower pass-local hotspot attribution, not another full WAT compare attempt.

## Validation

- `bun scripts/test/self-optimize-compare-command.ts` passed.
- The timing-only artifact command above completed and preserved canonical output generation.
