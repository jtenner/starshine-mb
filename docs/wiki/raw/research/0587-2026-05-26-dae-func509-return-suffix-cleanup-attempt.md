# DAE Func509 return-suffix cleanup attempt

## Question

Can a small DAE raw-cleanup change remove the Func509 `defined=509 abs=526` both-canonical frontier recorded in research note `0586`?

## Changes tried

This recovery run added focused coverage for two related cleanup shapes:

- root `return` followed by allocation/store/value debris in `src/passes/dead_argument_elimination_wbtest.mbt` and a public `dae-optimizing` fixture in `src/passes/dae_optimizing_test.mbt`;
- a narrow terminal wrapper-suffix shape that keeps an earlier result object after a tag/store sequence and drops the later `i32.const 8; call alloc; local.tee wrapper; tag store; i64.store; local.get wrapper` suffix.

The implementation adds a final DAE cleanup hook plus narrow helpers in `src/passes/dead_argument_elimination.mbt`. The focused Moon tests pass and protect the intended syntactic cleanups.

## Artifact replay

Command:

```sh
rm -rf .tmp/dae006-wrapper-suffix2-20260526 && \
  bun scripts/self-optimize-compare.ts \
    tests/node/dist/starshine-debug-wasi.wasm \
    --starshine-bin target/native/release/build/cmd/cmd.exe \
    --dae-optimizing \
    --canonicalize-binaryen-output \
    --out-dir .tmp/dae006-wrapper-suffix2-20260526
```

Result:

- Artifact directory: `.tmp/dae006-wrapper-suffix2-20260526`
- Canonical wasm equal: no
- Normalized WAT equal: no
- Canonical function compare equal: no
- First differing function: `defined=509 abs=526`
- Starshine runtime: `3200.121ms`
- Binaryen runtime: `1134.680ms`
- Starshine pass runtime: `2829.276ms`
- Binaryen pass runtime: `841.003ms`
- Pass-local target: still missed (`Starshine > 2x Binaryen`)

Trace spot-checking with `--tracing pass` still reports the earlier `module-raw-cleanup primary_def=215` but no final-return-suffix cleanup hit on the debug artifact, so the new syntactic helpers do not match the actual in-memory Func509 body shape before encoding/canonical printing.

## Validation

- Failing first: `moon test src/passes` failed on the new white-box root-return cleanup test before the initial cleanup implementation.
- Passing after implementation: `moon test src/passes` passes with `1368` tests.
- Native CLI rebuild: `moon build --target native --release` succeeds with existing warnings.
- Quick signoff: `moon info`, `moon fmt`, and `moon test` all pass with existing warnings.
- Direct fuzz smoke: `.tmp/pass-fuzz-dae-return-suffix-200` compared `45/200`, with `26` normalized matches, `19` mismatches, `0` validation failures, and `1` command failure. This smoke is not a signoff run; it only checked that the new cleanup did not immediately introduce validation failures.

## Agent classification

The current Func509 frontier remains **semantic-safe, size-losing dead/fallthrough wrapper cleanup gap** by the prior `0586` reasoning, but this run does **not** close it. The observed flat `body_raw` in the compare artifact still ends with the wrapper allocation/store/value sequence while Binaryen ends with the earlier result object.

## Next step

Instrument or reduce the actual pre-encode Starshine `@lib.Instruction` sequence for Func509, then write the next focused test against that exact flat shape. The current helpers cover plausible root-return and simple terminal-wrapper shapes but evidently miss the real lowered sequence used by the debug artifact.
