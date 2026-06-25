---
kind: research
status: supported
created: 2026-06-25
sources:
  - ../../../binaryen/passes/code-pushing/segment-selection-and-barriers.md
  - ../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/passes/code_pushing_test.mbt
---

# Code Pushing `try_table` Before `br_if`

## Question

Does Binaryen v130 move a pure SFA `local.set` after a later `br_if` when the intervening root is a `try_table` with a catch target?

This continues the EH segment-order audit after the `throw_ref` positive movement in [`0855`](0855-2026-06-25-code-pushing-throw-ref-movement.md) and the plain `throw` stationary boundary in [`0857`](0857-2026-06-25-code-pushing-plain-throw-boundary.md).

## Binaryen probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe input: `.tmp/cp-probes/try-table-before-brif.wat`.

```wat
(module
  (func (local $x i32)
    (block $h
      (block $out
        (local.set $x (i32.const 1))
        (try_table (catch_all $h)
          (drop (i32.const 0)))
        (drop (i32.const 1))
        (br_if $out (i32.const 2))
        (drop (local.get $x))))))
```

Commands:

```sh
wasm-tools parse .tmp/cp-probes/try-table-before-brif.wat -o .tmp/cp-probes/try-table-before-brif.wasm
wasm-tools validate --features all .tmp/cp-probes/try-table-before-brif.wasm
wasm-opt --all-features .tmp/cp-probes/try-table-before-brif.wat --code-pushing -S -o -
```

Binaryen accepted and validated the probe, then kept `local.set $x (i32.const 1)` before the `try_table`. This is a narrow Binaryen-stationary EH boundary, not a movement family.

## Starshine change

The focused boundary test failed red because Starshine treated the `try_table` root as crossable in the pure-value single-set / later-`br_if` path and moved the set after the branch.

Starshine now treats `HotOp::Try` and `HotOp::TryTable` as hard segment-order barriers. This keeps the earlier `throw_ref` movement case intact and preserves the plain `throw`, `rethrow`, and call barriers.

## Tests

Updated focused coverage in `src/passes/code_pushing_test.mbt`:

- added `code-pushing boundary keeps SFA set before try_table and br_if push point`.

The test failed before implementation with `6 != 5` body roots because Starshine inserted a moved clone after `br_if`; after implementation it passed and kept the original set before `try_table`.

## Validation

- `wasm-tools parse .tmp/cp-probes/try-table-before-brif.wat -o .tmp/cp-probes/try-table-before-brif.wasm`: passed.
- `wasm-tools validate --features all .tmp/cp-probes/try-table-before-brif.wasm`: passed.
- `wasm-opt --all-features .tmp/cp-probes/try-table-before-brif.wat --code-pushing -S -o -`: passed; Binaryen kept the pure set before `try_table`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*try_table*'`: failed before implementation, then passed after the segment-order refinement.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*plain throw*'`: passed.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*throw_ref*'`: passed.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*code-pushing*'`: passed `82/82`.
- `moon fmt`: passed.
- `moon info`: passed with pre-existing warnings.
- `moon build --target native --release src/cmd`: passed with pre-existing warnings.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-all-try-table-1000-20260625 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures`: compared `1000/1000`, normalized `466`, cleanup-normalized `534`, raw mismatches `0`, validation/generator/property failures `0`, command failures `0`, Binaryen cache `1000 hits/0 misses`, and Binaryen failure cache `0 hits/0 misses`.
- `git diff --check`: passed.

## Reopening criteria

Reopen this boundary if future Binaryen source/lit probes move a caught `try_table` shape, if catch payload/reference variants behave differently, if legacy `try`/`catch` proves positive movement or needs a narrower boundary, or if generated direct-compare lanes expose EH-attributable mismatches. This slice covers only the reduced `try_table (catch_all ...)` before later `br_if` boundary.
