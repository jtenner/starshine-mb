# DAE Func509 dead-return suffix frontier

## Question

After `0585` added the diagnostic-only canonical-function normalizer for the inspected Func505 parser-loop family, can the both-canonical `dae-optimizing` artifact replay advance past `defined=505 abs=522`, and what is the next frontier?

## Command

```sh
rm -rf .tmp/dae006-next-frontier-20260526 && \
  bun scripts/self-optimize-compare.ts \
    tests/node/dist/starshine-debug-wasi.wasm \
    --starshine-bin target/native/release/build/cmd/cmd.exe \
    --dae-optimizing \
    --canonicalize-binaryen-output \
    --out-dir .tmp/dae006-next-frontier-20260526
```

## Result

The replay completed and wrote `result.json`.

- Artifact directory: `.tmp/dae006-next-frontier-20260526`
- Canonical wasm equal: no
- Normalized WAT equal: no
- Canonical function compare equal: no
- First differing function: `defined=509 abs=526`
- Starshine runtime: `3299.269ms`
- Binaryen runtime: `1201.915ms`
- Starshine pass runtime: `2923.619ms`
- Binaryen pass runtime: `891.787ms`
- Pass-local target: still missed (`Starshine > 2x Binaryen`)

Both canonical outputs validated with:

```sh
wasm-opt --all-features .tmp/dae006-next-frontier-20260526/starshine.wasm -o /tmp/dae006-starshine-validated.wasm
wasm-opt --all-features .tmp/dae006-next-frontier-20260526/binaryen.wasm -o /tmp/dae006-binaryen-validated.wasm
```

`wasm-opt` printed only the existing large-local-count VM warning for function 518.

## Frontier shape

The Func505 diagnostic normalizer worked: the first diff moved to Func509.

The new `defined=509 abs=526` pretty/raw body is identical through construction of a 4-byte result object. Binaryen returns that object directly:

```wat
(i32.store offset=4 align=1 ...)
(i32.store offset=8 align=1 ...)
(return (local.get $22))
```

Starshine returns the same 4-byte object, but leaves an unreachable dead suffix after the return that allocates and initializes an 8-byte wrapper around the returned pointer:

```wat
(local.tee $2
  (return (local.get $21)))
(i32.store offset=4 align=1
  (local.tee $20 (call $7 (i32.const 8)))
  (i32.const 2097153))
(i64.store offset=8 align=1
  (local.get $20)
  (local.get $2))
(local.get $20)
```

The normalized pretty dump makes the same distinction: Starshine continues with `i32.const 8`, `call(Func24)`, stores tag `2097153`, stores the returned local as `i64`, and returns the wrapper local; Binaryen stops at `local.get(Local10)`.

## Agent classification

Classification: **semantic-safe, size-losing dead-return-suffix cleanup gap**.

Reasoning: the differing Starshine suffix is strictly after a function `return`; its allocation and stores cannot execute. Binaryen's output returns the same 4-byte object before that unreachable suffix. This is not evidence of a changed live result or side-effect order. It is also not just a compare-layer local-name or branch-polarity representation family, because Starshine emits additional unreachable allocation/store instructions that Binaryen has removed.

## Follow-up

The next DAE006 implementation step should be a small TDD pass cleanup, not another diagnostic normalizer:

1. Add a focused Moon regression for a DAE-touched function that leaves a `return` followed by allocation/store/value debris in the same instruction sequence.
2. Extend the existing DAE dead-suffix/raw-cleanup machinery to treat a root `return` as a terminating suffix boundary where it is safe to drop following instructions in that sequence.
3. Preserve operands/effects before the `return`; only remove instructions that are syntactically after the `return` and therefore unreachable.
4. Rebuild the native CLI and rerun the both-canonical artifact compare to discover the successor frontier.

This note only records the replay and classification; it does not change pass behavior.
