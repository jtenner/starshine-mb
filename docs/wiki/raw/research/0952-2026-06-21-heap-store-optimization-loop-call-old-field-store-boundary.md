# 0952 - Heap-store-optimization loop-wrapped call old-field store boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle an overwritten constructor field whose original value is a branchless `loop (result i32)` wrapping an ordinary direct `call`, when an unrelated store root appears before the later same-field `struct.set`?

This extends the old-field wrapper sweep beyond the block-wrapped direct-call cases in `0936` / `0937` and the if-wrapped direct-call cases in `0946` / `0947`. It does not cover looping branches or arbitrary loop bodies.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-loop-call-old-store.wat`.

Both functions build a fresh `$pair` where field 0 is produced by:

```wat
(loop (result i32)
  (call $callee)
)
```

Then they execute either an unrelated `i32.store` or `table.set`, overwrite field 0 with a later same-field `struct.set`, and read field 0.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-loop-call-old-store.wat \
  -S -o .tmp/hso-probe-loop-call-old-store.opt.wat

grep -n "call\|loop\|i32.store\|table.set\|struct.new\|struct.set" \
  .tmp/hso-probe-loop-call-old-store.opt.wat
```

Observed grep summary:

```text
6: (func $callee (type $sig) (result i32)
12:   (struct.new $pair
13:    (loop (result i32)
14:     (call $callee)
19:  (i32.store
23:  (struct.set $pair 0
34:   (struct.new $pair
35:    (loop (result i32)
36:     (call $callee)
41:  (table.set $0
45:  (struct.set $pair 0
```

## Finding

Binaryen preserves the loop-wrapped direct call, the unrelated `i32.store` / `table.set`, and the later same-field `struct.set`. It does not fold the later store into `struct.new` because doing so would drop or move the overwritten call old-field effect across an unrelated store root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps loop-wrapped call old fields before unrelated stores` passed immediately and asserts that the loop-wrapped call, the intervening store root, and the later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D old-field side-effect preservation coverage for branchless loop-wrapped direct-call old fields before unrelated store roots.
- Adds HSO-G wrapper/no-swap evidence for `loop(call)` old-field operands before unrelated `i32.store` and `table.set` roots.
- Does not generalize to growth roots beyond `0953`, loop backedges, branch/catch wrappers, indirect calls, `call_ref`, descriptor interactions, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'loop-wrapped call old fields'
# Total tests: 319, passed: 319, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
