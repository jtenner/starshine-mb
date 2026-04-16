# 0091 - Gen-valid RUME no-op start-section parity follow-up

## Status

- Active downstream follow-up as of 2026-04-16.
- Exposed by the same focused rerun that closed the imported-function family from [`0090`](./0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md).
- The focused rerun `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator gen-valid --count 20 --max-failures 5 --out-dir .tmp/pass-fuzz-fuz003a-genvalid-smoke` reached `20/20` compared cases with `18` normalized matches, `2` mismatches, `0` validation failures, `0` generator failures, and `0` command failures.
- The remaining mismatches are `.tmp/pass-fuzz-fuz003a-genvalid-smoke/failures/case-000002-gen-valid/` and `case-000020-gen-valid/`.

## Scope

- Capture the next distinct `gen-valid`-seeded `remove-unused-module-elements` parity family revealed after the imported-function fix landed.
- Keep this follow-up separate from the already-closed imported-function/type-compaction work so the next slice does not reopen solved behavior.
- Document the exact saved repros and the still-open uncertainty about Binaryen's precise no-op `start`-section pruning rule.

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

## Current best reading of the family

Observed Binaryen behavior in both saved cases is consistent with this narrower statement:

- when the surviving `start` target is also otherwise live and normalizes to a nullary no-op function with no observable work, Binaryen drops the `start` section during `RUME`

However, that should still be treated as an informed hypothesis, not yet a proven exact contract.

## Important uncertainty

The exact upstream preconditions are not yet pinned down.

Open questions that the next slice should answer before broad rewriting:

- Does Binaryen drop the `start` only for empty/no-op nullary functions, or for any side-effect-free start target?
- Are local declarations alone irrelevant, as `case-000020` suggests?
- Does the rule depend on the function also being kept alive through exports or elem segments, or would Binaryen drop the `start` even if it were the only remaining live path?
- Is this truly part of `remove-unused-module-elements`, or a normalization side effect from another cleanup performed inside Binaryen's pass pipeline?

The next implementation slice should start by reducing the exact positive boundary and at least one nearby negative boundary, rather than guessing a broad semantic rule.

## Likely implementation focus

Investigate [`src/passes/remove_unused_module_elements.mbt`](../../../src/passes/remove_unused_module_elements.mbt), especially:

- the liveness mark from `start_sec`
- the unconditional `start_sec` rewrite path in `rume_apply_module_rewrite`
- whether there is already an in-tree helper that can classify a function body as observably empty under the same conservative rules Binaryen uses here
- whether the drop belongs in `RUME` proper or in a narrower post-rewrite cleanup guarded by exact preconditions

Relevant current sites include:

- `rume_collect_liveness_with_import_parent_policy(...)`, which marks the start target live
- `rume_apply_module_rewrite(...)`, which currently rewrites `start_sec` whenever the target survives

## Required next-slice deliverables

1. Add focused regressions in `src/passes/remove_unused_module_elements_test.mbt` for the saved `start`-section family.
2. Reduce the exact positive boundary plus at least one nearby negative boundary so the kept rule is explicit and safe.
3. Update `remove-unused-module-elements` only if the preconditions are proven narrowly enough to avoid dropping observable `start` behavior.
4. Re-run at minimum:
   - `moon test --package jtenner/starshine/passes --file remove_unused_module_elements_test.mbt`
   - `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator gen-valid --count 20 --max-failures 5 --out-dir .tmp/pass-fuzz-fuz003b-genvalid-smoke`
5. Record whether the family closes cleanly or exposes another distinct downstream mismatch family afterward.

## Why this is a fuzz slice, not only a pass slice

This issue was only surfaced because the widened `coverage-forced` `gen-valid` batch now emits start-sensitive module topologies with live exports, elem segments, and removable imports in the same small corpus. The fuzz backlog therefore needs an explicit handoff entry for the follow-up even though the eventual code fix will likely land inside the `RUME` pass.