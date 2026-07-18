---
kind: workflow
status: working
last_reviewed: 2026-07-18
sources:
  - ../../../raw/research/1574-2026-07-18-precompute-binaryen-v131-parity-reopen.md
  - ../../../raw/research/1573-2026-07-18-precompute-returned-values-arrays-and-effect-retention.md
  - ../../../raw/research/1572-2026-07-17-precompute-propagate-port-and-signoff.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_precompute_propagate_tests.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../precompute/fuzzing.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `precompute-propagate` fuzzing

## Current state

The direct lane is active and maps the exact Starshine public name to Binaryen `version_131`'s `--precompute-propagate`.

Use the rebuilt native CLI:

```sh
moon build --target native --release src/cmd
```

For ordinary comparisons, preserve the inherited plain-precompute normalizers:

```text
--normalize drop-consts
--normalize local-cleanup-debris
--normalize unreachable-control-debris
```

They classify already reviewed dropped-constant, local-cleanup, and unreachable/control debris without hiding validation or command failures.

## Dedicated profile

Stable profile name:

```text
precompute-propagate-local-facts
```

Compatibility aliases `precompute-propagate` and `precompute-propagate-closeout` select the broader `precompute-all` aggregate so shared evaluator coverage cannot silently disappear. Use the exact `precompute-propagate-local-facts` name when only local-consensus generation is wanted.

The aggregate adds returned scalar, fresh immutable aggregate, and effect-retention leaves to the local-facts and historical plain-precompute leaves.

Each generated module includes:

- agreeing branch-local constants;
- a differing-definition bailout;
- a defaultable-local entry read;
- direct and block-fallthrough tees;
- a bounded chained propagation/evaluation shape;
- a parameter/nonconstant boundary.

Focused tests in `src/validate/gen_valid_precompute_propagate_tests.mbt` prove stable lookup, profile limits, validation, and the intended trigger floor.

## Recommended development smoke

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 --seed 0x5eed \
  --pass precompute-propagate \
  --gen-valid-profile precompute-propagate-local-facts \
  --normalize drop-consts \
  --normalize local-cleanup-debris \
  --normalize unreachable-control-debris \
  --out-dir .tmp/pass-fuzz-precompute-propagate-smoke \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt \
  --max-failures 1000 --keep-going-after-command-failures
