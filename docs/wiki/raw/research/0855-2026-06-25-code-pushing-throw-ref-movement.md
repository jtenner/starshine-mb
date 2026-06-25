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

# Code Pushing `throw_ref` Before `br_if`

## Question

Does Binaryen v130 keep a pure SFA `local.set` before an intervening `throw_ref` root when the same block has a later `br_if` push point?

This slice refines the ordered-window / EH surface after the earlier call-barrier fix. Calls remain an ordered segment barrier, but a `throw_ref` root cannot fall through to the later push point.

## Binaryen probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe input: `.tmp/cp-probes/throwref-before-brif.wat`.

```wat
(module
  (func (local $x i32)
    (block $out
      (local.set $x (i32.const 1))
      (throw_ref (ref.null exn))
      (drop (i32.const 1))
      (br_if $out (i32.const 2))
      (drop (local.get $x)))))
```

Commands:

```sh
wasm-tools parse .tmp/cp-probes/throwref-before-brif.wat -o .tmp/cp-probes/throwref-before-brif.wasm
wasm-tools validate --features all .tmp/cp-probes/throwref-before-brif.wasm
wasm-opt --version
wasm-opt --all-features .tmp/cp-probes/throwref-before-brif.wat --code-pushing -S -o -
```

Binaryen accepted and validated the probe, then moved `local.set $x (i32.const 1)` after the later `br_if`. The optimized text kept the `throw_ref` before the branch and inserted the set after the branch, so this is a Binaryen-positive movement family rather than a stationary EH boundary.

## Starshine change

This was a focused parity fix. The first Starshine test failed red because the call-barrier-era segment-order check treated `EFFECT_MASK_THROW` like calls and kept the set before `throw_ref`.

Starshine now keeps calls as hard segment-order barriers for this single-set movement path but does not treat `throw_ref` itself as a hard barrier. Existing value-specific checks still protect broader effectful values: heap-read movement, for example, remains subject to `code_pushing_node_safe_to_cross_for_value(...)` and its throw/effect checks. The widened behavior is therefore the narrow pure-value `throw_ref` / later-`br_if` movement observed in the Binaryen probe.

## Tests

Updated focused coverage in `src/passes/code_pushing_test.mbt`:

- added `code-pushing moves pure SFA set after throw_ref before later br_if push point`.

The test failed before implementation with `5 != 6` body roots because Starshine left the original set before `throw_ref`; after implementation it passed and found the cloned `local.set` after the `br_if`.

## Validation

- `wasm-tools parse .tmp/cp-probes/throwref-before-brif.wat -o .tmp/cp-probes/throwref-before-brif.wasm`: passed.
- `wasm-tools validate --features all .tmp/cp-probes/throwref-before-brif.wasm`: passed.
- `wasm-opt --version`: `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features .tmp/cp-probes/throwref-before-brif.wat --code-pushing -S -o -`: passed; Binaryen moved the pure set after the later `br_if`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*throw_ref*'`: failed before implementation, then passed after the segment-order refinement.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*call barrier*'`: passed, preserving the source-backed call boundary.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*code-pushing*'`: passed `80/80`.
- `moon fmt`: passed.
- `moon info`: passed with pre-existing warnings.
- `moon build --target native --release src/cmd`: passed with pre-existing warnings.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-all-throw-ref-1000-20260625 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures`: compared `1000/1000`, normalized `466`, cleanup-normalized `534`, raw mismatches `0`, validation/generator/property failures `0`, command failures `0`, Binaryen cache `1000 hits/0 misses`, and Binaryen failure cache `0 hits/0 misses`.

No GenValid leaf was added because this slice covers a narrow EH/control-root refinement around an existing `br_if` movement family rather than a new aggregate-safe generator family.

## Reopening criteria

Reopen this slice if a future Binaryen source/lit refresh keeps `throw_ref` windows stationary, if broader EH forms such as `throw`, `rethrow`, `try_table`, or legacy `try` exhibit different behavior, or if generated direct-compare lanes expose EH-attributable mismatches. Calls remain a separate stationary boundary under [`0850`](0850-2026-06-25-code-pushing-call-barrier.md).
