---
kind: research
status: supported
created: 2026-06-25
sources:
  - ./1051-2026-06-25-heap-store-optimization-mutable-descriptor-tail-oldfield-call.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
---

# HSO bottom tail-call descriptor old-field boundary

Question: is the exploratory `return_call_indirect`-as-overwritten-field shape from `1051` a source-backed old-field preservation family, a local invalid fixture, or a separate unreachable-constructor boundary?

## Answer

It is a separate bottom-typed unreachable-constructor boundary, not a normal old-field preservation family.

A local Binaryen `version_130` probe placed `return_call_indirect` as field `0` of `struct.new_desc`, followed by a catchable result-typed `try_table` / `return_call_indirect` wrapper and a later same-field `struct.set`. Binaryen accepted the input and rewrote the bottom-typed constructor to a synthetic block with dropped child operands and `unreachable`; it did not preserve `struct.new_desc` as an ordinary old-field side-effect case. The later wrapper and `struct.set` remained in the text, but they are after the tail-call field operand and therefore unreachable unless the tail call traps before transferring control.

Starshine accepts the same shape and produces validating output. It also removes `struct.new_desc`, keeps the `return_call_indirect`, `try_table`, and later `struct.set` surface, and may place the never-reached descriptor/value cleanup after the later store. That output-shape difference is behavior-safe for this narrow boundary: if the first `return_call_indirect` succeeds, control has left the function; if it traps, no later child or store executes.

## Probe commands

```sh
wasm-opt --all-features \
  .tmp/hso-probe-desc-mutable-oldfield-return-call-indirect.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-desc-mutable-oldfield-return-call-indirect.binaryen.wat

grep -nE "struct.new_desc|struct.set|return_call_indirect|try_table|global.get|unreachable|drop" \
  .tmp/hso-probe-desc-mutable-oldfield-return-call-indirect.binaryen.wat
```

Observed Binaryen markers: no `struct.new_desc`; a synthetic `block` with `drop(return_call_indirect ...)`, dropped later constructor children, `unreachable`, plus the later `try_table` / `return_call_indirect` and `struct.set`.

```sh
wasm-tools parse \
  .tmp/hso-probe-desc-mutable-oldfield-return-call-indirect.wat \
  -o .tmp/hso-probe-desc-mutable-oldfield-return-call-indirect.wasm
moon build --target-dir target --target native --release src/cmd
target/native/release/build/cmd/cmd.exe \
  .tmp/hso-probe-desc-mutable-oldfield-return-call-indirect.wasm \
  --heap-store-optimization \
  --dump .tmp/hso-probe-desc-mutable-oldfield-return-call-indirect.starshine.wasm \
  -o .tmp/hso-probe-desc-mutable-oldfield-return-call-indirect.starshine.out.wasm
wasm-tools validate --features all \
  .tmp/hso-probe-desc-mutable-oldfield-return-call-indirect.starshine.out.wasm
wasm-tools print \
  .tmp/hso-probe-desc-mutable-oldfield-return-call-indirect.starshine.out.wasm \
  > .tmp/hso-probe-desc-mutable-oldfield-return-call-indirect.starshine.wat
```

Result: Starshine exited `0`, `wasm-tools validate --features all` passed, and the printed output kept `return_call_indirect`, `try_table`, and `struct.set` while removing `struct.new_desc`.

## Focused coverage

Added:

- `heap-store-optimization handles bottom return_call_indirect descriptor old fields`

The test asserts that the pass succeeds, the output keeps the tail-call and wrapper/store surface, and `struct.new_desc` is gone. This guards the local validation surface without reclassifying bottom tail calls as ordinary old-field preservation.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `414/414` passed.

```sh
moon fmt
```

Result: passed.

```sh
moon build --target-dir target --target native --release src/cmd
```

Result: passed/no work to do.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-bottom-tail-oldfield-direct-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized matches `1000`, compare-normalized matches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, mismatches `0`, Binaryen cache `1000` hits / `0` misses.

## Classification and reopening criteria

Classification: source-backed boundary / explicit non-goal for normal old-field preservation. Bottom-typed `return_call_indirect` constructor operands make the constructor unreachable, so this does not satisfy the generated true call-result old-field blocker from `1047`.

Reopen if Binaryen starts preserving `struct.new_desc` for this bottom old-field shape, if Starshine emits invalid output for the focused test, or if a non-bottom result-producing tail-call-like operand becomes representable and source-backed as an actually completed constructor field.
