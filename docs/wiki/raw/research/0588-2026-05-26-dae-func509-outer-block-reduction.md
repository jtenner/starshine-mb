# DAE Func509 outer-block reduction follow-up

## Question

Can the DAE final return-suffix cleanup be extended safely for the pre-encode Func509 outer-block shape captured in `0587`?

## Focused reduction

This run added a white-box reduction in `src/passes/dead_argument_elimination_wbtest.mbt` for the narrowed structure:

- an outer value block (`block i64` in the fixture, matching the printed `block I64` family);
- a first inner `block (void)` that terminates without fallthrough by `return` or an equivalent terminator;
- a following `local.set` of the lowered block value;
- the wrapper allocation/tag/store/result suffix `i32.const 8; call alloc; local.tee wrapper; tag store; local.get wrapper; local.get stored; i64.store; local.get wrapper`.

The reduction proves the suffix is removable for this syntactic family when the first inner block cannot normally fall through to the wrapper-producing tail. The pass helper now strips that tail from matching instruction lists.

## Artifact replay

Command:

```sh
rm -rf .tmp/dae006-outer-block-suffix2-20260526 && \
  bun scripts/self-optimize-compare.ts \
    tests/node/dist/starshine-debug-wasi.wasm \
    --starshine-bin target/native/release/build/cmd/cmd.exe \
    --dae-optimizing \
    --canonicalize-binaryen-output \
    --out-dir .tmp/dae006-outer-block-suffix2-20260526
```

Result:

- Artifact directory: `.tmp/dae006-outer-block-suffix2-20260526`
- Canonical wasm equal: no
- Normalized WAT equal: no
- Canonical function compare equal: no
- First differing function: `defined=509 abs=526`
- Starshine runtime: `3158.354ms`
- Binaryen runtime: `1130.917ms`
- Starshine pass runtime: `2791.086ms`
- Binaryen pass runtime: `843.419ms`
- Pass-local target: still missed (`Starshine > 2x Binaryen`)

A follow-up trace/print with the rebuilt native CLI still showed no `pass[dae-optimizing]:final-return-suffix-cleanup` hit for the artifact Func509 body. Therefore this run protects the reduced outer-block family but does **not** close the live debug-artifact frontier.

## Agent classification

`[DAE]006` remains open. The Func509 compare frontier remains classified as a semantic-safe, size-losing return/wrapper cleanup gap by the `0586` and `0587` reasoning, but the reason the final pass hook misses the live artifact is now narrower: the focused helper is covered and passing, yet the artifact trace still does not report a final-return-suffix cleanup for `defined=509 abs=526`.

## Validation

- Failing first: `moon test src/passes` failed on the new white-box outer-block wrapper test before implementation.
- Passing after implementation: `moon test src/passes` passes with `1371` tests.
- Native CLI rebuild: `moon build --target native --release` succeeds with existing warnings.
- Both-canonical artifact replay: `.tmp/dae006-outer-block-suffix2-20260526` still first-diffs at `defined=509 abs=526` with timings above.

## Next step

Instrument or reduce the exact final-cleanup input seen by `dae_strip_module_root_return_suffix_once`, not only the `--print-func` or post-encode canonical body. The next slice should answer whether the final cleanup runs before a later lowering/encoding step reintroduces the wrapper, or whether the in-memory instruction list differs from both saved textual shapes in a way the helper still does not match. Do not claim Func509 closure until the both-canonical artifact compare moves past `defined=509 abs=526`.
