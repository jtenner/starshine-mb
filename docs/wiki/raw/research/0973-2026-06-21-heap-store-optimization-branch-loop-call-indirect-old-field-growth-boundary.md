# 0973 - Heap-store-optimization branch-loop call_indirect old-field growth boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle an overwritten constructor field whose old value is produced by a `call_indirect` inside a value-producing, branch-containing loop wrapper when an unrelated growth root appears before a later same-field `struct.set`?

This extends the branch-containing `call_indirect` constructor growth boundary in `0967` and the branchless loop-wrapped `call_indirect` old-field growth boundary in `0955`. It does not cover store roots, ordinary direct calls, typed-function-reference calls, constructor-other-field operands, loop backedges, descriptor interactions, `return_call_ref`, or arbitrary branch/catch wrappers.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-branch-loop-call-indirect-old-field-growth.wat`.

Both functions build a fresh `$pair` where field 0's overwritten old value is produced by a block result containing a loop with a branch to the outer result block:

```wat
(block $exit (result i32)
  (loop $loop
    (call_indirect (type $callee) (i32.const 0))
    (i32.const 1)
    (br_if $exit)
    (drop)
  )
  (i32.const 3)
)
```

Then they execute either an unrelated `memory.grow` or `table.grow`, drop the growth result, write field 0 with a later `struct.set`, and read field 0.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-branch-loop-call-indirect-old-field-growth.wat \
  -S -o .tmp/hso-probe-branch-loop-call-indirect-old-field-growth.opt.wat

grep -n "call_indirect\|loop\|br_if\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-branch-loop-call-indirect-old-field-growth.opt.wat
```

Observed grep summary:

```text
15:   (struct.new $pair
17:     (loop $loop
19:       (br_if $exit
20:        (call_indirect $0 (type $callee)
33:   (memory.grow
37:  (struct.set $pair 0
48:   (struct.new $pair
50:     (loop $loop
52:       (br_if $exit
53:        (call_indirect $0 (type $callee)
66:   (table.grow $0
71:  (struct.set $pair 0
```

## Finding

Binaryen preserves the branch-containing loop wrapper, the wrapped indirect-call old field, the unrelated `memory.grow` / `table.grow`, and the later same-field `struct.set`. It does not fold the later store into `struct.new` because doing so would move or discard the old-field indirect call across an unrelated growth root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps branch-containing loop call_indirect old fields before unrelated growth roots` passed immediately and asserts that the `call_indirect`, `loop`, `br_if`, intervening growth root, and later same-field `struct.set` remain in order.

## Coverage impact

- Adds HSO-D old-field side-effect preservation coverage for branch-containing loop-wrapped `call_indirect` old fields before unrelated growth roots.
- Adds HSO-G wrapper/no-swap evidence for a branch-containing loop/block wrapper around a `call_indirect` old field before unrelated `memory.grow` and `table.grow` roots.
- Does not generalize to store roots beyond `0972`, ordinary direct calls, `call_ref`, constructor-other-field operands, loop backedges, branch/catch wrappers beyond this exact outer-block/inner-loop `br_if` shape, descriptor interactions, `return_call_ref`, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'branch-containing loop call_indirect old fields before unrelated growth roots'
# Total tests: 339, passed: 339, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
