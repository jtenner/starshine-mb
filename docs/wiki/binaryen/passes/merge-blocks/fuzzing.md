---
kind: workflow
status: supported
last_reviewed: 2026-07-26
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_merge_blocks_tests.mbt
---

# `merge-blocks` Fuzzing Profile

## Dedicated aggregate

`merge-blocks-all` is the stable pass-owned GenValid aggregate. It selects four weighted leaf profiles:

| Leaf profile | Weight | Covered surface |
| --- | ---: | --- |
| `merge-blocks-structural` | 3 | Nested block roots and branch-free loop/block wrappers. |
| `merge-blocks-expression` | 3 | Dropped values, `if` conditions, stores, throws, and ordinary expression-child prefixes. |
| `merge-blocks-effect-order` | 2 | Reorderable and conflicting global/memory effect boundaries. |
| `merge-blocks-eh-atomic` | 2 | `try_table`, dropped-reference, fence, and represented atomic barriers. |

Aliases `merge-blocks`, `merge-blocks-closeout`, and `merge-blocks-all-profiles` resolve to the aggregate. `random-all-profiles` also includes it.

The dedicated lane is:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass merge-blocks --gen-valid-profile merge-blocks-all --out-dir .tmp/pass-fuzz-merge-blocks-genvalid-merge-blocks-all-10000-v131-release-final --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

## 2026-07-26 Binaryen-v131 closeout

The final matrix used native Starshine SHA-256 `ae55a599bde483c6eb05347d85a1a5ef9d2c21c8b47dc100277763b82a0108ca` and explicit `wasm-opt version 131 (version_131)` SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`.

| Lane | Result | Residual classification |
| --- | --- | --- |
| Regular GenValid, count `100000`, seed `0x5eed` | `100000/100000` normalized matches | None. |
| `merge-blocks-all`, count `10000`, seed `0x5eed` | `10000/10000` normalized matches | None. |
| `random-all-profiles`, count `10000`, seed `0x5555` | `10000/10000` normalized matches | None. |
| wasm-smith, count `10000`, seed `0x5eed` | `9956/9956` comparable normalized matches | No Starshine mismatch; 44 Binaryen-v131 tool/parser failures: 39 `rec-group-zero`, 3 bad section size, 1 invalid tag index, and 1 table index out of range. |

All lanes reported zero Starshine validation, property, and generator failures. No compare normalizer was needed. Direct `moon check --target wasm-gc`, `moon test --target wasm-gc --jobs 1` (`9933/9933`), README/API sync, and the full CI fuzz suite also passed, including `86820` binary roundtrips.

The random-all lane initially exposed 67 `dae-optimizing-computed-effects` flat-stack call cases. Binaryen moved a later argument's `global.set` prefix before an earlier pure or disjoint `memory.grow` operand, while correctly retaining order before a trapping load. Starshine now has a narrow raw-boundary bridge for that exact two-argument direct-call shape; it requires a context-free prefix value, rejects local/global dependencies and trapping/unknown earlier operands, and leaves structured functions to the HOT pass.

## Representation boundary

Regular memory-atomic and `atomic.fence` acquire/release order is still not preserved through Starshine's boundary IR. The represented surface is conservatively safe and the matrix is closed, but Binaryen's allowed release-store optimization remains unavailable until decode, IR, encode, and HOT effects retain that ordering.
