# 0970 - Heap-store-optimization branch-loop call old-field store boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle an overwritten constructor field whose old value is produced by an ordinary direct `call` inside a value-producing, branch-containing loop wrapper when an unrelated store root appears before a later same-field `struct.set`?

This extends the branch-containing direct-call constructor store boundary in `0964` and the branchless loop-wrapped direct-call old-field store boundary in `0952`. It does not cover growth roots, indirect calls, typed-function-reference calls, constructor-other-field operands, loop backedges, descriptor interactions, `return_call_ref`, or arbitrary branch/catch wrappers.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-branch-loop-call-old-field-store.wat`.

Both functions build a fresh `$pair` where field 0's overwritten old value is produced by a block result containing a loop with a branch to the outer result block:

```wat
(block $exit (result i32)
  (loop $loop
    (call $callee)
    (i32.const 1)
    (br_if $exit)
    (drop)
  )
  (i32.const 3)
)
```

Then they execute either an unrelated `i32.store` or `table.set`, write field 0 with a later `struct.set`, and read field 0.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-branch-loop-call-old-field-store.wat \
  -S -o .tmp/hso-probe-branch-loop-call-old-field-store.opt.wat

grep -n "call\|loop\|br_if\|i32.store\|table.set\|struct.new\|struct.set" \
  .tmp/hso-probe-branch-loop-call-old-field-store.opt.wat
```

Observed grep summary:

```text
12:   (struct.new $pair
14:     (loop
16:       (br_if $block
17:        (call $callee)
27:  (i32.store
31:  (struct.set $pair 0
42:   (struct.new $pair
44:     (loop
46:       (br_if $block
47:        (call $callee)
57:  (table.set $0
61:  (struct.set $pair 0
```

## Finding

Binaryen preserves the branch-containing loop wrapper, the wrapped direct-call old field, the unrelated `i32.store` / `table.set`, and the later same-field `struct.set`. It does not fold the later store into `struct.new` because doing so would move or discard the old-field call across an unrelated store root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps branch-containing loop call old fields before unrelated stores` passed immediately and asserts that the call, `loop`, `br_if`, intervening store root, and later same-field `struct.set` remain in order.

## Coverage impact

- Adds HSO-D old-field side-effect preservation coverage for branch-containing loop-wrapped direct-call old fields before unrelated store roots.
- Adds HSO-G wrapper/no-swap evidence for a branch-containing loop/block wrapper around a direct-call old field before unrelated `i32.store` and `table.set` roots.
- Does not generalize to growth roots, `call_indirect`, `call_ref`, constructor-other-field operands, loop backedges, branch/catch wrappers beyond this exact outer-block/inner-loop `br_if` shape, descriptor interactions, `return_call_ref`, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'branch-containing loop call old fields before unrelated stores'
# Total tests: 337, passed: 337, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
