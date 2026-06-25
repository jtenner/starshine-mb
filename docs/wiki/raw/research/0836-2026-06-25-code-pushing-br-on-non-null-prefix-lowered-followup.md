# Code-pushing br_on_non_null prefix lowered follow-up

Date: 2026-06-25

## Scope

Follow-up for `[O4Z-AUDIT-CP]` after the targeted `code-pushing-br-on-non-null-prefix` GenValid leaf exposed a generated/lowered prefix-payload mismatch. The intent was to cover the lowered HOT shape where the multivalue `br_on_non_null` prefix is wrapped in nested expression/control nodes, not just the direct block-root HOT fixture from notes `0834` and `0835`.

## Replay input

Representative mismatch replay remains:

```sh
.tmp/pass-fuzz-code-pushing-br-on-non-null-prefix-200-20260625/failures/case-000004-gen-valid
```

The input has two adjacent pure i32 `local.set` roots before a two-result block-label `br_on_non_null` carrying explicit i32 prefix payload plus implicit externref payload. Binaryen v130 sinks the two user locals after its rewritten `br_on_non_null`; Starshine leaves the WAT-lowered generated locals before the branch.

## Focused implementation attempt

Added a focused HOT regression in `src/passes/code_pushing_wbtest.mbt` for a lowered/generated-like expression-nested block whose inner block body contains:

- user locals `1` and `2` set from pure constants,
- scratch local setup feeding `br_on_non_null`,
- direct `br_on_non_null`,
- suffix reads/drops of locals `1` and `2`.

The first run failed red-first with the user locals before the branch:

```sh
moon test --target native src/passes/code_pushing_wbtest.mbt --filter '*lowered generated br_on_non_null*'
# failed: expected generated prefix sets after br_on_non_null in source order; got branch=5, first=0, second=1
```

Starshine then added a narrow generated-prefix movement helper plus recursive scanning for control regions under expression children. The focused HOT regression now passes:

```sh
moon test --target native src/passes/code_pushing_wbtest.mbt --filter '*lowered generated br_on_non_null*'
# passed 1/1
```

The existing focused prefix group also remains green:

```sh
moon test --target native src/passes/code_pushing_wbtest.mbt --filter '*br_on_non_null*'
# passed 5/5
```

## Targeted generated compare remains blocked

The focused HOT shape did **not** clear the real generated profile lane. After `moon info` and a native rebuild, both targeted reruns still mismatched every selected generated case:

```sh
bun scripts/pass-fuzz-compare.ts --count 200 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-br-on-non-null-prefix --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-br-on-non-null-prefix-fix-200-20260625 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
# compared 65/200 before mismatch cap; raw mismatches 65; no failures

bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-br-on-non-null-prefix --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-br-on-non-null-prefix-fix2-20-20260625 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 10 --keep-going-after-command-failures
# compared 20/20; raw mismatches 20; no failures
```

Agent classification: still a generated lowering/HOT-representation blocker. The new focused nested-HOT movement is forward coverage, but the targeted GenValid shape likely differs in a lower-level representation detail not captured by this hand-built fixture. Keep `code-pushing-br-on-non-null-prefix` out of `code-pushing-all`.

## Reopening criteria / next work

Replay the real generated case from the failure directory and inspect the actual HOT before `code-pushing`, rather than approximating from normalized WAT. The next implementation should add a focused test built from that exact HOT shape or add a debug dump path that exposes the block/region owner missed by the current recursive scan.
