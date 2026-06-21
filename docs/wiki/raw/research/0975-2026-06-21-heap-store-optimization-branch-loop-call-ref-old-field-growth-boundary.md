# 0975 - Heap-store-optimization branch-loop call_ref old-field growth boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle an overwritten constructor field whose old value is produced by a typed-function-reference `call_ref` inside a value-producing, branch-containing loop wrapper when an unrelated growth root appears before a later same-field `struct.set`?

This extends the branch-containing `call_ref` constructor growth boundary in `0969` and the branchless loop-wrapped `call_ref` old-field growth boundary in `0957`. It does not cover store roots, ordinary direct calls, indirect calls, constructor-other-field operands, loop backedges, descriptor interactions, `return_call_ref`, or arbitrary branch/catch wrappers.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe files: `.tmp/hso-probe-branch-loop-call-ref-old-field-growth.wat` and `.tmp/hso-probe-branch-loop-call-ref-old-field-table-growth.wat`.

Both functions build a fresh `$pair` where field 0's overwritten old value is produced by a block result containing a loop with a branch to the outer result block:

```wat
(block (result i32)
  (loop
    (call_ref $callee (local.get $f))
    (i32.const 1)
    (br_if 1)
    (drop)
  )
  (i32.const 3)
)
```

Then they execute either an unrelated `memory.grow` or `table.grow`, drop the growth result, write field 0 with a later `struct.set`, and read field 0.

Commands:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-branch-loop-call-ref-old-field-growth.wat \
  -S -o .tmp/hso-probe-branch-loop-call-ref-old-field-growth.opt.wat

grep -n "call_ref\|loop\|br_if\|memory.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-branch-loop-call-ref-old-field-growth.opt.wat

wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-branch-loop-call-ref-old-field-table-growth.wat \
  -S -o .tmp/hso-probe-branch-loop-call-ref-old-field-table-growth.opt.wat

grep -n "call_ref\|loop\|br_if\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-branch-loop-call-ref-old-field-table-growth.opt.wat
```

Observed grep summaries:

```text
10:   (struct.new $pair
12:     (loop
14:       (br_if $block
15:        (call_ref $callee
28:   (memory.grow
32:  (struct.set $pair 0
```

```text
10:   (struct.new $pair
12:     (loop
14:       (br_if $block
15:        (call_ref $callee
28:   (table.grow $0
33:  (struct.set $pair 0
```

## Finding

Binaryen preserves the branch-containing loop wrapper, the wrapped `call_ref` old field, the unrelated `memory.grow` / `table.grow`, and the later same-field `struct.set`. It does not fold the later store into `struct.new` because doing so would move or discard the old-field typed-function-reference call across an unrelated growth root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps branch-containing loop call_ref old fields before unrelated growth roots` passed immediately and asserts that the `call_ref`, `loop`, `br_if`, intervening growth root, and later same-field `struct.set` remain in order.

## Coverage impact

- Adds HSO-D old-field side-effect preservation coverage for branch-containing loop-wrapped `call_ref` old fields before unrelated growth roots.
- Adds HSO-G wrapper/no-swap evidence for a branch-containing loop/block wrapper around a `call_ref` old field before unrelated `memory.grow` and `table.grow` roots.
- Does not generalize to store roots beyond `0974`, ordinary direct calls, `call_indirect`, constructor-other-field operands, loop backedges, branch/catch wrappers beyond this exact outer-block/inner-loop `br_if` shape, descriptor interactions, `return_call_ref`, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'branch-containing loop call_ref old fields before unrelated growth roots'
# Total tests: 341, passed: 341, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
