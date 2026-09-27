---
kind: workflow
status: supported
last_reviewed: 2026-09-27
sources:
  - ../../../tooling/tracing-playbook.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
related:
  - ./index.md
  - ../simplify-locals/fuzzing.md
---

# `simplify-locals-notee-nostructure` fuzzing

## September 27 follow-up allocation campaign renewal

The [final follow-up report](../../../tooling/tracing-playbook.md#september-27-2026-follow-up-pass-allocation-campaign)
uses native CLI `6610a792ef8d07151ee38bd6c6fbfe82097086e4f50f6dfd3902eecacb00320e`,
verified Binaryen 133, seed `0x5eed`, eight subprocesses and 10,000 cases
per listed aggregate. It supersedes pending renewal for the follow-up
allocation changes and earlier current-baseline wording. New evidence
requires verified v133; older dated results retain their original scope.

| Lane | Aggregate | Canonical / cleanup matches | Residuals | Canonically larger | Star/original matches / blocked |
| --- | --- | ---: | ---: | ---: | ---: |
| `simplify-locals-notee-nostructure` | `simplify-locals-notee-nostructure-all` | 0 / 0 | 10,000 | 0 | 10,000 / 0 |

Validation, generator, property-counter, command and observed Starshine/
original semantic failures are zero. Blocked runtime cases remain unverified.
The report owns exact commands, normalizers, cache use, size-loss and retained
baseline replays, downstream evidence and agent classifications. Residual
parity/size gaps are not closed by validation or smaller output alone.

Local results: `.tmp/pass-perf-next-20260927/final-fuzz-simplify-locals-notee-nostructure/result.json`.

## September 26 final allocation/indexing renewal

The [final shared campaign](../../../tooling/tracing-playbook.md#september-26-2026-pass-time-allocation-and-indexing-renewal)
uses frozen native CLI `da5f112b6bbf092476d2d6ac6694128e19adca3d288003526ab01c3e0b0bfcbb`,
verified Binaryen 133 and 10,000 cases per documented aggregate at seed `0x5eed`.
The shared record owns exact commands, profiles, normalizers, cache counts,
runtime limits and baseline replays. This supersedes earlier current-baseline
wording; historical v131/v132 results keep their original scope.

| Lane | Canonical / cleanup matches | Residuals | Canonically larger | Star/original matches / blocked |
| --- | ---: | ---: | ---: | ---: |
| `simplify-locals-notee-nostructure` | 0 / 0 | 10,000 | 0 | 10,000 / 0 |

All listed lanes report zero validation, generator or command failures and no
observed Starshine/original semantic mismatches. Cases blocked on the original
input remain unverified.
Residuals remain open parity gaps; canonically larger outputs remain quality
gaps even when cleanup normalization matches. Valid or smaller output alone is not an accepted win. Saved residuals and all canonically larger
cases reproduce the starting compiler bytes, as recorded in the shared replay.

Local reports: `.tmp/pass-perf-work-20260926/final4-fuzz-simplify-locals-notee-nostructure/result.json`.

Node cannot execute the Binaryen output in 1,875 of the Starshine/original
matches above. The shared audit classifies these as runtime coverage gaps,
not observed wrong results or full three-way agreement.

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

## Binaryen-v131 closeout

The dedicated aggregate profile is `simplify-locals-notee-nostructure`. The refreshed closeout command used seed `0x5eed`, official Binaryen v131, and the explicit native Starshine release binary:

```text
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass simplify-locals-notee-nostructure \
  --gen-valid-profile simplify-locals-notee-nostructure \
  --out-dir .tmp/pass-fuzz-simplify-locals-notee-nostructure-v131-refresh-20260727-10000 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt
```

Result:

- compared: `10000/10000`;
- exact normalized matches: `2766`;
- structural differences: `7234`, every one strictly smaller for Starshine by `10–54` canonical wasm bytes;
- validation, property, generator, and command failures: `0`;
- profile leaf coverage: local traffic `3530`, structure result `3557`, effect order `1455`, stress `1458`.

The separate `1000`-case seed-`0x1d3a` idempotence lane is `1000/1000` with zero property failures. No parity gap, unknown/risky family, validation failure, or size-losing result remains.
