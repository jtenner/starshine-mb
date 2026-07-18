---
kind: workflow
status: supported
last_reviewed: 2026-07-18
sources:
  - ../../../raw/binaryen/2026-07-06-duplicate-import-elimination-v130-current-refresh.md
  - ./index.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `duplicate-import-elimination` Fuzzing Profile

Recommended smoke lane: run the ordinary GenValid compare-pass lane for this pass:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass duplicate-import-elimination --out-dir .tmp/pass-fuzz-duplicate-import-elimination --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Dedicated GenValid profile: use `--gen-valid-profile duplicate-import-elimination` for the ordinary closeout lane. It is an aggregate over:

- `duplicate-import-elimination-functions` (`75%` weight): duplicate function-import aliases with the same `(module, base)`, a mixed-signature first representative that exercises the Binaryen v130 representative reset rule, and users through `call`, `ref.func`, declarative element contents, function export, start, and module code.
- `duplicate-import-elimination-nonfunction` (`25%` weight): duplicate nonfunction imports, currently duplicate immutable globals, that must remain untouched because the source-confirmed Binaryen v130/main contract is function-import-only.

The profile also records manifest triage labels: `selected_profile` is the chosen leaf and `profile_case_label` is either `duplicate-import-elimination:functions` or `duplicate-import-elimination:nonfunction-negative`.

2026-07-06 dedicated profile closeout lane completed as part of the final direct-pass matrix:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass duplicate-import-elimination --gen-valid-profile duplicate-import-elimination --out-dir .tmp/pass-fuzz-die-genvalid-duplicate-import-elimination-10000-20260706 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: requested `10000`, compared `10000`, normalized matches `10000`, cleanup-normalized matches `0`, raw mismatches `0`, validation/property/generator/command failures `0`; cache wasm-smith `0/0`, Binaryen `10000` hits / `0` misses, Binaryen failures `0/0`. Selected profile counts were `duplicate-import-elimination-functions=7500` and `duplicate-import-elimination-nonfunction=2500`; profile case counts were `duplicate-import-elimination:functions=7500` and `duplicate-import-elimination:nonfunction-negative=2500`. Agent classification: behavior-parity match for the dedicated profile lane.

2026-07-06 final direct-pass closeout matrix is now complete with the current `_build/native/release/build/cmd/cmd.exe` and `--jobs auto`:

| Lane | Seed | Out dir | Requested / compared | Normalized | Cleanup-normalized | Raw mismatches | Failures / command classes | Cache |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| regular GenValid | `0x5eed` | `.tmp/pass-fuzz-die-genvalid-100000-20260706` | `100000 / 100000` | `100000` | `0` | `0` | validation/property/generator/command `0` | wasm-smith `0/0`; Binaryen `1315/98685`; Binaryen failures `0/0` |
| explicit wasm-smith, unnormalized required run | `0x5eed` | `.tmp/pass-fuzz-die-wasm-smith-10000-20260706` | `10000 / 9956` | `9955` | `0` | `1` | validation/property/generator `0`; command `44`: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3` | wasm-smith `10000/0`; Binaryen `106/9850`; Binaryen failures `0/44` |
| explicit wasm-smith, classification confirmation with `--normalize unreachable-control-debris` | `0x5eed` | `.tmp/pass-fuzz-die-wasm-smith-10000-unreachable-normalized-20260706` | `10000 / 9956` | `9955` | `1` | `0` | same 44 Binaryen/tool command failures | wasm-smith `10000/0`; Binaryen `9956/0`; Binaryen failures `44/0` |
| dedicated GenValid profile `duplicate-import-elimination` | `0x5eed` | `.tmp/pass-fuzz-die-genvalid-duplicate-import-elimination-10000-20260706` | `10000 / 10000` | `10000` | `0` | `0` | validation/property/generator/command `0` | wasm-smith `0/0`; Binaryen `10000/0`; Binaryen failures `0/0` |
| random all-profiles GenValid | `0x5555` | `.tmp/pass-fuzz-die-random-all-profiles-10000-20260706` | `10000 / 10000` | `10000` | `0` | `0` | validation/property/generator/command `0` | wasm-smith `0/0`; Binaryen `4725/5275`; Binaryen failures `0/0` |

Agent classification for the single unnormalized wasm-smith raw mismatch: semantic-safe unreachable-control-debris representation drift unrelated to DIE. The input had no duplicate function imports; Binaryen normalized an unreachable tail to `drop(memory.size); drop(f64.const); unreachable`, while Starshine emitted the same prefix plus `drop(unreachable); unreachable`. Both paths trap before any later observable value, and rerunning the same lane with the existing `unreachable-control-debris` normalizer moved that one case to `cleanupNormalizedMatchCount=1` with zero remaining mismatches.

Selected profile counts:

- regular GenValid: `binaryen-oracle-portable=100000`.
- dedicated DIE profile: `duplicate-import-elimination-functions=7500`, `duplicate-import-elimination-nonfunction=2500`; profile case labels `duplicate-import-elimination:functions=7500`, `duplicate-import-elimination:nonfunction-negative=2500`.
- random all-profiles: `local-subtyping-structured=549`, `coverage-forced-portable=1102`, `duplicate-import-elimination-functions=800`, `coalesce-locals-straight-line=438`, `heap2local-struct=484`, `ssa-nomerge-smoke=1154`, `ssa-nomerge-parity=1126`, `pass-fuzz-stress=1117`, `binaryen-oracle-portable=1148`, `heap2local-ref=308`, `local-subtyping-straight-line=551`, `heap2local-array=295`, `coalesce-locals-structured=322`, `duplicate-import-elimination-nonfunction=274`, `coalesce-locals-loop-copy-through=332`; DIE profile case labels `duplicate-import-elimination:functions=800`, `duplicate-import-elimination:nonfunction-negative=274`.

Conclusion: `[O4Z-AUDIT-DIE]` is closed for direct `--pass duplicate-import-elimination` Binaryen behavior parity under the source-confirmed `version_130` contract. Reopen if current Binaryen widens DIE beyond function imports, if a required fuzz lane develops unclassified semantic drift or Starshine validation/command failures, or if the timing fixtures in the strategy page regress above Binaryen median.
