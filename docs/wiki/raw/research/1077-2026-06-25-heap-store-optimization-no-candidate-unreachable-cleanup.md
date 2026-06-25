---
kind: research
status: active
created: 2026-06-25
sources:
  - ./1076-2026-06-25-heap-store-optimization-wasm-smith-lane.md
  - ../../../src/passes/pass_manager.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
---

# HSO no-candidate unreachable cleanup replay

## Question

Can the `1076` explicit wasm-smith mismatch be fixed without accepting broad HSO output-shape drift?

## Answer

Yes. The mismatch was in the heap-store-optimization raw no-candidate fast path, not in a heap-store fold family. When the raw candidate scan found no local/constructor/store opportunity, Starshine returned the original lowered function unchanged and bypassed the shared `pass_raw_remove_dropped_unreachable_debris(...)` cleanup that other pass surfaces already use. Binaryen's HSO command removes a dead `drop(unreachable)` immediately before a hard `unreachable`, so the raw fast path now applies that shared cleanup before returning a no-candidate result.

This is a parity fix, not an accepted drift classification. The saved `case-009332-wasm-smith` replay now matches exactly at the normalized WAT layer with no cleanup normalizer.

## Changed coverage

Focused test added:

- `heap-store-optimization removes dropped unreachable debris on no-candidate raw skip`

The red-first failure showed the HSO no-candidate raw skip still had three `drop` roots where the Binaryen-shaped result should keep only the two ordinary dropped constants and one terminal `unreachable`.

Implementation change:

- `run_hot_pipeline_raw_heap_store_optimization(...)` still returns the original function when no heap-store candidate and no cleanup opportunity exist.
- If the shared dropped-unreachable cleanup changes the body, the raw-skip result carries the cleaned function and `unchanged_original: false`, so pipeline writeback records the cleanup.
- The trace reason remains `no-heap-store-candidates`; this preserves the existing fast-skip accounting while allowing a narrow cleanup mutation.

## Commands

Red-first focused test before implementation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: failed as intended on the new test, reporting `3 != 2` drops.

Focused test after implementation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `416/416` passed.

Formatting:

```sh
moon fmt
```

Result: passed.

Native compare binary refresh:

```sh
moon build --target-dir target --target native --release src/cmd
```

Result: passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.

Saved mismatch replay:

```sh
bun scripts/pass-fuzz-compare.ts \
  --replay-failures-from .tmp/pass-fuzz-heap-store-optimization-wasm-smith-20260625-10000 \
  --failure-status mismatch \
  --case-index 9332 \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-wasm-smith-1076-replay-after-cleanup \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 20 \
  --keep-going-after-command-failures
```

Result:

| Metric | Count |
|---|---:|
| Requested/replayed | 1 |
| Compared | 1 |
| Normalized matches | 1 |
| Cleanup-normalized matches | 0 |
| Raw mismatches | 0 |
| Validation failures | 0 |
| Property failures | 0 |
| Generator failures | 0 |
| Command failures | 0 |
| Binaryen cache | 1 hit / 0 misses |

Small direct GenValid smoke:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-genvalid-smoke-after-1076-cleanup-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 200 \
  --keep-going-after-command-failures
```

Result:

| Metric | Count |
|---|---:|
| Requested | 1000 |
| Compared | 1000 |
| Normalized matches | 1000 |
| Cleanup-normalized matches | 0 |
| Raw mismatches | 0 |
| Validation failures | 0 |
| Property failures | 0 |
| Generator failures | 0 |
| Command failures | 0 |
| Binaryen cache | 1000 hits / 0 misses |

## Remaining status

The specific `1076` mismatch is fixed and replay-green. Follow-up `1078` reran the full explicit wasm-smith 10000-case lane after this fix with `9956/10000` compared, `9956` normalized matches, and `0` mismatches. HSO-J is still not closeout-green: the final closeout matrix still needs the 100000 regular GenValid lane, dedicated HSO profile lane refresh or acceptance of `1073` as current, random all-profiles lane if/when the profile exists or is named, O4z slot/neighborhood replay, full Moon validation, performance status, and source-backed family review.
