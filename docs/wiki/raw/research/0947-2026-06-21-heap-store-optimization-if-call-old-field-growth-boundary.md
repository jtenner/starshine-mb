# 0947 - Heap-store-optimization if-wrapped call old-field growth boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle an overwritten constructor field whose original value is an `if (result i32)` wrapping an ordinary direct `call`, when an unrelated growth root appears before the later same-field `struct.set`?

This is the growth-root counterpart to `0946`'s if-wrapped direct-call old-field store-root boundary.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-if-call-old-growth.wat`.

Both functions build a fresh `$pair` where field 0 is produced by:

```wat
(if (result i32) (i32.const 1)
  (then (call $helper (i32.const 1)))
  (else (i32.const 3))
)
```

Then they execute either an unrelated `memory.grow` or `table.grow`, overwrite field 0 with a later `struct.set`, and read field 0.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-if-call-old-growth.wat \
  -S -o .tmp/hso-probe-if-call-old-growth.opt.wat

grep -n "call\|if\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-if-call-old-growth.opt.wat
```

Observed grep summary:

```text
11:   (struct.new $pair
12:    (if (result i32)
15:      (call $helper
27:   (memory.grow
31:  (struct.set $pair 0
42:   (struct.new $pair
43:    (if (result i32)
46:      (call $helper
58:   (table.grow $0
63:  (struct.set $pair 0
```

## Finding

Binaryen preserves the if-wrapped direct `call`, the unrelated `memory.grow` / `table.grow`, and the later same-field `struct.set`. It does not fold the later store into `struct.new` because that would drop or move the overwritten old-field call effect across an unrelated growth root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps if-wrapped call old fields before unrelated growth roots` passed immediately and asserts that the call, the intervening growth root, and the later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D old-field side-effect preservation coverage for if-wrapped direct-call old fields before unrelated growth roots.
- Adds HSO-G wrapper/no-swap evidence for `if(call)` old-field operands before unrelated `memory.grow` and `table.grow` roots.
- Does not generalize to store roots beyond `0946`, branch/catch wrappers, descriptor interactions, `call_indirect` / `call_ref` if-wrappers, direct `return_call_ref`, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'if-wrapped call old fields'
# Total tests: 313, passed: 313, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
