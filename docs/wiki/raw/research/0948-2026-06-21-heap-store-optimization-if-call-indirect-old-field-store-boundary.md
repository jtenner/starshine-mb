# 0948 - Heap-store-optimization if-wrapped call_indirect old-field store boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle an overwritten constructor field whose original value is an `if (result i32)` wrapping `call_indirect`, when an unrelated store root appears before the later same-field `struct.set`?

This extends the if-wrapper sweep from the ordinary direct-call old-field cases in `0946` / `0947` to the indirect-call surface.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-if-call-indirect-old-store.wat`.

Both functions build a fresh `$pair` where field 0 is produced by:

```wat
(if (result i32) (i32.const 1)
  (then (call_indirect (type $sig) (i32.const 0)))
  (else (i32.const 3))
)
```

Then they execute either an unrelated `i32.store` or `table.set`, overwrite field 0 with a later `struct.set`, and read field 0.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-if-call-indirect-old-store.wat \
  -S -o .tmp/hso-probe-if-call-indirect-old-store.opt.wat

grep -n "call_indirect\|if\|i32.store\|table.set\|struct.new\|struct.set" \
  .tmp/hso-probe-if-call-indirect-old-store.opt.wat
```

Observed grep summary:

```text
13:   (struct.new $pair
14:    (if (result i32)
17:      (call_indirect $0 (type $sig)
28:  (i32.store
32:  (struct.set $pair 0
43:   (struct.new $pair
44:    (if (result i32)
47:      (call_indirect $0 (type $sig)
58:  (table.set $0
62:  (struct.set $pair 0
```

## Finding

Binaryen preserves the if-wrapped `call_indirect`, the unrelated `i32.store` / `table.set`, and the later same-field `struct.set`. It does not fold the later store into `struct.new` because that would drop or move the overwritten indirect-call old-field effect across an unrelated store root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps if-wrapped call_indirect old fields before unrelated stores` passed immediately and asserts that `call_indirect`, the intervening store root, and the later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D old-field side-effect preservation coverage for if-wrapped `call_indirect` old fields before unrelated store roots.
- Adds HSO-G wrapper/no-swap evidence for `if(call_indirect)` old-field operands before unrelated `i32.store` and `table.set` roots.
- Does not generalize to growth roots beyond `0949`, branch/catch wrappers, descriptor interactions, direct `call_ref` / `return_call_ref`, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'if-wrapped call_indirect old fields'
# Total tests: 315, passed: 315, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
