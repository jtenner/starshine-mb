# Remove-unused-brs try_table catch JumpThreader slice

Date: 2026-06-29

## Scope

Recursive RUB complete-family slice under `[O4Z-AUDIT-RUB-Q]`.

This slice audited the remaining catch-target side of Binaryen `JumpThreader` for locally representable `try_table` shapes. It implemented the source-backed no-payload child-block-to-following-simple-jump subset, added an explicit `catch_ref` sent-value boundary, and left the one-child catch-target shell as an open local JumpThreader gap rather than silently closing catch parity. Update: that one-child shell gap was closed later on 2026-06-29 in research note `1365`.

## Source evidence

The relevant Binaryen `version_130` model is the same JumpThreader source audited in the payload slice:

- `JumpThreader::visitExpression(...)` records only scope-name uses whose sent type is `Type::none`.
- `BranchUtils::operateOnScopeNameUsesAndSentTypes(...)` includes `TryTable` catch destinations in the scope-use walk.
- `JumpThreader::redirectBranches(...)` uses `BranchUtils::replacePossibleTarget(...)`, so no-payload `try_table` catch destinations can be retargeted alongside no-payload branches and tables.

This means no-payload `catch` / `catch_all` targets are source-backed JumpThreader candidates, while `catch_ref`, `catch_all_ref`, and payload-carrying tag catches remain excluded by the same sent-type filter that excludes payload `br`, `br_if`, and `br_table` uses.

## Binaryen probes

Local probes were written under `.tmp/rub-catch-*.wat` and run with `wasm-opt --all-features --remove-unused-brs -S ... -o -`:

- `.tmp/rub-catch-target-shell.wat`: no-payload `catch_all $inner` through a one-child `$outer/$inner` shell retargeted to `$outer` in Binaryen.
- `.tmp/rub-catch-tag-shell.wat`: no-payload exact `catch $e $inner` through the same one-child shell retargeted to `$outer` in Binaryen.
- `.tmp/rub-catch-target-child-to-jump.wat`: no-payload `catch_all $inner` inside a child block followed by `br $exit` retargeted to `$exit` in Binaryen.
- `.tmp/rub-catch-ref-boundary.wat`: `catch_ref $e $inner` kept `$inner` in Binaryen.
- `.tmp/rub-catch-payload-boundary.wat`: payload tag `catch $e $inner` for `(tag $e (param i32))` kept `$inner` in Binaryen.

The implemented Starshine positive uses the child-block-to-following-simple-jump shape with a no-payload exact `catch`; the `catch_ref` boundary covers the sent-value exclusion.

## Test and implementation changes

Added focused coverage in `src/passes/remove_unused_brs_test.mbt`:

- `remove-unused-brs retargets no-payload try_table catch targets to a following simple jump`
- `remove-unused-brs boundary keeps catch_ref jump-threading conservative`

A red-first one-child-shell catch-target test was also tried locally and failed: Starshine kept the inner catch target while Binaryen retargeted it. That failing test was not kept because it marks a remaining parity gap, not an accepted boundary.

Implementation changes in `src/passes/remove_unused_brs.mbt`:

- `remove_unused_brs_try_table_references_label(...)` admits `TryTable` nodes into the retargetable-label scan.
- `remove_unused_brs_retarget_retargetable_branches(...)` now rewrites `HotCatchArm` target labels via `hot_try_table_catches_set(...)` when the already-existing source/destination label arity guard proves a no-payload retarget.
- The retarget helper now returns the actual changed-node count instead of assuming all collected nodes were direct branches.
- The child-to-following-simple-jump path now reaches no-payload `try_table` catch targets.

At the end of this slice, the one-child-shell catch target case still did not fire locally. That was an open JumpThreader parity gap at this point; it was closed later in research note `1365`.

## Validation

Commands run from `/data/workspaces/229/starshine-sidework`:

- Red-first focused run before implementation: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` failed the two new catch-target positives, passing `184/186`.
- Focused pass test after implementation and after narrowing the kept positive to the implemented child-to-jump subset: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed `185/185`.
- Package validation: `moon fmt && moon info && moon test src/passes` passed; `moon info` reported 6 pre-existing warnings; `moon test src/passes` passed `3591/3591`.
- Native build and refreshed direct compare smoke after the behavior change: `moon build --target native --release src/cmd && bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass remove-unused-brs --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-catch-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` passed. The compare artifact reports requested `1000`, compared `1000`, `normalizedMatchCount=142`, `cleanupNormalizedMatchCount=858`, `mismatchCount=0`, `validationFailureCount=0`, `generatorFailureCount=0`, `commandFailureCount=0`, and Binaryen cache `1000` hits / `0` misses. Native build emitted 27 pre-existing pass-manager unused-function warnings.

Pass-local timing was not available from this compare smoke.

## Still open after this slice

This narrowed the catch-target JumpThreader item but did not close it at the time. Later research note `1365` closed the one-child-shell `try_table` catch-target retargeting gap. Remaining boundaries after that follow-up are:

- old-`try` / HOT `Try` catch-body representation remains blocked in the public WAT path
- `catch_ref`, `catch_all_ref`, and payload tag catches remain sent-value boundaries under the audited Binaryen source
- large mostly-default `br_table` JumpThreader beyond the `<= 8` guard remains blocked by switch-lowering interactions

The follow-up RUB-Q slice finished the one-child `try_table` catch-target shell with a narrower raw-gate and HOT scheduling fix. Subsequent slices should move to the next source-backed non-JumpThreader family such as broader GC `br_on_*`, result-typed `sinkBlocks`, adjacent-branch/final-optimizer, or payload/value `tablify` / `visitSwitch` coverage.
