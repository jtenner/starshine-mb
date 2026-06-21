# Heap-store-optimization call_indirect memory-store boundaries

## Question

Does Binaryen `version_130` preserve `call_indirect` constructor and old-field values before an unrelated ordinary memory store?

## Probes

Fixtures:

- `.tmp/hso-probe-call-indirect-constructor-memory-store.wat`
- `.tmp/hso-probe-call-indirect-old-field-memory-store.wat`

Shapes:

1. Constructor operand boundary:
   - construct `$pair` with field `0` from `call_indirect (type $callee) (i32.const 0)` and field `1` from `i32.const 2`;
   - store the fresh struct in a local;
   - execute unrelated `i32.store`;
   - later write field `1` with `struct.set`.
2. Old-field boundary:
   - same constructor, but the later `struct.set` overwrites field `0`, whose old value is the `call_indirect` result.

Commands:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-indirect-constructor-memory-store.wat \
  -S -o .tmp/hso-probe-call-indirect-constructor-memory-store.opt.wat

wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-indirect-old-field-memory-store.wat \
  -S -o .tmp/hso-probe-call-indirect-old-field-memory-store.opt.wat
```

Grep evidence:

```text
# constructor operand case
9:   (struct.new $pair
10:    (call_indirect $0 (type $callee)
16:  (i32.store
20:  (struct.set $pair 1

# old-field case
9:   (struct.new $pair
10:    (call_indirect $0 (type $callee)
16:  (i32.store
20:  (struct.set $pair 0
```

## Result

Binaryen preserves the indirect call, the intervening `i32.store`, and the later `struct.set` in both shapes. The ordinary memory store remains an ordering boundary for these indirect-call values.

Starshine already matched both boundaries. Added focused HSO-D/G coverage:

- `heap-store-optimization keeps call_indirect constructor operands before unrelated i32.store`
- `heap-store-optimization keeps call_indirect old fields before unrelated i32.store`

Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'call_indirect'
```

Result: `288/288` passed.

## Classification

HSO-D/G coverage-only Binaryen parity boundary. No implementation behavior changed; no native rebuild or direct compare was required.

## Reopening criteria

Reopen if Binaryen changes either indirect-call memory-store boundary, if Starshine starts moving or dropping `call_indirect` across the intervening `i32.store`, or if a future source-backed rule proves a narrower safe fold for indirect-call values across ordinary memory stores.
