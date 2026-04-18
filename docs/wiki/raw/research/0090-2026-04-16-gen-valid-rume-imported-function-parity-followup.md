# 0090 - Gen-valid RUME imported-function parity follow-up

## Status

- Resolved for the imported-function family on 2026-04-16.
- The focused rerun `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator gen-valid --count 20 --max-failures 5 --out-dir .tmp/pass-fuzz-fuz003a-genvalid-smoke` reached `20/20` compared cases with `18` normalized matches, `0` validation failures, `0` generator failures, and `0` command failures.
- The original imported-function repro family is gone after the fix.
- The same rerun exposed a distinct remaining mismatch family in `.tmp/pass-fuzz-fuz003a-genvalid-smoke/failures/case-000002-gen-valid/` and `case-000020-gen-valid/`, where Binaryen drops a no-op `start` section that Starshine still preserves. That is a separate downstream parity follow-up, not imported-function retention.

## Scope

- Capture the exact `gen-valid`-seeded `remove-unused-module-elements` parity failure exposed immediately after `[FUZ]003` widened topology generation.
- Record the concrete repro so the next validator-fuzz slice can point at one exact case instead of re-deriving the mismatch from chat history.
- Narrow the follow-up requirement to the imported-function pruning/remap surface rather than reopening the already-landed imported memory/table/global/tag work.

## Trigger

After landing `[FUZ]003`, the repo now emits `coverage-forced` `gen-valid` batches that can include unused imported functions plus surviving defined `main` functions, tables, memories, globals, tags, start sections, elem segments, and data segments.

That widened surface exposed a new `RUME` parity hole on the first focused smoke rerun:

- Command:
  - `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator gen-valid --count 20 --max-failures 5 --out-dir .tmp/pass-fuzz-fuz003-genvalid-smoke`
- Result:
  - `comparedCount=5`
  - `normalizedMatchCount=0`
  - `mismatchCount=5`
  - `validationFailureCount=0`
  - `generatorFailureCount=0`
  - `commandFailureCount=0`

This is therefore a semantic parity mismatch, not a generator-invalidity or command-failure issue.

## Exact saved case

Primary saved repro:

- `.tmp/pass-fuzz-fuz003-genvalid-smoke/failures/case-000001-gen-valid/`

Files of interest:

- input module: `.tmp/pass-fuzz-fuz003-genvalid-smoke/failures/case-000001-gen-valid/input.print.wat`
- Binaryen output: `.tmp/pass-fuzz-fuz003-genvalid-smoke/failures/case-000001-gen-valid/binaryen.wat`
- Starshine output: `.tmp/pass-fuzz-fuz003-genvalid-smoke/failures/case-000001-gen-valid/starshine.wat`
- mismatch marker: `.tmp/pass-fuzz-fuz003-genvalid-smoke/failures/case-000001-gen-valid/failure.txt`

### Input summary

The input contains:

- an imported function:
  - `(import "env" "imported_func_0" (func (;0;) (type 2)))`
- one live exported/start function `1` used by:
  - `(export "main" (func 1))`
  - `(start 1)`
  - `(elem (;0;) (i32.const 0) func 1)`
- live table/memory/global/tag/data sections that should stay
- two extra defined functions that are dead and should be removed

Key point: the imported function is unused after trimming and should disappear if Binaryen-style imported module-element cleanup is working.

### Binaryen normalized output

Binaryen keeps only the live zero-arg function type and the live defined `main` function. It drops the unused imported function and its now-dead function type:

```wat
(module
 (type $0 (func))
 (global $global$0 i32 (i32.const 369))
 (memory $0 1 4)
 (data $0 (i32.const 0) "gen-valid")
 (table $0 1 4 funcref)
 (elem $0 (i32.const 0) $0)
 (tag $tag$0 (type $0))
 (export "main" (func $0))
 (export "table0" (table $0))
 (export "memory0" (memory $0))
 (export "global0" (global $global$0))
 (export "tag0" (tag $tag$0))
 (start $0)
 (func $0 (type $0)
  (drop
   (f32.const 66)
  )
  (nop)
 )
)
```

