---
kind: workflow
status: supported
last_reviewed: 2026-07-18
sources:
  - ./index.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `reorder-locals` Fuzzing Profile

Dedicated GenValid aggregate: `reorder-locals-all`. It selects among:

- `reorder-locals-hot-sort` for high-index hot locals, repeated access counts, first-use ties, and tee coverage;
- `reorder-locals-unused-trim` for unused suffix trimming plus write-only/accessed local survival;
- `reorder-locals-name-repair` for local-name remap and raw-name-payload invalidation coverage.

Recommended direct lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass reorder-locals --gen-valid-profile reorder-locals-all --out-dir .tmp/pass-fuzz-reorder-locals-genvalid-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

O4Z closeout lanes from 2026-07-02:

| Lane | Result |
| --- | --- |
| Dedicated `reorder-locals-all` GenValid | `10000/10000` compared, `10000` normalized matches, zero failures. |
| Ordinary GenValid | `10000/10000` compared, `10000` normalized matches, zero failures. |
| `random-all-profiles` GenValid | `10000/10000` compared, `10000` normalized matches, zero failures. |
| External `wasm-smith` with `--normalize unreachable-control-debris` | `9956/10000` compared, `9955` raw normalized matches, `1` compare-normalized unreachable/control-debris case, zero remaining mismatches, `44` Binaryen/oracle command failures. |

The external raw residual was `case-009332-wasm-smith`, where Binaryen dropped unreachable-control debris unrelated to the local reorder contract. The normalized lane is the signoff record for that generator family.

Replay and triage notes:

- Use the manifest `config_label` and `selected_profile` fields for dedicated aggregate repros.
- No `--require-feature` floor is required for the dedicated aggregate; every leaf constructs the relevant local-table shape directly.
- Do not treat extra upstream preset slots as implied by the dedicated profile. Starshine still claims one public tuple/no-structure scheduler slot until `[O4Z-PRESET-BEHAVIOR]` supplies ordered-neighborhood evidence.
