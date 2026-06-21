# 0962 - Heap-store-optimization loop-wrapped call_ref constructor store boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle a branchless `loop (result i32)` wrapping typed-function-reference `call_ref` as a fresh `struct.new` constructor operand when an unrelated store root appears before a later `struct.set` to another field?

This extends the constructor-operand wrapper sweep beyond the block-wrapped `call_ref` store cases in `0940`, the direct-root `call_ref` store case in `0930`, the direct-call loop constructor store case in `0958`, and the `call_indirect` loop constructor store case in `0960`. It does not cover growth roots, old-field operands, loop backedges, branch-containing loops, descriptor interactions, `return_call_ref`, or arbitrary wrappers.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-loop-call-ref-constructor-store.wat`.

Both functions build a fresh `$pair` where field 0 is produced by:

```wat
(loop (result i32)
  (call_ref $callee (ref.as_non_null (local.get $f)))
)
```

Then they execute either an unrelated `i32.store` or `table.set`, write field 1 with a later `struct.set`, and read field 1.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-loop-call-ref-constructor-store.wat \
  -S -o .tmp/hso-probe-loop-call-ref-constructor-store.opt.wat

grep -n "call_ref\|loop\|i32.store\|table.set\|struct.new\|struct.set" \
  .tmp/hso-probe-loop-call-ref-constructor-store.opt.wat
```

Observed grep summary:

```text
13:   (struct.new $pair
14:    (loop (result i32)
15:     (call_ref $callee
24:  (i32.store
28:  (struct.set $pair 1
39:   (struct.new $pair
40:    (loop (result i32)
41:     (call_ref $callee
50:  (table.set $0
54:  (struct.set $pair 1
```

## Finding

Binaryen preserves the loop-wrapped `call_ref` constructor operand, the unrelated `i32.store` / `table.set`, and the later `struct.set` to another field. It does not fold the later store into `struct.new` because doing so would move the constructor operand `call_ref` across an unrelated store root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps loop-wrapped call_ref constructor operands before unrelated stores` passed immediately and asserts that the loop-wrapped typed call, the intervening store root, and the later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D constructor shallow-effect ordering coverage for branchless loop-wrapped `call_ref` constructor operands before unrelated store roots.
- Adds HSO-G wrapper/no-swap evidence for `loop(call_ref)` constructor operands before unrelated `i32.store` and `table.set` roots.
- Does not generalize to growth roots, old-field boundaries beyond `0956` / `0957`, loop backedges, branch/catch wrappers, `return_call_ref`, descriptor interactions, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'loop-wrapped call_ref constructor operands before unrelated stores'
# Total tests: 328, passed: 328, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
