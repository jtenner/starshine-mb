---
kind: research
status: current
last_reviewed: 2026-06-29
sources:
  - ./1354-2026-06-29-heap-store-optimization-hot-candidate-speed-rerun.md
  - ./1127-2026-06-25-heap-store-optimization-local-attribution.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ../../binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md
  - ../../../../src/passes/heap_store_optimization.mbt
  - ../../../../src/passes/heap_store_optimization_test.mbt
  - ../../../../src/passes/registry_test.mbt
---

# HSO tiny plain-struct.new fast path

## Question

Can Starshine reduce direct `heap-store-optimization` pass-local time on `.tmp/hso-hot-plain-struct-new-candidates-2000-20260625.wat` by matching Binaryen's cheap action-list style for the hot plain `struct.new`/two-`struct.set` shape?

## Result

Partial yes. This slice added a narrow HOT fast path for root regions that are exactly:

```wat
(local.set $x (struct.new $S CONST...))
(struct.set $S i (local.get $x) CONST_OR_REF_NULL)
(struct.set $S j (local.get $x) CONST_OR_REF_NULL)
```

where all constructor operands and replacement values are childless `Const` or `RefNull` HOT nodes. The fast path folds the two stores into the constructor, removes the two store roots with one region splice, and returns before the general HSO path. The HSO descriptor now leaves `requires=[]`; the general path still calls `pass_require_effects(...)` lazily after the tiny fast path misses. This avoids precomputing the effects overlay for the exact HOT fixture family.

The improvement is real but not enough: the seven-sample median dropped from the 2026-06-29 rerun's `10.350ms` to `6.881ms`, while Binaryen's median in the refreshed run was `1.110ms`. Starshine remains `6.199x` slower (`0.161x` Binaryen speed), so `[O4Z-AUDIT-HSO]` stays open.

## Why this matches Binaryen's cheap strategy

Binaryen's `HeapStoreOptimization.cpp` records only `StructSet` and `Block` action pointers while walking CFG basic blocks, then `optimizeBlock(...)` scans the block list in place. The hot fixture does not need Starshine's broad HOT wrapper, effect-order, descriptor, catch, branch, or prefix lifting machinery: the values are all childless constants and the roots are strictly consecutive. The new fast path therefore skips the general chain machinery when it can prove that exact simple shape locally.

## Implementation notes

Changed files:

- `src/passes/heap_store_optimization.mbt`
  - added `hso_fast_chain_leaf(...)` for childless `Const` / `RefNull` operands;
  - added `hso_try_fold_pure_plain_struct_set_chain(...)` for a non-root narrow plain-`struct.new` consecutive chain fallback;
  - added `hso_try_fold_tiny_pure_plain_region(...)` for exact three-root hot regions;
  - made `heap_store_optimization_run(...)` try the tiny pure root fast path before lazily requiring effects;
  - changed the descriptor `requires` list to `[]` because effects are now dynamic: required only after the fast path misses.
- `src/passes/registry_test.mbt`
  - updated the descriptor expectation for HSO to the lazy-effects contract.

Safety limits:

- only exact plain `StructNew`, not descriptor/default constructors;
- only exact root count `3` for the pre-effects fast path;
- only same-local `struct.set(local.get $x, value)` roots;
- only childless constant/ref.null old operands and replacement values;
- falls back to the existing full HSO machinery for wrappers, effectful values, branches, catch/try-table hazards, descriptors, nonconsecutive stores, and broader swap families.

## Timing evidence

Fixture: `.tmp/hso-hot-plain-struct-new-candidates-2000-20260625.wat`.

Build:

```sh
moon build --target native --release src/cmd
```

Seven samples:

```sh
bun scripts/self-optimize-compare.ts \
  .tmp/hso-hot-plain-struct-new-candidates-2000-20260625.wat \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/hso-hot-plain-struct-new-fastsplice-20260629/run-$n \
  --heap-store-optimization
```

| Run | Starshine pass ms | Binaryen pass ms | Raw skipped | Normalized WAT equal | Canonical function compare equal |
|---:|---:|---:|---|---|---|
| 1 | 7.826 | 1.085 | no | yes | yes |
| 2 | 6.159 | 1.657 | no | yes | yes |
| 3 | 6.716 | 1.037 | no | yes | yes |
| 4 | 6.238 | 1.679 | no | yes | yes |
| 5 | 7.327 | 0.999 | no | yes | yes |
| 6 | 7.862 | 1.110 | no | yes | yes |
| 7 | 6.881 | 1.644 | no | yes | yes |

Medians:

- Starshine: `6.881ms`
- Binaryen: `1.110ms`
- Starshine/Binaryen slowdown: `6.199x`
- Binaryen-speed fraction: `0.161x`
- Current `0.95x` target at this Binaryen median: Starshine `<=1.168ms`

Earlier local observations while iterating:

- plain-chain helper without root pre-effects avoidance: still about `9.1ms-9.5ms` pass-local;
- tiny root fast path with nop replacement and lazy effects: noisy `7.177ms-9.887ms` samples;
- switching consumed roots to one region splice gave the final seven-sample median `6.881ms`.

Trace interpretation caveat: direct `--tracing pass` shows the HSO pass timer still dominated by per-function lift/lower and mutation/writeback overhead on this many-small-functions fixture. Removing descriptor `requires=[effects]` eliminated the separate effects precompute from the tiny fast path, but the direct benchmark target includes more than just the internal rewrite helper cost.

## Validation

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — passed, `417/417`.
- `moon test --package jtenner/starshine/passes --file registry_test.mbt` — passed, `7/7`.
- `moon test src/passes` — passed, `3575/3575`.
- `moon build --target native --release src/cmd` — passed with existing warnings.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-hso-lazy-fastpath-100-20260629 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20` — compared `100/100`, normalized matches `100`, mismatches `0`, validation/generator/property/command failures `0`.
- Seven `self-optimize-compare` runs above — all normalized-equal, canonical-function-equal, raw-skipped `no`.

## Remaining risks and next target

- HSO speed target remains far open. The fast path is only a partial win.
- Static `requires=[]` is intentional for lazy effects, but future HSO edits must keep every effect-dependent path behind `pass_require_effects(...)`; otherwise descriptor truthfulness can regress.
- The remaining direct pass time appears dominated by per-function HOT lift/lower and mutation/writeback overhead, not just the general chain proof helpers.
- Next high-leverage direction: investigate a pass-manager / HOT execution fast lane for many tiny root-only functions that can rewrite this exact pattern without the ordinary per-function lift/lower/mutation overhead, or batch/specialize the root-region mutation so the traced pass-local timer no longer pays several microseconds per function.
