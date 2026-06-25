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

# Code Pushing Plain `throw` Before `br_if`

## Question

Does Binaryen v130 move a pure SFA `local.set` after a later `br_if` when the intervening root is a tag-based `throw` rather than `throw_ref`?

This slice refines the EH split from [`0855`](0855-2026-06-25-code-pushing-throw-ref-movement.md). `throw_ref` is Binaryen-positive in the reduced pure-value/later-`br_if` shape, but tag-based `throw` is not.

## Binaryen probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe input: `.tmp/cp-probes/throw-before-brif.wat`.

```wat
(module
  (tag $e)
  (func (local $x i32)
    (block $out
      (local.set $x (i32.const 1))
      (throw $e)
      (drop (i32.const 1))
      (br_if $out (i32.const 2))
      (drop (local.get $x)))))
```

Commands:

```sh
wasm-tools parse .tmp/cp-probes/throw-before-brif.wat -o .tmp/cp-probes/throw-before-brif.wasm
wasm-tools validate --features all .tmp/cp-probes/throw-before-brif.wasm
wasm-opt --all-features .tmp/cp-probes/throw-before-brif.wat --code-pushing -S -o -
```

Binaryen accepted and validated the probe, then kept `local.set $x (i32.const 1)` before `throw $e`. This is a narrow Binaryen-stationary EH boundary, not a movement family.

## Starshine change

The boundary test failed red after the prior `throw_ref` refinement because Starshine treated all non-call throwing roots as crossable for this pure-value single-set path and moved the set after the later `br_if`.

Starshine now treats `HotOp::Throw` and `HotOp::Rethrow` as hard segment-order barriers while still allowing the source-backed `HotOp::ThrowRef` movement from [`0855`](0855-2026-06-25-code-pushing-throw-ref-movement.md). Calls remain hard barriers as before.

## Tests

Updated focused coverage in `src/passes/code_pushing_test.mbt`:

- added `code-pushing boundary keeps SFA set before plain throw and br_if push point`.

The test failed before implementation with `6 != 5` body roots because Starshine inserted a moved clone after `br_if`; after implementation it passed and kept the original set before `throw`.

## Validation

- `wasm-tools parse .tmp/cp-probes/throw-before-brif.wat -o .tmp/cp-probes/throw-before-brif.wasm`: passed.
- `wasm-tools validate --features all .tmp/cp-probes/throw-before-brif.wasm`: passed.
- `wasm-opt --version`: `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features .tmp/cp-probes/throw-before-brif.wat --code-pushing -S -o -`: passed; Binaryen kept the pure set before `throw`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*plain throw*'`: failed before implementation, then passed after the segment-order refinement.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*throw_ref*'`: passed, preserving the source-backed positive `throw_ref` movement.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*call barrier*'`: passed, preserving the source-backed call barrier.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*code-pushing*'`: passed `81/81`.
- `moon fmt`: passed.
- `moon info`: passed with pre-existing warnings.
- `moon build --target native --release src/cmd`: passed with pre-existing warnings.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-all-plain-throw-1000-20260625 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures`: compared `1000/1000`, normalized `466`, cleanup-normalized `534`, raw mismatches `0`, validation/generator/property failures `0`, command failures `0`, Binaryen cache `1000 hits/0 misses`, and Binaryen failure cache `0 hits/0 misses`.
- `git diff --check`: passed.

## Reopening criteria

Reopen this boundary if a future Binaryen source/lit refresh moves the tag-based `throw` shape, if a tag with payloads or a caught `try_table`/legacy `try` shape behaves differently, if `rethrow` probes show a positive movement family, or if generated direct-compare lanes expose EH-attributable mismatches. This slice covers only the reduced plain `throw` before later `br_if` boundary.
