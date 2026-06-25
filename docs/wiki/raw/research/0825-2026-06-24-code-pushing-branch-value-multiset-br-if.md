# 0825-2026-06-24 Code Pushing Branch-Value Multi-Set `br_if`

## Scope

Continue `[O4Z-AUDIT-CP]` after the first branch-value `br_if` slice. This slice widens only the source-backed adjacent, local-independent ordered multi-set family for value-block-target `br_if` shapes.

## Binaryen `version_130` evidence

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe input:

```wat
(module
  (func (export "f") (param i32) (result i32)
    (local i32 i32)
    (block $exit (result i32)
      i32.const 2
      local.set 1
      i32.const 3
      local.set 2
      (drop
        (br_if $exit
          (i32.const 7)
          (local.get 0)))
      local.get 1
      drop
      local.get 2
      drop
      i32.const 0)))
```

Command:

```sh
wasm-opt --all-features --code-pushing -S \
  .tmp/cp-probes/br_if_value_multiset.wat -o -
```

Binaryen moved both `local.set` roots after the dropped value-carrying `br_if` and preserved source order (`local.set $1` before `local.set $2`). This matches the `Pusher::optimizeSegment` ordered-movement model recorded in the `version_130` source refresh.

A related payload-read probe where the branch payload used `$1` kept `local.set $1` before the branch and moved the independent `local.set $2` after it. Starshine already had the single-set payload-read boundary; this slice does not attempt broader partial-window splitting beyond what the existing single-set fallback can prove.

## Starshine change

- `src/passes/code_pushing.mbt` now lets the ordered multi-set movement helper accept a value-carrying `BrIf` push point in addition to the prior no-branch-value `BrIf` subset. HOT may represent the WAT `drop (br_if ...)` as a direct `BrIf` with payload children, so the helper uses the same shape gate as the single-set branch-value slice and then relies on whole-root local accounting to reject branch payloads or conditions that read moved locals.
- `src/passes/code_pushing_test.mbt` adds a red-first focused test for two adjacent pure SFA sets before a value-block-target `br_if`. Before implementation, Starshine moved the sets through repeated single-set passes in reverse order; after implementation, the ordered helper moves them together and preserves Binaryen order.
- `src/validate/gen_valid.mbt` refreshes the targeted-only `code-pushing-br-if-value` leaf so it now emits the adjacent multi-set branch-value shape. The leaf remains excluded from `code-pushing-all` because the previously observed value-`br_if` HOT-lowering temporary-local representation/size gap is still open.

## Validation

- Red-first: `moon test src/passes/code_pushing_test.mbt --target native -f '*branch value*'` failed before implementation in `code-pushing preserves order moving multiple SFA sets after dropped br_if branch value` with reversed moved-local order (`2 != 1`).
- Focused after implementation: `moon test src/passes/code_pushing_test.mbt --target native -f '*branch value*'` passed `3/3` with pre-existing warnings.
- Focused GenValid profile tests: `moon test src/validate/gen_valid_tests.mbt --target native -f '*code-pushing*'` passed `3/3`.
- Aggregate-safe profile refresh with the branch-value leaf still excluded: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-branch-value-multiset-aggregate-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures` compared `1000/1000`, normalized `375`, cleanup-normalized `625`, raw mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache `1000 hits/0 misses`.

## Remaining caveats

- `code-pushing-br-if-value` remains targeted-only and is still not included in `code-pushing-all` until the value-`br_if` HOT-lowering temporary-local representation/size gap is fixed or normalized.
- This is not broad branch-value parity. Non-adjacent branch-value windows, branch-value local-copy dependencies, payload-reading partial ordered windows, value loop labels, `br_on_*`, switch/`br_table`, and broader `orderedBefore`/GC/EH/trap-option surfaces remain open.
