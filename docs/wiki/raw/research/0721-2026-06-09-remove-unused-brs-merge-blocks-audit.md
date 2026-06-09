# Remove-unused-brs merge-blocks/result-fallback audit

Date: 2026-06-09

## Question

Audit `remove-unused-brs` against Binaryen behavior, with special attention to the result-block / `br_if` prefix family exposed after `merge-blocks`. The suspected correctness class was: Starshine treats a result-block fallback as removable even though at least one path still falls through to the block end and needs that result value.

## Local oracle

- Local Binaryen: `wasm-opt version 130 (version_130)`.
- Starshine native binary: `target/native/release/build/cmd/cmd.exe`, rebuilt after the code change.
- Canonical pass spelling: `remove-unused-brs`.
- Ordered-neighborhood probe: `merge-blocks -> remove-unused-brs`, because Binaryen intentionally reruns RUB after `merge-blocks` in the no-DWARF optimize pipeline.

## Source behavior inventory

Binaryen `RemoveUnusedBrs` is broader than dead tail deletion. The relevant behavior surface, from the existing dossier and current local `version_130` oracle, is:

| Binaryen family | Starshine status after this audit | Tests / evidence |
| --- | --- | --- |
| Plain redundant tail `br` / `return`, including multivalue | Implemented | Existing `remove_unused_brs_test.mbt` tail and return tests |
| Tail `if` whose arms exit to the same continuation | Implemented | Existing stack-style branch/return arm tests |
| Constant-condition `br_if` without payload | Implemented before this slice | Existing `folds constant br-if conditions` |
| Constant-condition `br_if` with carried payload | **Fixed in this slice**. False condition now leaves payload; true condition becomes a payload `br`. | New `folds constant br-if with carried payloads` |
| One-arm `if br` / nested one-arm condition folding | Implemented | Existing one-arm, nested, and chain tests |
| Repeated `br_if (x == const)` to `br_table` | Implemented for current local dense-eq subset | Existing repeated equality ladder test |
| Direct `br_table` cleanup / wrapper retargeting | Implemented for current carried-wrapper and self-target subsets | Existing `br_table` wrapper/self-target tests |
| Result-block prefix payload branch (`block(result) (block (br_if self) ... (br outer payload)) fallback`) | Implemented; this audit added a merge-blocks-neighborhood fallback guard | Existing result-prefix tests plus new fallback preservation test |
| Result-block fallback after `merge-blocks -> remove-unused-brs` | **Guarded in this slice**. The fallback value remains a live block-body root when the `br_if` true path falls through. | New `preserves merge-blocks-exposed result-block fallbacks`; 1000-case ordered compare green with normalizers |
| Pure value `if` to `select` and local.set(if) cleanup | Implemented for the modeled HOT subset | Existing select/local.set tests |
| Loop/body restructuring and block sinking | Implemented for selected safe families; not complete Binaryen coverage | Existing loop fallthrough, one-exit-arm, rotation tests; remaining gaps below |
| EH `throw` caught by `try_table` to branch | Not implemented in RUB HOT logic today | Open behavior gap; needs focused red tests before implementation |
| GC `br_on_null`, `br_on_non_null`, `br_on_cast*` cleanup | Not implemented in RUB HOT logic today | Open behavior gap; current random compare does not prove this surface |
| Branch-hint preservation / `neverUnconditionalize` | No full Starshine metadata-equivalent audit in this slice | Open behavior/metadata gap unless branch hints remain intentionally out of local scope |
| Upstream switch cleanup beyond current `br_table` subsets | Partial | Existing direct `br_table` tests; broader switch/default trimming remains open |
| Jump-threading / branches-to-traps current-main drift | Partial / tracked separately | Existing continuation-wrapper tests; newer branch-to-trap behavior remains an upstream drift item |

Conclusion: this slice improves direct Binaryen behavior parity and hardens the suspected result-fallback class, but it does **not** close `[O4Z-AUDIT-RUB]` because broad upstream EH/GC/switch/metadata surfaces remain unimplemented or unaudited.

## Focused behavior found and fixed

### Constant payload `br_if`

Binaryen simplifies a tail `br_if` with a constant condition even when the branch carries a block result payload. Starshine previously only folded `br_if` nodes with exactly one child, so payload forms were left unchanged.

Reduced false-condition shape:

```wat
(module
  (func (result i32)
    (block $exit (result i32)
      i32.const 7
      i32.const 0
      br_if $exit)))
```

