# `heap-store-optimization` call_ref old-field boundary

Question: does Binaryen `version_130` fold a later `struct.set` into a fresh `struct.new` when the overwritten constructor field was produced by `call_ref` and an unrelated mutable `global.set` appears between the constructor and later store?

## Answer

No. Binaryen preserves the `call_ref`-valued old constructor field, keeps the intervening unrelated mutable `global.set`, and leaves the later `struct.set`. Starshine already matched this no-fold boundary, so this slice is behavior-parity coverage, not an implementation change.

This complements the direct call-ref constructor-operand boundary in `0914`: the typed-function-reference call root is also conservative when it is the overwritten field value.

## Evidence

Local oracle:

- `wasm-opt --version` reported `wasm-opt version 130 (version_130)`.
- Probe file: `.tmp/hso-probe-call-ref-old-field.wat`.
- Command: `wasm-opt --all-features --heap-store-optimization .tmp/hso-probe-call-ref-old-field.wat -S -o .tmp/hso-probe-call-ref-old-field.opt.wat`.
- The optimized output for `$call_ref_old_field` kept `call_ref` inside `struct.new`, kept the intervening `global.set`, and kept the later `struct.set`.

Focused Starshine coverage:

- `src/passes/heap_store_optimization_test.mbt` adds `heap-store-optimization keeps call_ref old fields before unrelated global.set`.
- The test checks that optimized output still contains `call_ref`, `global.set`, and `struct.set`, and that `global.set` remains before `struct.set`.

Validation:

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` passed `275/275` after adding this focused coverage.

## Classification

Binaryen behavior-parity negative/boundary. Not a Starshine win and not an accepted non-goal.

Reopen if Binaryen starts preserving `call_ref` old-field effects under `drop` while removing the later `struct.set`, or if Starshine starts folding this shape without a source-backed better-than-Binaryen argument.
