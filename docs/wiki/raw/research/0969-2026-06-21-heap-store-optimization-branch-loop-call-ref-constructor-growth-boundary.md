# 0969 - Heap-store-optimization branch-loop call_ref constructor growth boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle a typed-function-reference `call_ref` in a value-producing, branch-containing loop wrapper used as a fresh `struct.new` constructor operand when an unrelated growth root appears before a later `struct.set` to another field?

This extends the branch-containing direct-call and `call_indirect` constructor growth boundaries in `0965` and `0967`, plus the branchless loop-wrapped `call_ref` constructor growth boundary in `0963`. It does not cover store roots, ordinary direct calls, indirect calls, old-field operands, loop backedges, descriptor interactions, `return_call_ref`, or arbitrary branch/catch wrappers.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe files:

- `.tmp/hso-probe-branch-loop-call-ref-constructor-growth.wat`
- `.tmp/hso-probe-branch-loop-call-ref-constructor-table-growth.wat`

Both functions build a fresh `$pair` where field 0 is produced by a block result containing a loop with a branch to the outer result block:

```wat
(block $exit (result i32)
  (loop $loop
    (call_ref $callee (local.get $f))
    (i32.const 1)
    (br_if $exit)
    (drop)
  )
  (i32.const 3)
)
```

Then they execute either an unrelated `memory.grow` or `table.grow`, drop the growth result, write field 1 with a later `struct.set`, and read field 1.

Commands:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-branch-loop-call-ref-constructor-growth.wat \
  -S -o .tmp/hso-probe-branch-loop-call-ref-constructor-growth.opt.wat

grep -n "call_ref\|loop\|br_if\|memory.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-branch-loop-call-ref-constructor-growth.opt.wat

wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-branch-loop-call-ref-constructor-table-growth.wat \
  -S -o .tmp/hso-probe-branch-loop-call-ref-constructor-table-growth.opt.wat

grep -n "call_ref\|loop\|br_if\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-branch-loop-call-ref-constructor-table-growth.opt.wat
```

Observed grep summary:

```text
10:   (struct.new $pair
12:     (loop
14:       (br_if $block
15:        (call_ref $callee
28:   (memory.grow
32:  (struct.set $pair 1
10:   (struct.new $pair
12:     (loop
14:       (br_if $block
15:        (call_ref $callee
28:   (table.grow $0
33:  (struct.set $pair 1
```

## Finding

Binaryen preserves the branch-containing loop wrapper, the wrapped `call_ref` constructor operand, the unrelated `memory.grow` / `table.grow`, and the later `struct.set` to another field. It does not fold the later store into `struct.new` because doing so would move the constructor operand `call_ref` across an unrelated growth root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps branch-containing loop call_ref constructor operands before unrelated growth roots` passed immediately and asserts that the typed-function-reference call, `loop`, `br_if`, intervening growth root, and later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D constructor shallow-effect ordering coverage for branch-containing loop-wrapped `call_ref` constructor operands before unrelated growth roots.
- Adds HSO-G wrapper/no-swap evidence for a branch-containing loop/block wrapper around a typed-function-reference call constructor operand before unrelated `memory.grow` and `table.grow` roots.
- Does not generalize to store roots beyond `0968`, direct calls beyond `0965`, indirect calls beyond `0967`, old-field operands, loop backedges, branch/catch wrappers beyond this exact outer-block/inner-loop `br_if` shape, descriptor interactions, `return_call_ref`, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'branch-containing loop call_ref constructor operands before unrelated growth roots'
# Total tests: 335, passed: 335, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