Expected behavior: remove `br_if`, preserve the carried `i32.const 7` as the fallthrough block result.

Reduced true-condition shape:

```wat
(module
  (func (result i32)
    (block $exit (result i32)
      i32.const 7
      i32.const 1
      br_if $exit)))
```

Expected behavior: remove `br_if`, keep the payload on a plain branch to the same target. A later cleanup may erase that branch when safe; this slice only requires the Binaryen-visible constant-conditional cleanup and payload preservation.

Implementation change: `remove_unused_brs_try_fold_constant_br_if(...)` now treats the final child as the condition and preserves any earlier children as branch/fallthrough payloads.

### Merge-blocks-exposed result fallback

The focused guard shape is:

```wat
(module
  (func (param i32 i32) (result i32)
    (block $outer
      (block $exit (result i32)
        (block $inner
          (br_if $inner (local.get 0))
          (local.get 1)
          (br $exit))
        (i32.const 9))
      (return))
    (i32.const 0)))
```

After `merge-blocks -> remove-unused-brs`, the `local.get 0 != 0` path still falls through the rewritten prefix `if` and requires the `i32.const 9` fallback at the result-block end. The new focused test asserts:

- the fallback `I32(9)` remains live,
- the unreachable suffix `I32(0)` can be removed,
- the explicit `return` can be stripped,
- the result block still has two body roots: the rewritten guard and the fallback constant.

This did not reproduce a current validation/runtime failure in the tree, but it locks the exact suspected merge-blocks/RUB interaction so future tail-control changes cannot silently remove that fallback.

## Compare evidence

Focused tests:

```sh
moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt
# Total tests: 113, passed: 113, failed: 0.
```

Pass package:

```sh
moon test src/passes
# Total tests: 2044, passed: 2044, failed: 0.
```

Native build:

```sh
moon build --target native --release src/cmd
# Passed; only pre-existing pass_manager unused-function warnings.
```

Direct RUB compare after the fix:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass remove-unused-brs \
  --normalize drop-consts \
  --normalize unreachable-control-debris \
  --out-dir .tmp/pass-fuzz-rub-audit-final-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 50 \
  --keep-going-after-command-failures
```

Result: compared `998/1000`, normalized matches `571`, cleanup-normalized matches `427`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `2`.

Ordered `merge-blocks -> remove-unused-brs` compare after the fix:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass merge-blocks \
  --pass remove-unused-brs \
  --normalize drop-consts \
  --normalize unreachable-control-debris \
  --out-dir .tmp/pass-fuzz-mb-rub-audit-final-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 50 \
  --keep-going-after-command-failures
```

Result: compared `998/1000`, normalized matches `571`, cleanup-normalized matches `427`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `2`.

Agent classification: the cleanup-normalized cases remain semantic-safe dropped-constant / unreachable-control debris already covered by the active compare normalizers. The two command failures are Binaryen/tool command failures, not Starshine validation or semantic mismatches.

A prior unnormalized 1000-case direct probe timed out and wrote raw mismatch artifacts dominated by known cleanup drift, so the behavior classification above relies on the established RUB normalizer set rather than raw WAT equality.

## Remaining RUB audit work

Do not close `[O4Z-AUDIT-RUB]` on this slice. Remaining behavior-parity work should be split into focused red-test tracks:

1. EH `throw` to caught `try_table` branch, including `catch_ref` / `catch_all_ref` negatives.
2. GC `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` cleanup, including nullability and fallthrough-type negatives.
3. Broader switch/default trimming and large mostly-default `br_table` restructuring beyond the current local subsets.
4. Branch-hint / `neverUnconditionalize` metadata equivalence or an explicit accepted non-goal.
5. Current-main branches-to-traps drift versus the local `version_130` oracle.
6. A final closeout compare at `100000` cases after those broad source-documented surfaces are either implemented or explicitly scoped out.

## Files touched by this slice

- `src/passes/remove_unused_brs.mbt`
  - widened constant `br_if` folding to preserve carried payload children.
- `src/passes/remove_unused_brs_test.mbt`
  - added constant payload `br_if` true/false coverage.
  - added merge-blocks-exposed result-block fallback preservation coverage.

## Reopening criteria

Reopen this specific slice if any future `merge-blocks -> remove-unused-brs` run removes the result-block fallback from a prefix-guard shape where the guard-taken path can fall through to the block end, or if direct compare produces a non-normalized semantic mismatch involving constant-condition payload `br_if` cleanup.
