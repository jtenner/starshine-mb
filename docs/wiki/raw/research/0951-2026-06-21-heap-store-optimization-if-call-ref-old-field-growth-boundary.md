# 0951 - Heap-store-optimization if-wrapped call_ref old-field growth boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle an overwritten constructor field whose original value is an `if (result i32)` wrapping a typed-function-reference `call_ref`, when an unrelated growth root appears before the later same-field `struct.set`?

This is the growth-root companion to `0950` and is distinct from the direct `call_ref` growth cases in `0933` and the block-wrapped `call_ref` old-field growth cases in `0943`.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-if-call-ref-old-growth.wat`.

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

Then they execute either an unrelated `memory.grow` or `table.grow`, overwrite field 0 with a later same-field `struct.set`, and read field 0.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-if-call-ref-old-growth.wat \
  -S -o .tmp/hso-probe-if-call-ref-old-growth.opt.wat

grep -n "call_ref\|if\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-if-call-ref-old-growth.opt.wat
```

Observed grep summary:

```text
10:   (struct.new $pair
11:    (if (result i32)
14:      (call_ref $callee
28:   (memory.grow
32:  (struct.set $pair 0
43:   (struct.new $pair
44:    (if (result i32)
47:      (call_ref $callee
61:   (table.grow $0
66:  (struct.set $pair 0
```

## Finding

Binaryen preserves the if-wrapped `call_ref`, the unrelated `memory.grow` / `table.grow`, and the later same-field `struct.set`. It does not fold the later store into `struct.new` because doing so would drop or move the overwritten typed-function-reference call old-field effect across an unrelated growth root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps if-wrapped call_ref old fields before unrelated growth roots` passed immediately and asserts that `call_ref`, the intervening growth root, and the later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D old-field side-effect preservation coverage for if-wrapped `call_ref` old fields before unrelated growth roots.
- Adds HSO-G wrapper/no-swap evidence for `if(call_ref)` old-field operands before unrelated `memory.grow` and `table.grow` roots.
- Does not generalize to store roots beyond `0950`, branch/catch wrappers, descriptor interactions, direct `return_call_ref`, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'if-wrapped call_ref old fields'
# Total tests: 317, passed: 317, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
