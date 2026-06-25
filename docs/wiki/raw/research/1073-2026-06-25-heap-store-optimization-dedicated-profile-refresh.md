---
kind: research
status: active
created: 2026-06-25
sources:
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
  - ./1023-2026-06-24-heap-store-optimization-genvalid-profile.md
  - ./1071-2026-06-25-heap-store-optimization-direct-o4z-refresh.md
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/fuzz/main_wbtest.mbt
---

# `heap-store-optimization` dedicated GenValid profile refresh

## Question

After generated HSO profile coverage was extended through mutable-descriptor tail-call result-wrapper old-field cases (`1068`-`1070`), does the aggregate `heap-store-optimization` GenValid profile remain compare-green at the ordinary 10000-case dedicated-profile scale?

## Answer

Yes. The refreshed 10000-case dedicated-profile lane is compare-normalized green with `--normalize local-cleanup-debris`: all `10000/10000` cases compared, all `10000` matched through the documented local-cleanup-debris normalizer, and there were `0` raw mismatches, validation failures, property failures, generator failures, or command failures.

The raw-vs-cleanup-normalized split remains the known narrow profile drift from `1023`: Binaryen retains folded-store `nop` placeholders in these generated cases while Starshine emits nop-free validated output. This note does not broaden that classification beyond the documented local-cleanup-debris normalizer.

## Command

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --gen-valid-profile heap-store-optimization \
  --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-genvalid-profile-refresh-20260625-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result:

| Metric | Count |
|---|---:|
| Requested | 10000 |
| Compared | 10000 |
| Normalized matches | 0 |
| Cleanup-normalized matches (`local-cleanup-debris`) | 10000 |
| Raw mismatches | 0 |
| Validation failures | 0 |
| Property failures | 0 |
| Generator failures | 0 |
| Command failures | 0 |
| Binaryen cache | 8154 hits / 1846 misses |
| Binaryen failure cache | 0 hits / 0 misses |
| wasm-smith cache | 0 hits / 0 misses |

`cases.jsonl` selected profile counts:

| `genValidSelectedProfile` | Count |
|---|---:|
| `heap-store-optimization` | 10000 |

The recorded input effect/trap facts were saturated for this profile lane (`hasCall`, `mutatesMemory`, `mutatesTable`, `hasException`, `hasUnreachable`, and `mayTrap` true in all 10000 cases), reflecting the current aggregate generator's mixed feature floor.

## Interpretation

- This is strong generated-profile smoke evidence after the new true call-result, indirect/ref-call, descriptor, and tail-call old-field profile floors through `1070`.
- It is not final HSO closeout: final closeout still needs the full required signoff matrix and source-backed family review.
- Keep using `--normalize local-cleanup-debris` for the dedicated HSO profile while the Binaryen-retained `nop` vs Starshine nop-free drift remains the documented narrow cleanup-normalized profile difference.
