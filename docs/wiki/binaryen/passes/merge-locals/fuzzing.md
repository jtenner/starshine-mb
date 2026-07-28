---
kind: workflow
status: strong
last_reviewed: 2026-07-28
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/MergeLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/passes/merge-locals_all-features.wast
  - ./index.md
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_merge_locals_tests.mbt
---

# `merge-locals` fuzzing profiles

Use `merge-locals-all` for direct closeout. It deterministically samples fifteen source-family leaves and records both `selected_profile` and a seed-rotated case label.

| Profile | Family |
| --- | --- |
| `merge-locals-forward` | single forward source-use retarget |
| `merge-locals-forward-multiple` | all sibling source uses retarget together |
| `merge-locals-partial-influence` | linear and branch-local uses before a later source write |
| `merge-locals-reverse` | reverse destination-use retarget when forward is blocked |
| `merge-locals-reverse-boundary` | source lifetime ended / later-source-write negatives |
| `merge-locals-control` | block, `if`, and loop influences |
| `merge-locals-tee` | `local.tee` copy candidates |
| `merge-locals-merge-boundary` | multi-source/phi rejection |
| `merge-locals-type-boundary` | exact type equality and GC strict-subtype rejection |
| `merge-locals-rollback` | forward target-clobber rollback |
| `merge-locals-reverse-rollback` | direct, conditional, and nested reverse rollback |
| `merge-locals-nested-copies` | interacting synthetic/nested copy candidates |
| `merge-locals-trivial-confusion` | upstream loop interaction with an unread tee target |
| `merge-locals-unreachable` | `between-unreachable` robustness |
| `merge-locals-legacy-eh` | protected, typed-catch, catch-all, and delegate-bearing legacy `try` regions |

## Final 2026-07-28 matrix

Oracle: official `.tmp/binaryen-version-131-bin/bin/wasm-opt`, `wasm-opt version 131 (version_131)`, SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`.

Starshine: `_build/native/release/build/cmd/cmd.exe`, SHA-256 `8bc8fa62e9580d12ce9e8981153d4ab88c5d6a00a0deffb0a9628c3a492c4723`.

All lanes used `--jobs auto`, the default persistent `.tmp/pass-fuzz-cache`, explicit binary paths, `--max-failures 2000`, and `--keep-going-after-command-failures`.

### Regular GenValid

```text
bun fuzz compare-pass --count 100000 --seed 0x5eed --pass merge-locals \
  --out-dir .tmp/pass-fuzz-merge-locals-v131-renewal-regular-100000 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt
```

Result: `100000/100000` compared and normalized; zero mismatches, validation failures, generator failures, property failures, or command failures. Cache: Binaryen `320` hits / `99680` misses.

### Dedicated aggregate

```text
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass merge-locals \
  --gen-valid-profile merge-locals-all \
  --out-dir .tmp/pass-fuzz-merge-locals-v131-renewal-dedicated-10000 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt
```

Result: `10000/10000` compared; `9353` normalized matches and `647` raw residuals; zero failures. Cache: Binaryen `8917` hits / `1083` misses.

Every residual is `merge-locals-trivial-confusion`. Starshine removes an unread `local.tee` while preserving the branch condition value. Canonical byte census: `9353` equal, `647` Starshine smaller, `0` Starshine larger; every win is `-2` bytes, totaling `-1294` bytes.

All fifteen leaves were selected `624..717` times. Seed-rotated coverage includes `216/211/213` block/if/loop cases; `320/363` partial-influence cases; `309/337` reverse-boundary cases; `240/221/204` reverse-rollback cases; `367/350` nested-copy cases; and `193/180/169/167` protected/catch/catch-all/delegate legacy-EH cases.

### Random all profiles

```text
bun fuzz compare-pass --count 10000 --seed 0x5555 --pass merge-locals \
  --gen-valid-profile random-all-profiles \
  --out-dir .tmp/pass-fuzz-merge-locals-v131-renewal-random-all-10000 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt
```

Result: `10000/10000` compared; `9330` normalized matches and `670` measured Starshine wins; zero failures. Cache: Binaryen `5733` hits / `4267` misses.

Byte classification: `625` `remove-unused-brs-control` structured-result forms are `-8` canonical bytes each, and `45` `merge-locals-trivial-confusion` forms are `-2` bytes each. Totals: `9330` equal, `670` smaller, `0` larger, `-5090` bytes aggregate. A structured-result representative is idempotent and produces the same runtime trap in both tools.

### wasm-smith

```text
bun fuzz compare-pass --wasm-smith --count 10000 --seed 0x5eed \
  --pass merge-locals \
  --out-dir .tmp/pass-fuzz-merge-locals-v131-renewal-wasm-smith-10000 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt
```

Result: `9956/10000` comparable; `9955` normalized matches, one non-pass residual, zero Starshine/validation/property/generator failures, and `44` Binaryen-only failures. Cache: wasm-smith `10000` hits / `0` misses; Binaryen `106` hits / `9850` misses; Binaryen failures `0` hits / `44` misses.

Binaryen failure classes: `39` zero-length rec groups, one invalid tag index, one table index out of range, and three bad section sizes.

Residual case `9332` has no local reads, sets, tees, or copy candidates. Starshine no-pass and `--merge-locals` are byte-identical at SHA-256 `548cc8e99c3e5a413344aaa0d135945fa2e524899b8b1ce6c3c7fbcd3bfff8fb`; Binaryen removes two bytes of unreachable stack debris during reader/writer canonicalization. This remains `[TOOL]001`.

## Runtime and idempotence

`.tmp/pass-fuzz-merge-locals-v131-renewal-runtime-idempotence-1000` completed `1000/1000` idempotence checks with zero property or execution failures. All 60 exported legacy-EH cases returned equal results; there were zero semantic mismatches.

## Performance

A 143,734-byte single-function benchmark with 10,000 copy/use groups used two warmups and nine measured runs. Starshine's traced pass-local pipeline median is `7.548 ms`; Binaryen's `BINARYEN_PASS_DEBUG=1` merge-locals median is `27.1409 ms`. Ratio: `0.278x` Binaryen time, about `3.60x` as fast.

Whole-command multi-function results remain codec dominated and are tracked under `[WALL]001`, not this pass-local closeout.

## Repository validation

- `moon info` and `moon fmt` pass.
- focused merge-locals tests pass `10/10`; focused profile tests pass `5/5`.
- `moon test src/passes` passes `6541/6541`; full native `moon test` passes `10054/10054`.
- direct wasm-gc check and tests pass; native `moon run src/fuzz -- all ci` passes every suite, including `86820` binary roundtrips.
- `bun validate readme-api-sync` passes.
- `bun validate full --profile ci --target wasm-gc` reproduced the repository's command-wrapper failure at its initial `moon info`. Running the stages directly reached the separately documented aggregate wasm-gc fuzz abort after Moon check/tests passed; the same full fuzz aggregate passes natively.
