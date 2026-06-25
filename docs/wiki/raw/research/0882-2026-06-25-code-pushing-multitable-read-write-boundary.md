# 0882 - code-pushing multitable read/write boundary

Date: 2026-06-25

## Question

`0880` showed reduced memory/table-reading candidates remain stationary before unrelated memory/table writes. Check one index-refined alias case that local WAT/HOT can represent: `table.get $t0` before `table.set $t1` where `$t0 != $t1`.

## Probe

Probe file:

- `.tmp/cp-probes/table-get-across-other-table-set-before-brif.wat`

Commands:

```sh
wasm-tools parse .tmp/cp-probes/table-get-across-other-table-set-before-brif.wat -o .tmp/cp-probes/table-get-across-other-table-set-before-brif.wasm
wasm-tools validate --features all .tmp/cp-probes/table-get-across-other-table-set-before-brif.wasm
wasm-opt --all-features .tmp/cp-probes/table-get-across-other-table-set-before-brif.wat --code-pushing -S -o -
```

## Finding

Local `wasm-opt version 130 (version_130)` validates the probe and keeps the table-reading candidate before the write to the other table:

```wat
(local.set $1
 (table.get $t0
  (i32.const 0)))
(table.set $t1
 (i32.const 0)
 (ref.func $f))
(br_if $exit
 (local.get $0))
```

This is a Binaryen-stationary boundary in the reduced probe. It does not prove all multitable read/write aliasing must remain stationary forever, but it prevents treating the disjoint-global exception as a template for table reads.

## Starshine coverage

Added focused boundary test:

- `code-pushing boundary keeps table.get value before other table.set and br_if push point`

The test is intentionally unsupported/Binaryen-stationary. It passed with the current movable-value gates; no implementation or GenValid profile changed.

The fixture places the tested function before helper `$f` so `code_pushing_test_run_hot(...)` / `pass_test_lift_first_func(...)` optimize the intended function, matching the fixture-order lesson from `0880`.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*other table.set*'` passed `1/1`.

## Follow-up

Final `[O4Z-AUDIT-CP]` closeout still needs the post-`0881` four-lane matrix because `0881` changed behavior. Multiple memories, table.init/table.copy index-refinements, and broader state-read/write windows remain open unless future reduced probes and HOT fixtures justify movement or narrow stationary acceptance.
