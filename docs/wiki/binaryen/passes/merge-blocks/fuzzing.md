---
kind: workflow
status: supported
last_reviewed: 2026-08-12
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
| `merge-blocks-effect-order` | 2 | Reorderable and conflicting global/memory effect boundaries; the review matrix also exercises represented trap/trap pairs. |
| `merge-blocks-eh-atomic` | 2 | `try_table`, dropped-reference, fence, and represented atomic barriers. |

Aliases `merge-blocks`, `merge-blocks-closeout`, and `merge-blocks-all-profiles` resolve to the aggregate. `random-all-profiles` also includes it.

The dedicated lane is:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass merge-blocks --gen-valid-profile merge-blocks-all --out-dir .tmp/pass-fuzz-merge-blocks-genvalid-merge-blocks-all-10000-v131-release-final --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

## 2026-08-12 stack-carried-local guard refresh

Native SHA-256 `15804fd785eada79e95fcfc783cc026c5bab86f71fa80e24d1c176a923e7c86e` reran the dedicated aggregate against the explicit verified Binaryen-v131 binary:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass merge-blocks --gen-valid-profile merge-blocks-all --out-dir .tmp/pass-fuzz-merge-blocks-stack-carried-fix-dedicated-10000-v131-20260812 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

Result: `10000/10000` normalized matches, zero cleanup-normalized residuals, mismatches, validation failures, property failures, generator failures, or command failures. Binaryen cache was `10000/0`. This refresh follows the direct stack-carried-overwritten-local regression discovered by SGO late-suffix runtime testing; the new guard is fail-closed and does not change the generated aggregate's Binaryen parity.

## 2026-07-31 review reclose matrix

The repaired pass uses native SHA-256 `11322ff39e52cef842f0fdf263fc3d35ec3b823ab84f0540ff5984f8a8806174` and explicit official Binaryen-v131 SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`.

| Lane | Result | Classification |
| --- | --- | --- |
| Regular GenValid, count `100000`, seed `0x5eed` | `100000/100000` normalized matches | Exact; zero failures. |
| `merge-blocks-all`, count `10000`, seed `0x5eed` | `10000/10000` normalized matches | Exact; every selected leaf sampled, zero failures. |
| Random all-profiles, count `10000`, seed `0x5555` | `9827` normalized matches plus `173` residuals | Same neighboring-profile Starshine wins as the historical closeout: every residual is smaller, range `-18..-1`, total `-1130` bytes, zero ties or losses. |
| wasm-smith, count `10000`, seed `0x5eed` | `9956/9956` comparable normalized matches | Zero Starshine failures; 44 Binaryen-only cached parser/tool failures. |

The random-all residuals split into `56` `local-subtyping-control-refinalize`, `24` multivalue-drop, `21` GC, and `18` each result-refinalize, switch, control, and cleanup cases. Focused runtime separately proves that preserving the earlier load trap is an intentional correctness win over both pre-review Starshine and Binaryen v131, which expose the later division trap on the reduced fixture. No compare normalizer is needed for this pass.

## Historical 2026-07-31 Binaryen-v131 closeout

This earlier matrix predates the post-closeout distinct-trap-order review. It remains provenance; the refreshed matrix above supersedes its direct closeout status.

The historical matrix used native Starshine SHA-256 `01fd7706f67cf5d2628a4339b6f78d02cadcb541e830d9c7219e6136703cfcf0` and explicit `wasm-opt version 131 (version_131)` SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`.

| Lane | Result | Residual classification |
| --- | --- | --- |
| Regular GenValid, count `100000`, seed `0x5eed` | `100000/100000` normalized matches | None. |
| `merge-blocks-all`, count `10000`, seed `0x5eed` | `10000/10000` normalized matches | None. |
| `random-all-profiles`, count `10000`, seed `0x5555` | `9827` exact plus `173` raw residuals | All 173 are strictly smaller Starshine outputs, `-1..-18` bytes each and `-1130` bytes total. Selected profiles are `local-subtyping-control-refinalize` (`56`) and six `remove-unused-brs-*` families (`117`); there are zero ties or size losses. |
| wasm-smith, count `10000`, seed `0x5eed` | `9956/9956` comparable normalized matches | No Starshine mismatch; 44 Binaryen-v131 tool/parser failures: 39 `rec-group-zero`, 3 bad section size, 1 invalid tag index, and 1 table index out of range. |

All lanes reported zero Starshine validation, property, and generator failures and zero Starshine command failures. No compare normalizer was needed. The regular and dedicated reruns reused the deterministic saved GenValid manifests through the harness's `--resume` mode and rebuilt every Starshine output; Starshine outputs are never cached.

The random-all residuals are representation wins, not unclassified semantic drift. Literal multivalue drops avoid Binaryen scratch shells, scalar stack values avoid unnecessary local spills, and all-null branch-result blocks are narrowed to the hierarchy bottom without retained casts. The final lowered cleanup removed the former 44 size losses; every residual is now no-larger and externally valid.

## Representation boundary

General regular memory-atomic and `atomic.fence` acquire/release order is still not preserved through Starshine's boundary IR. The represented surface remains conservative, while a narrow raw bridge handles the exact official v131 acquire/release fixture and produces byte-identical `93`-byte output. Broader atomic extraction should reopen only when decode, IR, encode, and HOT effects retain ordering generically.
