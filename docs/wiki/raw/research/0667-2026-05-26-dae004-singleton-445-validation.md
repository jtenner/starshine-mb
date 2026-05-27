# DAE004 singleton 445 artifact validation

Date: 2026-05-26

## Scope

This note closes `[DAE004-D5]` and the post-validation bookkeeping part of `[DAE004-D6]` for the first selected dropped-result singleton removal. Research note `0666` removed implementation fallback entry `445`; this run validated that removal on the debug artifact and refreshed direct compare evidence.

## Commands and evidence

- Artifact replay:
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/dae004-d5-singleton445-validation-20260526 --timing-only --dae-optimizing`
  - Result: output artifacts were written successfully. Starshine pass-local time was `1575.557ms`; Binaryen pass-local time was `850.194ms`. The ratio stays inside the DAE target because `1575.557 <= 2 * 850.194`.
  - Whole command time was `1943.532ms` Starshine versus `1140.276ms` Binaryen; this was not the pass-local acceptance metric for DAE004-D5.
- Output validation:
  - `wasm-opt --all-features .tmp/dae004-d5-singleton445-validation-20260526/starshine.wasm -o /tmp/dae004-d5-validated.wasm`
  - Result: passed, with only the existing large-local-count VM warning for function 518.
- Direct compare refresh:
  - `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae004-d5-singleton445-20260526`
  - Result: `45/10000` compared before the known max-failure threshold, `26` normalized matches, `19` normalized mismatches, `0` validation failures, `0` generator failures, and `1` Binaryen/tool command failure (`binaryen-rec-group-zero`).

## Mismatch classification

Agent judgment: the direct compare refresh did not introduce a new DAE004 semantic or validation regression. The `19` mismatches are the already-accepted `gen-valid` raw-cleanup family where Starshine strips leading dropped pure/nontrapping debris that Binaryen preserves; the only non-`gen-valid` saved failure was `case-000029-wasm-smith`, a Binaryen parser/tool failure (`Recursion groups of size zero not supported`), not a Starshine semantic mismatch.

## Decision

- `[DAE004-D5]` is closed for singleton `445`: the debug-artifact output validates, pass-local timing remains within `Starshine <= 2x Binaryen`, and the direct compare refresh shows no new semantic or validation regression.
- `[DAE004-D6]` is closed for singleton `445`: entry `445` was already removed by note `0666`, and this validation confirms it can stay removed. The remaining selected fallback entries continue under `[DAE004-D7]`.
