# Heap-store-optimization call_indirect old-field store boundaries

## Question

Does Binaryen `version_130` preserve a value-producing `call_indirect` old field when a later `struct.set` overwrites that field after an unrelated mutable store root?

## Probes

Fixtures:

- `.tmp/hso-probe-call-indirect-old-field-global-set.wat`
- `.tmp/hso-probe-call-indirect-old-field-table-set.wat`

Shared shape:

- construct `$pair` with field `0` from `call_indirect (type $callee) (i32.const 0)` and field `1` from `i32.const 2`;
- store the fresh struct in a local;
- execute either an unrelated mutable `global.set` or an unrelated `table.set`;
- later overwrite field `0` with `struct.set`.

Commands:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-indirect-old-field-global-set.wat \
  -S -o .tmp/hso-probe-call-indirect-old-field-global-set.opt.wat

wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-indirect-old-field-table-set.wat \
  -S -o .tmp/hso-probe-call-indirect-old-field-table-set.opt.wat
```

Grep evidence:

```text
# global.set case
9:   (struct.new $pair
10:    (call_indirect $0 (type $callee)
16:  (global.set $g
19:  (struct.set $pair 0

# table.set case
8:   (struct.new $pair
9:    (call_indirect $0 (type $callee)
15:  (table.set $0
19:  (struct.set $pair 0
```

## Result

Binaryen preserves the `call_indirect` old field, the intervening store root, and the later `struct.set` in both shapes. The old-field indirect call is not dropped or moved across the unrelated mutable store root.

Starshine already matched both boundaries. Added focused HSO-D/G coverage:

- `heap-store-optimization keeps call_indirect old fields before unrelated global.set`
- `heap-store-optimization keeps call_indirect old fields before unrelated table.set`

Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'call_indirect'
```

Result: `286/286` passed after this and the companion constructor-operand table-set coverage were present.

## Classification

HSO-D/G coverage-only Binaryen parity boundary. No implementation behavior changed; no native rebuild or direct compare was required.

## Reopening criteria

Reopen if Binaryen changes either old-field preservation rule, if Starshine starts dropping or moving the `call_indirect` old field across the intervening store root, or if a future source-backed rule proves a narrower safe fold for indirect-call old fields without changing call/table/global ordering.
