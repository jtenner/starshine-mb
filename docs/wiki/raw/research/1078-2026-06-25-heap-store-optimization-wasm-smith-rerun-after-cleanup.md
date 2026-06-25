---
kind: research
status: active
created: 2026-06-25
sources:
  - ./1076-2026-06-25-heap-store-optimization-wasm-smith-lane.md
  - ./1077-2026-06-25-heap-store-optimization-no-candidate-unreachable-cleanup.md
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
  - ../../../scripts/pass-fuzz-compare.ts
---

# HSO explicit wasm-smith rerun after no-candidate cleanup

## Question

After the `1077` no-candidate raw cleanup fix, is the required explicit wasm-smith HSO lane green?

## Answer

Yes for this lane. The 10000-case explicit `--wasm-smith` HSO lane at seed `0x5eed` now has zero mismatches without cleanup normalizers: `9956/10000` requested cases compared, all `9956` normalized, with the same `44` Binaryen/oracle command failures as `1076` and no Starshine validation, property, or generator failures.

This closes the specific `1076` wasm-smith output-shape cleanup gap. It does not complete HSO-J, because final closeout still needs the 100000 regular GenValid lane, dedicated HSO profile lane refresh or acceptance of `1073` as current, random all-profiles lane if/when the profile exists or is named, O4z slot/neighborhood replay, full Moon validation, performance status, and source-backed residual family review.

## Command

```sh
bun scripts/pass-fuzz-compare.ts \
  --wasm-smith \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-wasm-smith-after-1077-20260625-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result:

| Metric | Count |
|---|---:|
| Requested | 10000 |
| Compared | 9956 |
| Normalized matches | 9956 |
| Cleanup-normalized matches | 0 |
| Raw mismatches | 0 |
| Validation failures | 0 |
| Property failures | 0 |
| Generator failures | 0 |
| Command failures | 44 |
| Binaryen rec-group-zero failures | 39 |
| Binaryen invalid-tag-index failures | 1 |
| Binaryen table-index-out-of-range failures | 1 |
| Binaryen bad-section-size failures | 3 |
| wasm-smith cache | 10000 hits / 0 misses |
| Binaryen cache | 9956 hits / 0 misses |
| Binaryen failure cache | 44 hits / 0 misses |

Input feature/trap facts across the lane:

| Fact | Count |
|---|---:|
| hasCall | 2837 |
| mutatesMemory | 1728 |
| mutatesTable | 227 |
| mutatesGlobal | 250 |
| hasException | 7039 |
| hasAtomics | 170 |
| hasUnreachable | 9981 |
| mayTrap | 9981 |

## Classification

Agent classification: no true HSO semantic mismatches and no remaining output-shape mismatch in this explicit wasm-smith lane. The `44` command failures are Binaryen/oracle decode/validation classes already observed in `1076` and are not Starshine validation failures.

No normalizers were used. The result is stronger than the `1077` single-case replay and can replace `1076` as the current explicit wasm-smith lane evidence for HSO-J, while still not substituting for the other final-matrix lanes or source-backed family closure.
