# DAE004 large fact-queue recovery probe

Date: 2026-05-26

## Scope

Recovery/completion probe for the remaining `[DAE]004` selected result-removal broadening task: remove the large-artifact handpicked selected-def fallback only when evidence proves the fact-driven queue covers the remaining result-removal frontier without reopening the closed DAE011 pass-local runtime/validity target.

## Test-first probe

I first changed the existing focused regression `dae-optimizing removes high fact-discovered dropped callee result outside selected list` in `src/passes/dae_optimizing_test.mbt` from target defined function `3000` to target defined function `4500`, outside the current `defined <= 4096` fact-driven queue guard and outside the handpicked selected-def list.

Failing command before the experimental implementation:

```sh
moon test src/passes -f 'dae-optimizing removes high fact-discovered dropped callee result outside selected list'
```

Failure: the target still had one result (`1 != 0`). This confirmed the remaining large-module scheduling gap is real for synthetic modules if the handpicked fallback is not consulted.

## Rejected implementation experiment

I then temporarily widened the fact-driven dropped-result queue guard in `src/passes/dead_argument_elimination.mbt` from `original_defined <= 4096` to `<= 8192`. The focused test passed after that experiment, but the debug-artifact timing-only replay did not preserve the current DAE011 artifact contract:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --dae-optimizing \
  --timing-only \
  --out-dir .tmp/dae004-8192-timing-20260526b
```

Result: rejected. The run exited with code `1` from the Starshine command after producing an invalid/failed artifact dump around the selected dropped-result lane. Trace output showed the widened fact queue consuming all `32` iterations on low-numbered candidates (`primary_def` reaching the `600` range) before the historical selected fallback still handled high defs such as `3566`, `3732`, `3814`, `3834`, `4106`, `4229`, `4232`, `4240`, and `4241`. That means the broad ascending queue neither replaces the fallback nor preserves the artifact validation contract.

The temporary code/test edits were reverted. No pass behavior changed in this committed recovery slice.

## Classification

Agent classification: validation failure for the experimental unguarded/wider large-module fact queue. This is not a Binaryen semantic mismatch and not an accepted raw-cleanup drift. The failed experiment proves that simply widening the existing ascending bounded queue is insufficient: it can spend its budget on early candidates, still fall through to the handpicked high-def fallback, and produce invalid output on the huge debug artifact.

## Next required subtasks

To complete `[DAE]004` safely, future work should avoid another blind guard widening and instead add a measured large-module scheduler with focused tests before changing the artifact path:

1. Add a candidate-ordering test that demonstrates the current ascending fact queue starves a high dropped-result callee when many low dropped-result candidates are present.
2. Design a deterministic ordered candidate queue (for example priority by current frontier/high defs or direct-call graph locality) that can reach high candidates without relying on the handpicked selected-def list.
3. Keep per-candidate revalidation through `dae_try_remove_dropped_results(...)`, including private/non-tail/all-direct-calls-dropped guards, mixed live/undropped-call preservation, `call; drop` repair, and type-liveness updates.
4. Replay the debug artifact with `--timing-only`; require valid Starshine output and `Starshine pass <= 2x Binaryen pass` before removing or disabling the large-artifact fallback.
5. Run a 10k direct `dae-optimizing` compare refresh and classify any mismatches per repo policy.

## Validation for this docs-only recovery slice

Behavioral changes were reverted before commit. Final validation after the research/backlog updates:

- `git diff --check` passed.
- `moon info` passed.
- `moon fmt` passed.
- `moon test` passed (`3452` tests; existing unused-helper warnings remain).
