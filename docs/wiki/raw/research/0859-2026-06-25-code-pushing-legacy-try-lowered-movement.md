# 0859 - code-pushing legacy try-lowered movement

Date: 2026-06-25

## Question

Does Binaryen v130 keep a pure SFA `local.set` before a legacy `try`/`catch` root, or can the set move after a later `br_if` push point like ordinary non-reading roots?

## Probe

Reduced local probe:

```wat
(module
  (tag $e)
  (func (param $p i32) (local $x i32)
    (block $exit
      i32.const 7
      local.set $x
      try
        i32.const 0
        drop
      catch $e
        i32.const 1
        drop
      end
      local.get $p
      br_if $exit
      local.get $x
      drop)))
```

Commands:

- `wasm-tools parse .tmp/cp-probes/legacy-try-before-brif.wat -o .tmp/cp-probes/legacy-try-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/legacy-try-before-brif.wasm` — passed.
- `wasm-opt --all-features .tmp/cp-probes/legacy-try-before-brif.wat --code-pushing -S -o -` — passed with local `wasm-opt version 130 (version_130)`.

## Binaryen result

Binaryen moved the pure `local.set $x (i32.const 7)` after the legacy `try`/`catch` root and after the later `br_if $exit (local.get $p)`. This contrasts with the stationary `try_table` catch-target boundary recorded in `0858`.

## Starshine coverage

Added focused coverage in `src/passes/code_pushing_test.mbt`:

- `code-pushing moves pure SFA set after legacy try-lowered block before later br_if`

The local WAT fixture currently lowers this legacy `try`/`catch` to a HOT `Block` rather than exposing a native `HotOp::Try` root in the tested parent region. The test therefore guards the observable Binaryen-positive movement through the current frontend/lifter path, but it does **not** prove native `HotOp::Try` segment-barrier behavior. Keep the broader EH note open for native HOT `Try`, rethrow, and richer try/catch forms.

No pass implementation change was needed in this slice.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*legacy try-lowered*'` — passed `1/1` with pre-existing unused-function warnings.

## Impact

This narrows the EH audit by splitting legacy `try`/`catch` observable movement from `try_table` stationary behavior. Final closeout still needs post-`0858` matrix refreshes because the last actual behavior change remains `0858`; this `0859` slice only adds probe-backed characterization coverage and documentation.
