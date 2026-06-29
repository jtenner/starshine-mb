# Remove-unused-brs try_table catch shell JumpThreader slice

Date: 2026-06-29

## Scope

Recursive RUB complete-family slice under `[O4Z-AUDIT-RUB-Q]`.

This slice closed the remaining no-payload `try_table` catch-target one-child-shell JumpThreader gap left by research note `1364`. Binaryen had already been probed to retarget no-payload `catch` / `catch_all` targets from an inner one-child block shell to the outer block. Starshine previously kept the inner catch target because the raw candidate gate skipped a function whose only RUB opportunity was a `try_table` catch destination and the surrounding shell did not contain `br`, `br_if`, `br_table`, `throw`, or other existing raw candidates.

## Red-first evidence

A focused positive test was added before the implementation:

- `remove-unused-brs retargets no-payload try_table catch targets through one-child named block shells`

Initial focused run:

- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` failed `185/186`; the new test kept catch target label `1` (`$inner`) instead of retargeting to label `0` (`$outer`).

A temporary trace confirmed the reason: the pass reported `skip-raw reason=no-remove-unused-brs-candidates` for the tested function. That made this a narrow raw-admission plus HOT retarget scheduling gap, not a failure of Binaryen source evidence.

## Implementation

Changed files:

- `src/passes/pass_manager.mbt`
  - Added `run_hot_pipeline_raw_remove_unused_brs_has_try_table_catch(...)`.
  - Added `run_hot_pipeline_raw_remove_unused_brs_has_try_table_catch_shell(...)`.
  - The final raw candidate gate now admits only a narrow one-child block-shell shape whose inner body contains a `try_table` with catch arms. The raw layer does not rewrite anything and does not decide payload legality.
- `src/passes/remove_unused_brs.mbt`
  - Added `remove_unused_brs_try_thread_try_table_catches_through_one_child_block(...)`.
  - The helper runs from block roots, requires a void one-child block shell, requires zero branch arity on both source and destination labels, and retargets only `TryTable` catch labels in the current shell subtree.
  - Existing `catch_ref`, `catch_all_ref`, and payload-tag boundaries remain protected by nonzero branch arity / sent-value behavior and existing focused boundary tests.
- `src/passes/remove_unused_brs_test.mbt`
  - Kept the new one-child-shell positive alongside the child-to-following-simple-jump positive and `catch_ref` boundary.

## Validation

Commands run from `/data/workspaces/229/starshine-sidework`:

- Red-first focused run before implementation: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` failed `185/186` with the new one-child-shell catch-target positive keeping `$inner`.
- Focused run after raw-gate and HOT retarget implementation: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed `186/186`.
- Formatting/info/package validation: `moon fmt` passed; `moon info` passed with 6 pre-existing warnings; `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt && moon test src/passes` passed (`186/186`, then `3592/3592`).
- Native build: `moon build --target native --release src/cmd` passed with 27 pre-existing pass-manager unused-function warnings.
- Refreshed direct compare smoke: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass remove-unused-brs --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-catch-shell-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` passed: requested `1000`, compared `1000`, `normalizedMatchCount=142`, `cleanupNormalizedMatchCount=858`, `mismatchCount=0`, `validationFailureCount=0`, `generatorFailureCount=0`, `commandFailureCount=0`, Binaryen cache `1000` hits / `0` misses, wasm-smith cache `0` hits / `0` misses.

Pass-local timing was not available from this compare smoke.

## Status after this slice

The locally representable no-payload `try_table` catch-target JumpThreader subset now covers both audited Binaryen shell shapes:

- one-child named block shell: `catch $e $inner` / `catch_all $inner` retargets to the outer shell label when both labels have zero branch arity
- child block followed by a simple jump: catch target retargets to the following jump destination

Still open under `[O4Z-AUDIT-RUB-Q]`:

- old-`try` / HOT `Try` catch-region body traversal if a binary-decoder path can expose it
- large mostly-default `br_table` JumpThreader beyond the local `<= 8` guard
- broader GC `br_on_*` payload/prefix/nullable-cast/descriptor/fallthrough/localize/unreachable forms
- result-typed `sinkBlocks`
- adjacent `br_if` + unconditional `br` cleanup and payload/value adjacent merges
- payload/value `tablify` ladders and child-less stack-payload switches
- broader select/restructure/set-if value legality
- raw-gate/performance accountability and final generator/signoff freshness
