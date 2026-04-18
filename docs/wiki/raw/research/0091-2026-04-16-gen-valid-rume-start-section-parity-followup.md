# 0091 - Gen-valid RUME no-op start-section parity follow-up

## Status

- Completed 2026-04-16 under `[FUZ]003B`.
- Exposed by the same focused rerun that closed the imported-function family from [`0090`](./0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md).
- The pre-fix focused rerun `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator gen-valid --count 20 --max-failures 5 --out-dir .tmp/pass-fuzz-fuz003a-genvalid-smoke` reached `20/20` compared cases with `18` normalized matches, `2` mismatches, `0` validation failures, `0` generator failures, and `0` command failures.
- The post-fix focused rerun `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator gen-valid --count 20 --max-failures 5 --out-dir .tmp/pass-fuzz-fuz003b-genvalid-smoke` is now `20/20` compared cases with `20` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `0` command failures.

## Scope

- Capture the next distinct `gen-valid`-seeded `remove-unused-module-elements` parity family revealed after the imported-function fix landed.
- Keep this follow-up separate from the already-closed imported-function/type-compaction work so the next slice did not reopen solved behavior.
- Record the exact saved repros, the reduced positive and negative boundaries, and the final kept Binaryen-matching rule for this no-op `start`-section family.

## Trigger

After landing the imported-function fix from [`0090`](./0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md), the follow-up smoke rerun was:

- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator gen-valid --count 20 --max-failures 5 --out-dir .tmp/pass-fuzz-fuz003a-genvalid-smoke`

Observed result:

- `comparedCount=20`
- `normalizedMatchCount=18`
- `mismatchCount=2`
- `validationFailureCount=0`
- `generatorFailureCount=0`
- `commandFailureCount=0`

That leaves a small semantic parity family, not a generator-invalidity or harness-failure problem.

## Exact saved cases

Saved repro folders:

- `.tmp/pass-fuzz-fuz003a-genvalid-smoke/failures/case-000002-gen-valid/`
- `.tmp/pass-fuzz-fuz003a-genvalid-smoke/failures/case-000020-gen-valid/`

Files of interest for each case:

- `input.print.wat`
- `binaryen.wat`
- `starshine.wat`
- `failure.txt`

## Shared observed shape

Both saved cases have the same normalized-diff pattern after `RUME` runs:

- the imported-function family from [`0090`](./0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md) is already fixed, so the unused import is removed correctly
- one defined nullary function survives as the live `main` export and elem target
- that same surviving function is also the `start` target in the input
- Binaryen keeps the function, exports, table, memory, global, tag, elem, and data sections
- Starshine keeps the same surviving function and sections
- the only visible normalized difference is that Binaryen drops the `start` section while Starshine still preserves it

In other words, the follow-up is not another survivor-index remap bug. It is specifically a `start`-section retention difference.

## Saved case summaries

### Case `000002`

Input highlights:

- imported function `0`
- live exported/start/elem function `1`
- surviving start target body:

```wat
(func (;1;) (type 0)
  nop
)
```

Binaryen normalized output omits the `start` section entirely:

```wat
(module
 (type $0 (func))
 ...
 (export "main" (func $0))
 ...
 (func $0 (type $0)
  (nop)
 )
)
```

Starshine preserves the same function but keeps:

```wat
(start $0)
```

### Case `000020`

Input highlights:

- imported function `0`
- live exported/start/elem function `1`
- surviving start target body:

```wat
(func (;1;) (type 0)
  (local i64 i32 f64)
  nop
)
```

Binaryen again omits the `start` section entirely while preserving the same function and surrounding live module surface.

Starshine again keeps:

```wat
(start $0)
```

## Resolved rule

The reduced boundary work for `[FUZ]003B` now supports this narrower exact rule for the family seen in the saved repros:

- Binaryen drops `start` during `remove-unused-module-elements` when `start` targets a **defined** nullary function whose body is exactly a single `nop`.
- Local declarations do not matter for this exact family: the saved `case-000020-gen-valid` still drops `start` even though the function keeps locals.
- If that single-`nop` function is otherwise live through exports or elem segments, Binaryen keeps the function and only drops `start`.
- If that single-`nop` function is rooted only by `start`, Binaryen drops both `start` and the now-unreachable function.
- The nearby negative boundary is important: an **empty-body** start function is *not* dropped by Binaryen, so the rule is narrower than “any observably empty start”.

This is still intentionally conservative. The checked-in Starshine fix matches only that proved exact boundary instead of generalizing to broader “side-effect-free start” deletion.

## Outcome

The landed Starshine change now mirrors the proved rule by:

- detecting defined `start` targets whose body is exactly one `nop`
- skipping `start`-rooted liveness for that exact family
- omitting `start_sec` from the rewritten module for that exact family
- keeping the otherwise-live exported/elem-linked function body untouched when other roots keep it alive
- preserving the nearby empty-body negative boundary unchanged

## Landed implementation focus

The landed change in [`src/passes/remove_unused_module_elements.mbt`](../../../../src/passes/remove_unused_module_elements.mbt) touches the two expected control points:

- `rume_collect_liveness_with_import_parent_policy(...)` now skips marking the start target live for the exact defined-single-`nop` family.
- `rume_apply_module_rewrite(...)` now omits `start_sec` for that same exact family and avoids the old early-return fast path when dropping `start` is the only required rewrite.

Focused regressions now live in [`src/passes/remove_unused_module_elements_test.mbt`](../../../../src/passes/remove_unused_module_elements_test.mbt) for:

1. exported/elem-linked single-`nop` start targets
2. the same family with locals still present
3. the empty-body negative boundary
4. a start-only single-`nop` function that should disappear entirely once `start` no longer roots it

## Why this is a fuzz slice, not only a pass slice

This issue was only surfaced because the widened `coverage-forced` `gen-valid` batch now emits start-sensitive module topologies with live exports, elem segments, and removable imports in the same small corpus. The fuzz backlog therefore needs an explicit handoff entry for the follow-up even though the eventual code fix will likely land inside the `RUME` pass.