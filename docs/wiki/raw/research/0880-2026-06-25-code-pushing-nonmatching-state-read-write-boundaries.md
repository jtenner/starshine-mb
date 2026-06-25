# Code-pushing nonmatching state-read/write boundaries

Date: 2026-06-25

## Question

After matching read/write boundaries and the disjoint global-read movement slice, does Binaryen v130 move state-reading candidate values across unrelated memory/table writes before a later `br_if` push point?

## Probes

Reduced local probes:

- `.tmp/cp-probes/load-candidate-across-table-set-before-brif.wat`
- `.tmp/cp-probes/table-get-candidate-across-memory-store-before-brif.wat`

Shapes:

```wat
(module
  (memory 1)
  (table 1 funcref)
  (func $f)
  (elem declare func $f)
  (func (param i32) (local i32)
    (block $exit
      i32.const 0
      i32.load
      local.set 1
      i32.const 0
      ref.func $f
      table.set 0
      local.get 0
      br_if $exit
      local.get 1
      drop)))
```

```wat
(module
  (memory 1)
  (table 1 funcref)
  (func $f)
  (elem declare func $f)
  (func (param i32) (local funcref)
    (block $exit
      i32.const 0
      table.get 0
      local.set 1
      i32.const 0
      i32.const 42
      i32.store
      local.get 0
      br_if $exit
      local.get 1
      drop)))
```

## Binaryen v130 result

Local `wasm-opt version 130 (version_130)` kept both candidate `local.set` roots before the unrelated write and later `br_if`:

- `i32.load` stayed before `table.set`;
- `table.get` stayed before `i32.store`.

These are Binaryen-stationary boundaries for the reduced default-trap-policy probes. They show that the disjoint-global direct-root exception from `0879` should not be generalized to arbitrary nonmatching memory/table state reads without source-backed proof.

## Starshine coverage

Added intentionally unsupported/Binaryen-stationary focused coverage in `src/passes/code_pushing_test.mbt`:

- `code-pushing boundary keeps load value before table.set and br_if push point`
- `code-pushing boundary keeps table.get value before memory.store and br_if push point`

No pass implementation changed. The existing movable-value gate already excludes these memory/table-reading candidate values, so Starshine preserved the Binaryen-stationary shape.

## Validation

```sh
wasm-tools parse .tmp/cp-probes/load-candidate-across-table-set-before-brif.wat -o .tmp/cp-probes/load-candidate-across-table-set-before-brif.wasm
wasm-tools validate --features all .tmp/cp-probes/load-candidate-across-table-set-before-brif.wasm
wasm-opt --all-features .tmp/cp-probes/load-candidate-across-table-set-before-brif.wat --code-pushing -S -o -
wasm-tools parse .tmp/cp-probes/table-get-candidate-across-memory-store-before-brif.wat -o .tmp/cp-probes/table-get-candidate-across-memory-store-before-brif.wasm
wasm-tools validate --features all .tmp/cp-probes/table-get-candidate-across-memory-store-before-brif.wasm
wasm-opt --all-features .tmp/cp-probes/table-get-candidate-across-memory-store-before-brif.wat --code-pushing -S -o -
moon test --target native src/passes/code_pushing_test.mbt --filter '*before table.set*'
moon test --target native src/passes/code_pushing_test.mbt --filter '*before memory.store*'
```

Results: both probes parsed/validated, Binaryen kept both candidate sets before the unrelated writes, and the focused Starshine filters passed `2/2` each. The filters also match the earlier matching-write boundary tests.

## Conclusion

`[O4Z-AUDIT-CP]` should keep memory/table state-reading candidate values stationary across unrelated writes under the reduced default-policy probes until a narrower Binaryen-positive source case exists. This characterization-only slice did not change pass behavior or GenValid profiles and does not refresh the post-`0879` final matrix requirement.
