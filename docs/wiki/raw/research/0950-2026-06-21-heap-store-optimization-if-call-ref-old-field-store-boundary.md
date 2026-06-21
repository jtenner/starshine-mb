# 0950 - Heap-store-optimization if-wrapped call_ref old-field store boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle an overwritten constructor field whose original value is an `if (result i32)` wrapping a typed-function-reference `call_ref`, when an unrelated store root appears before the later same-field `struct.set`?

This extends the if-wrapper old-field sweep from ordinary direct calls (`0946` / `0947`) and `call_indirect` (`0948` / `0949`) to the typed-function-reference surface. It is distinct from the direct `call_ref` store/growth cases in `0930` / `0933` and the block-wrapped cases in `0942` / `0943`.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-if-call-ref-old-store.wat`.

Both functions build a fresh `$pair` where field 0 is produced by:

```wat
(if (result i32) (i32.const 1)
  (then
    (local.get $f)
    (ref.as_non_null)
    (call_ref $callee)
  )
  (else (i32.const 3))
)
```

Then they execute either an unrelated `i32.store` or `table.set`, overwrite field 0 with a later same-field `struct.set`, and read field 0.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-if-call-ref-old-store.wat \
  -S -o .tmp/hso-probe-if-call-ref-old-store.opt.wat

grep -n "call_ref\|if\|i32.store\|table.set\|struct.new\|struct.set" \
  .tmp/hso-probe-if-call-ref-old-store.opt.wat
```

Observed grep summary:

```text
10:   (struct.new $pair
11:    (if (result i32)
14:      (call_ref $callee
27:  (i32.store
31:  (struct.set $pair 0
42:   (struct.new $pair
43:    (if (result i32)
46:      (call_ref $callee
59:  (table.set $0
63:  (struct.set $pair 0
```

## Finding

Binaryen preserves the if-wrapped `call_ref`, the unrelated `i32.store` / `table.set`, and the later same-field `struct.set`. It does not fold the later store into `struct.new` because doing so would drop or move the overwritten typed-function-reference call old-field effect across an unrelated store root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps if-wrapped call_ref old fields before unrelated stores` passed immediately and asserts that `call_ref`, the intervening store root, and the later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D old-field side-effect preservation coverage for if-wrapped `call_ref` old fields before unrelated store roots.
- Adds HSO-G wrapper/no-swap evidence for `if(call_ref)` old-field operands before unrelated `i32.store` and `table.set` roots.
- Does not generalize to growth roots beyond `0951`, branch/catch wrappers, descriptor interactions, direct `return_call_ref`, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'if-wrapped call_ref old fields'
# Total tests: 317, passed: 317, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
