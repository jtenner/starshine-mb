# `heap-store-optimization` call_ref constructor-operand boundary

Question: does Binaryen `version_130` fold a later `struct.set` into a fresh `struct.new` when an earlier constructor operand is produced by `call_ref` and an unrelated mutable `global.set` appears between the constructor and later store?

## Answer

No. Binaryen preserves the `call_ref`-valued constructor operand, keeps the intervening unrelated mutable `global.set`, and leaves the later `struct.set`. Starshine already matched this no-fold boundary, so this slice is behavior-parity coverage, not an implementation change.

This extends the existing direct `call` / `call_indirect` constructor-operand no-swap boundaries to the typed-function-reference `call_ref` root. It does not generalize to all reference-typed control-flow or exception roots.

## Evidence

Local oracle:

- `wasm-opt --version` reported `wasm-opt version 130 (version_130)`.
- Probe file: `.tmp/hso-probe-call-ref.wat`.
- Command: `wasm-opt --all-features --heap-store-optimization .tmp/hso-probe-call-ref.wat -S -o .tmp/hso-probe-call-ref.opt.wat`.
- The optimized output for `$call_ref_ctor` kept `call_ref` inside `struct.new`, kept the intervening `global.set`, and kept the later `struct.set`.

Focused Starshine coverage:

- `src/passes/heap_store_optimization_test.mbt` adds `heap-store-optimization keeps call_ref constructor operands before unrelated global.set`.
- The test checks that optimized output still contains `call_ref`, `ref.as_non_null`, `global.set`, and `struct.set`, and that `global.set` remains before `struct.set`.

Validation:

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` passed `274/274` after adding this focused coverage.

## Classification

Binaryen behavior-parity negative/boundary. Not a Starshine win and not an accepted non-goal.

Reopen if Binaryen changes HSO `trySwap(...)` handling for `call_ref` constructor operands, or if Starshine starts folding this shape without a source-backed better-than-Binaryen argument.
