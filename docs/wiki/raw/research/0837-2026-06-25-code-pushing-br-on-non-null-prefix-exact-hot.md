# Code-pushing br_on_non_null prefix exact HOT follow-up

Date: 2026-06-25

## Scope

Follow-up for `[O4Z-AUDIT-CP]` after [`0836`](0836-2026-06-25-code-pushing-br-on-non-null-prefix-lowered-followup.md) showed that a hand-built lowered/generated-like HOT fixture passed but the targeted `code-pushing-br-on-non-null-prefix` GenValid leaf still mismatched every generated case.

## Exact HOT finding

A temporary local HOT dump of `.tmp/pass-fuzz-code-pushing-br-on-non-null-prefix-200-20260625/failures/case-000004-gen-valid/input.wasm` showed the real generated root shape was simpler than the previous approximation:

- the two user `local.set` roots were in the two-result block body before the branch;
- the `BrOnNonNull` itself was a region root, not only hidden under nested control;
- it had **two children**: an explicit i32 prefix payload and the nullable reference guard;
- the enclosing two-result block was referenced twice by top-level `drop` roots, so total local get/write accounting that revisits shared nodes over-counted the same block body.

## Focused test and implementation

Added red-first focused coverage in `src/passes/code_pushing_wbtest.mbt`:

```sh
moon test --target native src/passes/code_pushing_wbtest.mbt --filter '*exact generated br_on_non_null*'
# failed before implementation: expected exact generated prefix sets after br_on_non_null in source order; got branch=2, first=0, second=1
```

The fix was intentionally narrow:

- allow generated-prefix sinking across `BrOnNonNull` roots with one or more children instead of requiring exactly one child, because prefix-payload `br_on_non_null` has an explicit payload child plus the reference child;
- use unique-node whole-function local get/write accounting for this generated-prefix helper so duplicated/shared block references do not make a single local write look like multiple writes.

Focused evidence after implementation:

```sh
moon test --target native src/passes/code_pushing_wbtest.mbt --filter '*exact generated br_on_non_null*'
# passed 1/1

moon test --target native src/passes/code_pushing_wbtest.mbt --filter '*br_on_non_null*'
# passed 6/6
```

`moon fmt`, `moon info`, and `moon build --target native --release src/cmd` also passed with pre-existing warnings.

## Targeted profile status

The exact-HOT movement fix changes the representative mismatch family: the generated user-local prefix sets now sink after `br_on_non_null`, matching the Binaryen movement ordering. However, the targeted leaf is **not aggregate-safe yet**:

```sh
bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-br-on-non-null-prefix --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-br-on-non-null-prefix-exact-20-20260625 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 10 --keep-going-after-command-failures
# compared 20/20; normalized 0; cleanup-normalized 0; raw mismatches 20; no validation/generator/property/command failures

bun scripts/pass-fuzz-compare.ts --count 200 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-br-on-non-null-prefix --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-br-on-non-null-prefix-exact-200-20260625 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
# compared 65/200 before the mismatch cap; normalized 0; cleanup-normalized 0; raw mismatches 65; no validation/generator/property/command failures
```

Representative post-fix mismatch: `.tmp/pass-fuzz-code-pushing-br-on-non-null-prefix-exact-20-20260625/failures/case-000001-gen-valid`. The 200-case refresh confirms this is not just a small-sample artifact: all compared selected cases still raw-mismatch after the exact-HOT movement fix.

Agent classification: the original generated prefix movement gap is narrowed, but the lane remains blocked by a lowerer/local-cleanup output-shape gap around the explicit prefix payload value. Binaryen emits the post-branch payload drop as `drop (local.get $3)` after the moved user locals. Starshine sinks the user locals, but lowering materializes the prefix drop through an extra temporary local (`local.set $5 (local.get $3)` then `drop (local.get $5)`). This is not yet measured as a Starshine win and should remain a parity/normalization blocker.

## Next work

Keep `code-pushing-br-on-non-null-prefix` out of `code-pushing-all`. Next work should either:

1. add a red focused lowerer/canonicalization test for the exact prefix-payload post-branch drop temp (`local.set tmp (local.get prefix); drop tmp` vs Binaryen's direct `drop (local.get prefix)`) and fix or normalize it narrowly; or
2. if that is judged outside `code-pushing`, document explicit source-backed acceptance criteria and reopening conditions before aggregating the leaf.
