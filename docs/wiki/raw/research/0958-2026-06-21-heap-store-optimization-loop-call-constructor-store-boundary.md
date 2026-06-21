# 0958 - Heap-store-optimization loop-wrapped call constructor store boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle a branchless `loop (result i32)` wrapping an ordinary direct `call` as a fresh `struct.new` constructor operand when an unrelated store root appears before a later `struct.set` to another field?

This extends the constructor-operand wrapper sweep beyond the block-wrapped direct-call cases in `0936` / `0937` and separates constructor-operand ordering from the old-field loop coverage in `0952` / `0953`. It does not cover loop backedges, branch-containing loop bodies, indirect calls, `call_ref`, descriptor interactions, or arbitrary wrappers.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-loop-call-constructor-store.wat`.

Both functions build a fresh `$pair` where field 0 is produced by:

```wat
(loop (result i32)
  (call $callee)
)
```

Then they execute either an unrelated `i32.store` or `table.set`, write field 1 with a later `struct.set`, and read field 1.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-loop-call-constructor-store.wat \
  -S -o .tmp/hso-probe-loop-call-constructor-store.opt.wat

grep -n "call\|loop\|i32.store\|table.set\|struct.new\|struct.set" \
  .tmp/hso-probe-loop-call-constructor-store.opt.wat
```

Observed grep summary:

```text
6: (func $callee (type $sig) (result i32)
12:   (struct.new $pair
13:    (loop (result i32)
14:     (call $callee)
19:  (i32.store
23:  (struct.set $pair 1
34:   (struct.new $pair
35:    (loop (result i32)
36:     (call $callee)
41:  (table.set $0
45:  (struct.set $pair 1
```

## Finding

Binaryen preserves the loop-wrapped direct call constructor operand, the unrelated `i32.store` / `table.set`, and the later `struct.set` to another field. It does not fold the later store into `struct.new` because doing so would move the constructor operand call across an unrelated store root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps loop-wrapped call constructor operands before unrelated stores` passed immediately and asserts that the loop-wrapped call, the intervening store root, and the later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D constructor shallow-effect ordering coverage for branchless loop-wrapped direct-call constructor operands before unrelated store roots.
- Adds HSO-G wrapper/no-swap evidence for `loop(call)` constructor operands before unrelated `i32.store` and `table.set` roots.
- Does not generalize to growth roots beyond `0959`, old-field boundaries beyond `0952` / `0953`, loop backedges, branch/catch wrappers, indirect calls, `call_ref`, descriptor interactions, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'loop-wrapped call constructor operands'
# Total tests: 325, passed: 325, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
