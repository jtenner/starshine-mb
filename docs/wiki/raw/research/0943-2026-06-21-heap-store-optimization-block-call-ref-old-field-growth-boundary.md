# Heap-store-optimization block-wrapped call_ref old-field growth boundaries

Date: 2026-06-21

## Question

Do the typed-function-reference `call_ref` old-field growth-root no-fold boundaries from `0933` also apply when the overwritten constructor field itself is a value-producing `block` wrapping `call_ref`?

## Probe

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture:

- `.tmp/hso-probe-block-call-ref-old-growth.wat`

Shape: field `0` of a fresh `struct.new` is produced by a `block (result i32)` wrapping `(call_ref $callee (ref.as_non_null (local.get $fn)))`; an unrelated `memory.grow` or `table.grow` root follows; a later `struct.set` overwrites field `0`.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-block-call-ref-old-growth.wat \
  -S -o .tmp/hso-probe-block-call-ref-old-growth.opt.wat

grep -n "call_ref\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-block-call-ref-old-growth.opt.wat
```

Grep evidence:

```text
13:   (struct.new $pair
15:     (call_ref $callee
25:   (memory.grow
29:  (struct.set $pair 0
40:   (struct.new $pair
42:     (call_ref $callee
52:   (table.grow $0
57:  (struct.set $pair 0
```

Binaryen preserves the block-wrapped `call_ref`, the intervening growth root, and the later same-field `struct.set` for both shapes.

## Starshine result

Added focused HSO-D/G coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps block-wrapped call_ref old fields before unrelated growth roots`

Starshine already matched Binaryen. Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'block-wrapped call_ref old fields before unrelated growth roots'
```

Result: `309/309` passed after adding the coverage.

## Classification

Coverage-only Binaryen parity boundary. No implementation changed, so no native rebuild or direct compare was required.

This closes only block-wrapped typed-function-reference `call_ref` overwritten constructor fields before unrelated `memory.grow` and `table.grow` roots. It does not close arbitrary wrapper forms, descriptor interactions, branch/catch wrappers, `return_call_ref`, or all mutable/growth roots.

## Reopening criteria

Reopen if Binaryen changes either block-wrapped `call_ref` old-field growth boundary, if Starshine starts dropping or moving the block-wrapped `call_ref` across the intervening growth root, or if a future source-backed rule proves a narrower safe fold that preserves typed-function-reference call effects, old-field side effects, and growth ordering.
