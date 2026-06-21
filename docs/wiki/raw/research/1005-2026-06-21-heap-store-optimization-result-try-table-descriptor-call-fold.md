---
kind: research
status: supported
created: 2026-06-21
sources:
  - ../../../../src/passes/heap_store_optimization.mbt
  - ../../../../src/passes/heap_store_optimization_test.mbt
  - ../../../../docs/wiki/binaryen/passes/heap-store-optimization/index.md
  - ../../../../docs/wiki/binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/HeapStoreOptimization.cpp
---

# HSO result-typed `try_table` descriptor call fold

## Question

Does Binaryen `version_130` fold a later `struct.set` into a descriptor constructor when an intervening result-typed `try_table` body contains a catchable direct call and the descriptor operand is an immutable descriptor global?

This narrows the result-typed `try_table` audit by checking descriptor operands in a catchable direct-call wrapper. It is distinct from the void catchable descriptor-call boundary in `0984` and from the result-typed tail-call no-fold boundaries in `0996`, `0999`, and `1000`.

## Binaryen probe

Probe file:

- `.tmp/hso-result-try-desc-call-value.wat`

Command:

```sh
wasm-opt --all-features .tmp/hso-result-try-desc-call-value.wat --heap-store-optimization -S -o .tmp/hso-result-try-desc-call-value.opt.wat
```

Result: Binaryen moves the pure descriptor constructor after the dropped result-typed `try_table`, folds `i32.const 9` into `struct.new_desc`, preserves the wrapper and catchable direct call, preserves the immutable descriptor `global.get`, and removes the later `struct.set`.

## Starshine gap and fix

Red-first focused test:

- `heap-store-optimization folds descriptor constructors across result try_table calls`

Initial Starshine behavior preserved the descriptor `struct.new_desc` before the result wrapper and kept the later `struct.set`, overblocking the Binaryen fold.

Implementation change:

- `src/passes/heap_store_optimization.mbt`
  - Recognizes a narrow dropped result-typed `try_table` block wrapper as swappable before a constructor local-set when the constructor operands have no ordering conflict with the wrapper and the wrapper does not touch the target local.
  - Keeps tail-call and throw bodies excluded from this positive so the existing result-typed `return_call`, `return_call_indirect`, and `return_call_ref` set-value boundaries remain intact.

## Validation

Focused red/green command after the fix:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'result try_table'
```

Result: `374/374` passed.

Additional validation:

```sh
moon fmt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-result-try-desc-call-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Results:

- `moon fmt` passed.
- Focused HSO tests passed `374/374`.
- Native `src/cmd` build passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Direct 10000-case `heap-store-optimization` compare matched `10000/10000` with `10000` normalized matches, `0` mismatches, `0` validation/property/generator failures, and `0` command failures.

## Classification and reopening criteria

Classification: HSO-D/F/G behavior-parity fix. Binaryen folds this descriptor set-value shape; Starshine now matches by allowing only the dropped result-wrapper direct-call positive while retaining the tail-call and throw no-fold boundaries.

Reopen if Binaryen changes result-typed descriptor-call wrapper movement, if mutable descriptor globals start folding across catchable calls, if Starshine reintroduces a broad try-table swap that drops the tail-call/throw boundaries, or if direct compare exposes another descriptor result-wrapper family with different behavior.
