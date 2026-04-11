# `0079` Health Rerun: focused pass-fuzz validation + external oracle check

## Scope

- run a second pass-fuzz round on additional Binaryen ports using the same `000x` health pattern
- keep results anchored to `version_129` in the local `pass-fuzz` harness and Binaryen’s upstream release page
- resolve any contradictions against existing wiki parity status

## Sources

- Binaryen releases page: `https://github.com/webassembly/binaryen/releases` (shows `version_129` as latest, dated 01 Apr 2026).
- `/tmp/health-dfe-200-2026-04-11-smoke`
- `/tmp/health-pick-load-signs-200-2026-04-11-smoke`
- `/tmp/health-rub-200-2026-04-11-smoke`
- `/tmp/health-rub-200-genvalid-2026-04-11-smoke`
- `/tmp/health-tuple-200-2026-04-11-smoke`
- `/tmp/health-dfe-200-genvalid-2026-04-11-smoke`
- `/tmp/health-pick-load-signs-200-genvalid-2026-04-11-smoke`
- `/tmp/health-tuple-200-genvalid-2026-04-11-smoke`

## Commands

- `bun scripts/pass-fuzz-compare.ts --pass duplicate-function-elimination --count 200 --seed 0x5eed --max-failures 30 --out-dir /tmp/health-dfe-200-2026-04-11-smoke`
- `bun scripts/pass-fuzz-compare.ts --pass duplicate-function-elimination --generator gen-valid --count 200 --seed 0x5eed --out-dir /tmp/health-dfe-200-genvalid-2026-04-11-smoke`
- `bun scripts/pass-fuzz-compare.ts --pass pick-load-signs --count 200 --seed 0x5eed --max-failures 30 --out-dir /tmp/health-pick-load-signs-200-2026-04-11-smoke`
- `bun scripts/pass-fuzz-compare.ts --pass pick-load-signs --generator gen-valid --count 200 --seed 0x5eed --out-dir /tmp/health-pick-load-signs-200-genvalid-2026-04-11-smoke`
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --count 200 --seed 0x5eed --max-failures 30 --out-dir /tmp/health-rub-200-2026-04-11-smoke`
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator gen-valid --count 200 --seed 0x5eed --max-failures 30 --out-dir /tmp/health-rub-200-genvalid-2026-04-11-smoke`
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --count 200 --seed 0x5eed --max-failures 30 --out-dir /tmp/health-tuple-200-2026-04-11-smoke`
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 200 --seed 0x5eed --out-dir /tmp/health-tuple-200-genvalid-2026-04-11-smoke`

## Results

- `duplicate-function-elimination` (`both`, count 200): `199 / 199` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `1` command failure (`binaryen-rec-group-zero`).
- `duplicate-function-elimination` (`gen-valid`, count 200): `200 / 200` compared, `200` normalized matches, `0` mismatches, `0` validation failures, `0` command failures.
- `pick-load-signs` (`both`, count 200): `199 / 199` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `1` command failure (`binaryen-rec-group-zero`).
- `pick-load-signs` (`gen-valid`, count 200): `200 / 200` compared, `200` normalized matches, `0` mismatches, `0` validation failures, `0` command failures.
- `remove-unused-brs` (`both`, count 200): `199 / 199` compared, `175` normalized matches, `24` mismatches, `0` validation failures, `1` command failure (`binaryen-rec-group-zero`).
- `remove-unused-brs` (`gen-valid`, count 200): `114 / 114` compared, `84` normalized matches, `30` mismatches, `0` validation failures, `0` command failures, `maxFailuresHit: true`.
- `tuple-optimization` (`both`, count 200): `199 / 199` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `1` command failure (`binaryen-rec-group-zero`).
- `tuple-optimization` (`gen-valid`, count 200): `200 / 200` compared, `200` normalized matches, `0` mismatches, `0` validation failures, `0` command failures.

## Interpretation

- Binaryen remains at `version_129` in upstream release state.
- The same parser-family failure (`binaryen-rec-group-zero`) still appears in mixed passes at `case-000029-wasm-smith`.
- `remove-unused-brs` still shows concrete normalization mismatches in this smoke band (both mixed and gen-valid subsets), so its parity status should remain explicitly open until those cases are narrowed into canonical reduced artifacts.
- `pick-load-signs`, `duplicate-function-elimination`, and `tuple-optimization` remain clean for this band, with only the expected parser-gap command failure on mixed runs.

## Follow-up

- Keep `remove-unused-brs` mismatch set in a dedicated reduced repro queue and classify each family before claiming broader pass stability.
- Keep health rerun evidence linked from parity pages as long-lived signoff context.
