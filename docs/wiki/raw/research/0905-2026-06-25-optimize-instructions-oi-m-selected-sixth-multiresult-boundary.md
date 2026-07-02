# Optimize Instructions OI-M Selected Sixth Multi-Result Tuple Boundary

Date: 2026-06-25

## Question

How does Binaryen `version_130` handle a `tuple.extract` selecting the sixth scalar result from a multi-result tuple child, and should Starshine localize it yet?

## Oracle probe

Probe: `.tmp/oi-m-tuple-multiresult-selected-sixth-probe.wat`

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64)))
  (func (result i64)
    (tuple.extract 7 5
      (tuple.make 7
        (call $many)
        (i64.const 9)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-sixth-probe.wat -o -
```

Observed Binaryen output:

- Binaryen materializes the multi-result call into a tuple scratch local.
- It drops the first scalar lane from that scratch, stores/drops the selected sixth `i64` lane through a scalar temp, then reloads that temp as the function result.
- The non-selected trailing `i64.const 9` sibling disappears because it is pure and not needed after localization.

## Starshine slice

This remains a boundary/status slice after the 2026-07-02 arity-5 follow-up. Starshine's current direct-HOT tuple localizer proves selected children with one through five scalar results plus already-covered single-result effectful sibling drop/localization. The six-result selected-child case still stays fail-closed until it is source-probed, updated red-first, and implemented as its own bounded tuple-scratch/local-set slice.

Focused direct-HOT coverage in `src/passes/optimize_instructions_test.mbt` still uses `optimize-instructions intentionally keeps tuple.extract with multi-result selected sixth lane boundary`. The test asserts that Starshine keeps the `TupleExtract` at index `5`, the `TupleMake`, and the multi-result `Call` unchanged until a safe arity-6 selected-child tuple-scratch localizer exists.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-sixth-probe.wat -o -` passed and showed the tuple-scratch localization described above.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*selected sixth lane*'` passed `1/1`.

Full required slice validation is recorded in the commit that cites this note.

## Remaining work

Remaining OI-M work includes selected-child arities 6+, multi-result non-selected sibling tuple-scratch localization, public/binary tuple fixture coverage where representable, replay/reduction of the full `simplify-locals` `InvalidChildRef(3, 0, 0)` blocker, dedicated `tuple-optimization` neighbor reductions, and broader tee/drop reconstruction beyond the covered one-use selected/sibling localizer.
