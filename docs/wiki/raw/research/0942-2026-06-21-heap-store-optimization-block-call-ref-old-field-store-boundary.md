# Heap-store-optimization block-wrapped call_ref old-field store boundaries

Date: 2026-06-21

## Question

Do the typed-function-reference `call_ref` old-field no-fold boundaries from `0915`, `0917`, `0930`, and the block-wrapped constructor-operand store boundary from `0940` also apply when the overwritten constructor field itself is a value-producing `block` wrapping `call_ref` and the intervening root is an ordinary store?

## Probe

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture:

- `.tmp/hso-probe-block-call-ref-old-store.wat`

Shape: field `0` of a fresh `struct.new` is produced by a `block (result i32)` wrapping `(call_ref $callee (ref.as_non_null (local.get $fn)))`; an unrelated `i32.store` or `table.set` root follows; a later `struct.set` overwrites field `0`.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-block-call-ref-old-store.wat \
  -S -o .tmp/hso-probe-block-call-ref-old-store.opt.wat

grep -n "call_ref\|i32.store\|table.set\|struct.new\|struct.set" \
  .tmp/hso-probe-block-call-ref-old-store.opt.wat
```

Grep evidence:

```text
13:   (struct.new $pair
15:     (call_ref $callee
24:  (i32.store
28:  (struct.set $pair 0
39:   (struct.new $pair
41:     (call_ref $callee
50:  (table.set $0
54:  (struct.set $pair 0
```

Binaryen preserves the block-wrapped `call_ref`, the intervening ordinary store root, and the later same-field `struct.set` for both shapes.

## Starshine result

Added focused HSO-D/G coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps block-wrapped call_ref old fields before unrelated stores`

Starshine already matched Binaryen. Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'block-wrapped call_ref old fields before unrelated stores'
```

Result: `308/308` passed after adding the coverage.

## Classification

Coverage-only Binaryen parity boundary. No implementation changed, so no native rebuild or direct compare was required.

This closes only block-wrapped typed-function-reference `call_ref` overwritten constructor fields before unrelated `i32.store` and `table.set` roots. It does not close arbitrary wrapper forms, `call_ref` constructor wrappers beyond `0940`, growth roots, descriptor interactions, branch/catch wrappers, `return_call_ref`, or all mutable roots.

## Reopening criteria

Reopen if Binaryen changes either block-wrapped `call_ref` old-field store boundary, if Starshine starts dropping or moving the block-wrapped `call_ref` across the intervening store root, or if a future source-backed rule proves a narrower safe fold that preserves typed-function-reference call effects, old-field side effects, and ordinary-store ordering.
