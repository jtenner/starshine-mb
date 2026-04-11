# `0078` Health Rerun: Pass Fuzz Smoke on Active Binaryen Ports

## Scope

- Rerun focused smoke parity for:
  - `reorder-locals`
  - `heap2local`
  - `remove-unused-module-elements`
- Track failures against current local `wasm-opt` (`version_129`) behavior.

## Commands

- `bun scripts/pass-fuzz-compare.ts --pass reorder-locals --count 200 --seed 0x5eed --max-failures 5 --out-dir /tmp/health-reorder-locals-both-2026-04-11-smoke`
- `bun scripts/pass-fuzz-compare.ts --pass reorder-locals --generator gen-valid --count 200 --seed 0x5eed --max-failures 5 --out-dir /tmp/health-reorder-locals-genvalid-2026-04-11-smoke`
- `bun scripts/pass-fuzz-compare.ts --pass heap2local --count 200 --seed 0x5eed --max-failures 20 --out-dir /tmp/health-heap2local-200-2026-04-11-smoke`
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --count 200 --seed 0x5eed --max-failures 20 --out-dir /tmp/health-rume-200-2026-04-11-smoke`

## Results

- `reorder-locals` (`both`): `199 / 200` compared, `198` normalized matches, `1` mismatch, `1` command failure (`binaryen-rec-group-zero`, case `000029-wasm-smith`).
- `reorder-locals` (`gen-valid`): `199 / 200` compared, `199` normalized matches, `0` command failures, `1` mismatch.
- `heap2local`: `199 / 200` compared, `199` normalized matches, `1` command failure (`binaryen-rec-group-zero`, case `000029-wasm-smith`), `0` mismatches.
- `remove-unused-module-elements`: `199 / 200` compared, `199` normalized matches, `1` command failure (`binaryen-rec-group-zero`, case `000029-wasm-smith`), `0` mismatches.

## Mismatch Interpretation

- `reorder-locals` mismatch in `case-000150-gen-valid` is still the same local-index swap on dead locals seen in prior runs and remains behaviorally equivalent in direct runtime probes:
  - `wasmtime --invoke main` on both outputs returns `0`.

## Conclusion

- The fresh `2026-04-11` health rerun remains consistent with current parity framing:
  - one clean `reorder-locals` behavioral mismatch class (non-semantic evidence pending)
  - `binaryen-rec-group-zero` command failure class for all three passes in at least one smith case
  - no new semantic mismatches observed in this 200-case smoke band.
