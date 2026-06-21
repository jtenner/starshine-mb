---
kind: research
status: active
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/heap-store-optimization.wast
---

# HSO tee plus later chain parity fix

Question: does Starshine match Binaryen `version_130` for the dedicated lit family where an immediate tee-wrapped `struct.set` is followed by later `local.get`-based stores to the same fresh struct?

## Answer

Not before this slice. Binaryen's dedicated lit function `$tee-and-subsequent` folds all three stores into one `struct.new`: the first store is through `local.tee(struct.new ...)`, then two later `struct.set(local.get ...)` roots update the remaining fields. Starshine previously folded only the immediate tee store and left the later `local.get` stores in place.

This was a behavior-parity gap, not an intentional Starshine output difference: Binaryen removes the whole tee-plus-later-store chain, and no Starshine win justified retaining the later stores.

## Test-first result

Added focused test:

- `heap-store-optimization folds tee plus later local-get struct.set chain`

Initial focused run failed as expected:

```text
body_raw:
  (i32.const I32(40))(i32.const I32(20))(i32.const I32(30))(struct.new (Type 0))(local.set (Local 0))
  (local.get (Local 0))(i32.const I32(50))(struct.set (Type 0) U32(1))
  (local.get (Local 0))(i32.const I32(60))(struct.set (Type 0) U32(2))
  ...
```

That showed the first tee value was folded into field `0`, but fields `1` and `2` remained as later `struct.set`s.

## Implementation change

Refactored the later-`local.set(struct.new)` chain scanner into `hso_process_local_set_chain(...)` and reused it after a successful tee fold. The tee fold still materializes the `local.set` replacement for the `local.tee`, but now immediately continues scanning the same original root suffix for matching `struct.set(local.get)` roots. This preserves the existing one-pass boundary tests that intentionally should not become second-pass cleanup, unlike the rejected fixed-point attempt.

## Validation

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-tee-chain-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
moon test
```

Results:

- `moon info` passed with three pre-existing warnings in `src/validate/gen_valid*.mbt`.
- `moon fmt` passed.
- Focused HSO tests passed: `200/200`.
- `moon test src/passes` passed: `2828/2828`.
- Native `src/cmd` release build passed with pre-existing unused helper warnings in `src/passes/pass_manager.mbt`.
- Direct 10000-case compare passed: compared `10000/10000`, normalized matches `10000`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, Binaryen cache `10000` hits / `0` misses.
- Full `moon test` passed: `6141/6141`.

## Audit status

This advances `[O4Z-AUDIT-HSO-C]` by implementing the source-backed Binaryen `$tee-and-subsequent` core-chain family. HSO-C remains open for broader lit chain review and any remaining debris/output-shape classification.
