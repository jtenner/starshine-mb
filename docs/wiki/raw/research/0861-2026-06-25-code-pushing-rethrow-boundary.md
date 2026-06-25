# 0861 - code-pushing rethrow boundary

Date: 2026-06-25

## Question

Does the legacy EH `rethrow` shape behave like the Binaryen-stationary tag-based `throw` / `try_table` boundaries, or like the Binaryen-positive non-fallthrough `throw_ref` movement case?

## Probe

Reduced local Binaryen probe:

```wat
(module
  (tag $e)
  (func (param $p i32) (local $x i32)
    (block $exit
      i32.const 7
      local.set $x
      try
        throw $e
      catch $e
        rethrow 0
      end
      local.get $p
      br_if $exit
      local.get $x
      drop)))
```

Commands:

- `wasm-tools parse .tmp/cp-probes/rethrow-before-brif.wat -o .tmp/cp-probes/rethrow-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/rethrow-before-brif.wasm` — passed.
- `wasm-opt --version` — reported `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features .tmp/cp-probes/rethrow-before-brif.wat --code-pushing -S -o -` — passed.

## Binaryen result

Binaryen kept the pure `local.set $x (i32.const 7)` before the legacy `try`/`catch` root that can `rethrow`, then left the later `br_if` and suffix read unchanged. This is a stationary EH boundary, unlike the narrow non-fallthrough `throw_ref` positive movement case and unlike the no-rethrow legacy `try`/`catch` probe in `0859`.

## Starshine coverage and implementation

Added focused boundary coverage in `src/passes/code_pushing_test.mbt`:

- `code-pushing boundary keeps SFA set before rethrowing legacy try and br_if push point`

The WAT lifter currently lowers legacy `rethrow` to `unreachable`, so the focused Starshine fixture uses direct HOT construction to keep a nested `HotOp::Rethrow` visible. The implementation now treats a crossed HOT subtree / region containing `Rethrow` as unsafe for segment movement, preserving the set before the rethrow-containing block. This is intentionally narrow and does not change the `0859` no-rethrow legacy try-lowered movement case.

## Validation

- Red-first `moon test --target native src/passes/code_pushing_test.mbt --filter '*rethrowing legacy try*'` failed before implementation because Starshine moved the set after the later `br_if` (`5 != 4` root-count mismatch).
- After implementation, `moon test --target native src/passes/code_pushing_test.mbt --filter '*rethrowing legacy try*'` passed `1/1`.
- Full focused `moon test --target native src/passes/code_pushing_test.mbt --filter '*code-pushing*'` passed `85/85`.
- `moon fmt`, `moon info`, `moon build --target native --release src/cmd`, and `git diff --check` passed with pre-existing warnings where noted.
- Bounded post-change aggregate smoke `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-all-rethrow-1000-20260625 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` compared `1000/1000`, normalized `466`, cleanup-normalized `534`, raw mismatches/failures `0`, validation/generator/property/command failures `0`, Binaryen cache `1000 hits/0 misses`, Binaryen failure cache `0 hits/0 misses`.

## Impact

The EH split is narrower and closer to Binaryen v130: `throw_ref` remains crossable for the reduced pure-value/later-`br_if` movement, no-payload and payload-bearing tag `throw` remain stationary, reduced `try_table` remains stationary, no-rethrow legacy try-lowered movement remains covered, and rethrow-containing HOT regions are now stationary. Broader native HOT `Try`, richer `try_table`, caught payload/reference forms, and other EH forms remain open.