```

## Final 2026-07-18 v131 matrix

All final lanes use explicit `.tmp/binaryen-version-131-bin/bin/wasm-opt`, `_build/native/release/build/cmd/cmd.exe`, isolated cache `.tmp/pass-fuzz-cache-v131`, parallel workers, and the reviewed local/unreachable cleanup normalizers.

| Lane | Directory | Compared | Direct | Cleanup-normalized | Classified differences | Failures |
|---|---|---:|---:|---:|---:|---|
| Regular GenValid, seed `0x5eed` | `.tmp/pass-fuzz-precompute-propagate-v131-final-regular-100000` | `100000/100000` | `41287` | `58713` | `0` | none |
| Dedicated `precompute-all`, seed `0x5eed` | `.tmp/pass-fuzz-precompute-propagate-v131-final-dedicated-10000` | `10000/10000` | `7306` | `2694` | `0` | none |
| Random all profiles, seed `0x5555` | `.tmp/pass-fuzz-precompute-propagate-v131-final-random-all-10000` | `10000/10000` | `5076` | `2190` | `2734` smaller | none |
| wasm-smith, seed `0x5eed` | `.tmp/pass-fuzz-precompute-propagate-v131-final-wasm-smith-10000` | `9956/10000` | `9951` | `2` | `3` Starshine wins | `44` Binaryen tool failures |

All `2734` random-all differences are smaller by `2..18` bytes and save `33,282` bytes total. They occur only in `ssa-nomerge-smoke` (`920`), `ssa-nomerge-parity` (`916`), duplicate-function-import (`657`), and duplicate-nonfunction-import (`241`) leaves. The wasm-smith differences are a smaller exact scratch-local form, preservation of a reachable `atomic.fence`, and removal of nontrapping `memory.size` debris before `unreachable`.

Runtime/idempotence completed `500/500` with zero semantic/property/validation/command failures; unsupported Node GC/reference cases remain separately classified. Self-optimization validates and produces `4,581,251` canonical bytes versus Binaryen's `4,671,312`. One warmup plus 15 runs gives pass-local medians `1,042.358 ms` versus `525.378 ms`, ratio `1.984x`, inside the required `2x` ceiling.

## Historical 2026-07-18 v130 evaluator refresh

All refreshed lanes used Binaryen `version_130`, the explicit rebuilt native Starshine binary, parallel workers, the persistent cache, and the three normalizers above.

| Lane | Directory | Compared | Normalized | Cleanup-normalized | Mismatches | Failures |
|---|---|---:|---:|---:|---:|---|
| Regular GenValid, seed `0x5eed` | `.tmp/pass-fuzz-precompute-gap-close-final4-regular-10000` | `10000/10000` | `1915` | `8085` | `0` | none |
| Expanded aggregate, seed `0x5eed` | `.tmp/pass-fuzz-precompute-gap-close-final4-aggregate-10000` | `10000/10000` | `7306` | `2694` | `0` | none |
| Broad `pass-fuzz-stress`, seed `0x5555` | `.tmp/pass-fuzz-precompute-gap-close-final4-stress-10000` | `10000/10000` | `1921` | `8079` | `0` | none |
| wasm-smith, seed `0x5eed` | `.tmp/pass-fuzz-precompute-gap-close-final4-wasm-smith-10000` | `9956/10000` | `9951` | `3` | `2` | `44` Binaryen parser/tool failures |
| Random all profiles, seed `0x5555` | `.tmp/pass-fuzz-precompute-gap-close-final4-random-all-10000` | `10000/10000` | `4664` | `2602` | `2734` | none |

A separate aggregate runtime/idempotence lane at `.tmp/pass-fuzz-precompute-gap-close-final4-runtime-1000` completed `1000/1000` idempotence checks, runtime-checked `955` cases, reported `45` unsupported runtime cases, and found zero semantic mismatches or property failures. Expanded scalar and GC leaves each matched `100/100` exactly; the effectful leaf matched `100/100` after the reviewed local-cleanup normalizer.

All `2734` random-all raw differences are canonically smaller for Starshine: `920` `ssa-nomerge-smoke`, `916` `ssa-nomerge-parity`, `657` duplicate-function-import, and `241` duplicate-nonfunction-import cases. There are no equal-sized or Starshine-larger cases.

The two wasm-smith differences and `44` Binaryen tool failures are unchanged from July 17.

## Historical 2026-07-17 v130 closeout matrix

All final lanes used Binaryen `version_130`, the explicit current native Starshine binary, `--jobs auto`, the default persistent cache, and the three normalizers above.

| Lane | Directory | Compared | Normalized | Cleanup-normalized | Mismatches | Failures |
|---|---|---:|---:|---:|---:|---|
| Regular GenValid, seed `0x5eed` | `.tmp/pass-fuzz-precompute-propagate-gap-close-final4-genvalid-100000` | `100000/100000` | `19160` | `80840` | `0` | none |
| Dedicated profile, seed `0x5eed` | `.tmp/pass-fuzz-precompute-propagate-gap-close-final3-profile-10000` | `10000/10000` | `0` | `10000` | `0` | none |
| Broad `pass-fuzz-stress`, seed `0x5555` | `.tmp/pass-fuzz-precompute-propagate-gap-close-final4-stress-10000` | `10000/10000` | `1921` | `8079` | `0` | none |
| wasm-smith, seed `0x5eed` | `.tmp/pass-fuzz-precompute-propagate-gap-close-final4-wasm-smith-10000` | `9956/10000` | `9951` | `3` | `2` | `44` Binaryen parser/tool failures |
| Random all profiles, seed `0x5555` | `.tmp/pass-fuzz-precompute-propagate-gap-close-final3-random-all-10000` | `10000/10000` | `4175` | `2852` | `2973` | none |

The wasm-smith command-failure classes were:

- `39` zero-sized rec-group failures;
- `1` invalid tag index;
- `1` table index out of range;
- `3` bad section size.

The two raw mismatches are agent-classified, not harness-proven:

1. `case-003694-wasm-smith`: exact scratch-local replay with a smaller Starshine canonical output (`74` versus `81` bytes).
2. `case-006523-wasm-smith`: the inherited plain-precompute correctness boundary where Starshine preserves a reachable `atomic.fence` that Binaryen erases before a branch-to-end.

See the retained closeout note for full rationale and artifacts.

## Historical v130 random-all classification

The completed `random-all-profiles` lane has `2973` raw mismatches and no failures. Agent-side canonical size classification found:

- `2973` Starshine-smaller cases;
- `0` equal-sized differing cases;
- `0` Starshine-larger cases.

The families are `ssa-nomerge-smoke` (`965`), `ssa-nomerge-parity` (`945`), duplicate-function-import elimination (`546`), and duplicate-nonfunction-import elimination (`517`). The differences are retained Starshine wins: stronger dead read/control cleanup or smaller import-preserving output. This lane closes the earlier size-losing coverage/atomic and evaluator-breadth families; do not regress Starshine merely to force textual Binaryen parity.

## Reporting rule

Report separately:

- requested and compared counts;
- normalized and cleanup-normalized matches;
- raw mismatches with agent classification;
- validation/generator/property failures;
- command-failure classes;
- cache hit/miss counters;
- exact Binaryen executable/version;
- any inherited plain-precompute boundary rather than relabeling it as propagation parity.
