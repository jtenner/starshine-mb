# DAE Func509 return-suffix cleanup attempt

## Question

Can a small DAE raw-cleanup change remove the Func509 `defined=509 abs=526` both-canonical frontier recorded in research note `0586`?

## Changes tried

This recovery run added focused coverage for two related cleanup shapes:

- root `return` followed by allocation/store/value debris in `src/passes/dead_argument_elimination_wbtest.mbt` and a public `dae-optimizing` fixture in `src/passes/dae_optimizing_test.mbt`;
- a narrow terminal wrapper-suffix shape that keeps an earlier result object after a tag/store sequence and drops the later `i32.const 8; call alloc; local.tee wrapper; tag store; i64.store; local.get wrapper` suffix.

The implementation adds a final DAE cleanup hook plus narrow helpers in `src/passes/dead_argument_elimination.mbt`. A recovery follow-up fixed the pending lowered-return helper tuple/length bug and added a block-wrapped terminal-wrapper regression. The focused Moon tests now pass and protect the intended syntactic cleanups.

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

Trace spot-checking with `--tracing pass` still reports the earlier `module-raw-cleanup primary_def=215` but no final-return-suffix cleanup hit on the debug artifact, so the new syntactic helpers do not match the actual in-memory Func509 body shape before encoding/canonical printing. The recovery replay `.tmp/dae006-return-suffix-recovery-20260526` likewise stayed at `defined=509 abs=526` (`2870.440ms` Starshine pass versus `867.327ms` Binaryen pass).

## Validation

- Failing first: `moon test src/passes` failed on the new white-box root-return cleanup test before the initial cleanup implementation.
- Passing after implementation: `moon test src/passes` passes with `1368` tests.
- Native CLI rebuild: `moon build --target native --release` succeeds with existing warnings.
- Quick signoff: `moon info`, `moon fmt`, and `moon test` all pass with existing warnings.
- Direct fuzz smoke: `.tmp/pass-fuzz-dae-return-suffix-200` compared `45/200`, with `26` normalized matches, `19` mismatches, `0` validation failures, and `1` command failure. This smoke is not a signoff run; it only checked that the new cleanup did not immediately introduce validation failures.

## Agent classification

The current Func509 frontier remains **semantic-safe, size-losing dead/fallthrough wrapper cleanup gap** by the prior `0586` reasoning, but this run does **not** close it. The observed flat `body_raw` in the compare artifact still ends with the wrapper allocation/store/value sequence while Binaryen ends with the earlier result object.

## Follow-up recovery probe

A later recovery run rebuilt the native CLI and printed the live pre-encode Func509 shape with:

```sh
moon build --target native --release && \
  target/native/release/build/cmd/cmd.exe \
    --dae-optimizing \
    --print-func 526 \
    --out .tmp/dae-print-func526.wasm \
    tests/node/dist/starshine-debug-wasi.wasm \
    2> .tmp/dae-print-func526.err
```

The print confirmed the helper miss is structural, not just local-index drift. Before canonicalization, Func509 is an outer `block I64` whose first child is an inner `block (Void)`. The inner block contains branches to `Label 1`, an `unreachable`, and a fallthrough parser-object path ending in `local.get $20; return`. After that inner block, the outer block still has `local.set $2` plus the same `i32.const 8; call $alloc; local.tee $18; tag store; local.get $18; local.get $2; i64.store; local.get $18` wrapper suffix. The canonical compare artifact flattens this to the known suffix (`local10` object versus wrapper `local11`), but the pass-side cleanup currently runs on the pre-encode nested block/return form.

This run did **not** add a new cleanup. The `br Label 1` exits in the printed inner block mean a safe rewrite needs an explicit control-flow proof for the outer block result path, not just a suffix pattern. In particular, the next implementation must prove whether the `Label 1` branches can reach the wrapper-producing suffix with a live value that must be wrapped, or whether the printed branch/value shape is an artifact of return lowering and the wrapper remains dead for every real exit.

## Next step

Reduce the actual pre-encode Starshine Func509 `@lib.Instruction` sequence printed by `--print-func 526` into a focused white-box fixture before changing behavior again. The fixture should keep the outer `block I64`, inner `block (Void)`, `br Label 1` exits, fallthrough `local.get $20; return`, and post-inner `local.set $2` plus wrapper suffix. Prove whether all exits return the earlier object or whether a branch can still make the wrapper live. Only after that proof should the pass either extend `dae_strip_root_return_suffix_instrs` for this exact outer-block shape or document the frontier as non-normalizable/currently unsafe. The existing helpers cover plausible root-return and simple terminal-wrapper shapes but still miss the real lowered sequence used by the debug artifact.