### Starshine normalized output

Starshine keeps the same live defined `main` function, but it incorrectly preserves the unused imported function and its type:

```wat
(module
 (type $0 (func))
 (type $1 (func (param i32 f32) (result i32)))
 (import "env" "imported_func_0" (func $fimport$0 (type $1) (param i32 f32) (result i32)))
 (global $global$0 i32 (i32.const 369))
 (memory $0 1 4)
 (data $0 (i32.const 0) "gen-valid")
 (table $0 1 4 funcref)
 (elem $0 (i32.const 0) $0)
 (tag $tag$0 (type $0))
 (export "main" (func $0))
 (export "table0" (table $0))
 (export "memory0" (memory $0))
 (export "global0" (global $global$0))
 (export "tag0" (tag $tag$0))
 (start $0)
 (func $0 (type $0)
  (drop
   (f32.const 66)
  )
  (nop)
 )
)
```

## Expected contract

The existing RUME docs and backlog already record that Binaryen drops unused imported module elements, and the in-tree Starshine port already fixed that behavior for imported memories, tables, globals, and tags.

This repro shows the imported-function case is still missing from the landed cleanup surface exposed by widened `gen-valid` topology.

Expected behavior for this family:

- drop the unused imported function from `import_sec`
- compact or rewrite the surviving function-type pool if the import was the only user of that type
- keep the surviving live defined function indexed/exported/started correctly after the import disappears
- preserve the still-live table/memory/global/tag/elem/data/start/export surface

## Likely implementation focus

Investigate `src/passes/remove_unused_module_elements.mbt`, especially:

- imported function liveness marking versus defined function liveness
- `import_sec` rebuild logic for function imports compared with the already-fixed table/memory/global/tag paths
- function/type remap and compaction after imported function removal
- survivor rewrites through exports, start, elem segments, and any name/annotation surfaces that still reference post-import function indices

Existing focused imported-element tests already cover other imported categories in:

- `src/passes/remove_unused_module_elements_test.mbt`

The missing follow-up is a function-import-specific regression.

## Required next-slice deliverables

1. Add a focused regression in `src/passes/remove_unused_module_elements_test.mbt` for an unused imported function that should be removed while a defined `main` function remains live.
2. Fix `remove-unused-module-elements` so function imports are trimmed and remapped like the already-landed imported memory/table/global/tag cases.
3. Re-run at minimum:
   - `moon test src/passes`
   - `moon test src/cmd` if CLI-facing replay coverage changes
   - `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator gen-valid --count 20 --max-failures 5 --out-dir .tmp/pass-fuzz-fuz003a-genvalid-smoke`
4. Record whether the remaining `gen-valid` mismatches collapse completely or expose a second follow-up family after imported-function pruning is fixed.

## Landed fix summary

The landed fix in [`src/passes/remove_unused_module_elements.mbt`](../../../../src/passes/remove_unused_module_elements.mbt) and [`src/passes/remove_unused_module_elements_test.mbt`](../../../../src/passes/remove_unused_module_elements_test.mbt) now:

- drops unused imported functions in the module-pass `RUME` import rebuild path
- remaps surviving function indices through the real used-function bitset instead of assuming all imported functions stay live
- compacts dead simple function types after imported-function removal by reusing the existing passes-package type-index rewrite machinery
- keeps surviving exports, start sections, elem segments, and function names coherent after the imported function disappears

## Why this is a fuzz slice, not only a pass slice

This regression was not visible before `[FUZ]003` because the earlier valid generator rarely produced the exact widened module topology needed to expose it. The fuzz worker therefore owned both the follow-up capture and the handoff bookkeeping, even though the final code fix landed in the `RUME` pass implementation.
