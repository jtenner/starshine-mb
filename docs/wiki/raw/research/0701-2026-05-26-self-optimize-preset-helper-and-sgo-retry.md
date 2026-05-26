# Self-optimize preset helper and SGO retry

Date: 2026-05-26
Slice: `[SGO]005` / compare-tooling unblocker

## Context

The previous `[SGO]005` full parity signoff attempt (`0700`) could not reach the v0.1.0 optimize-path comparison because `scripts/self-optimize-compare.ts` rejected preset flags such as `--optimize` before invoking either tool.

This run kept `[SGO]005` as the active slice and addressed that helper blocker before trying the full optimize replay again.

## Change

`self-optimize-compare` now accepts public preset flags for artifact comparison:

- Starshine `--optimize` is passed through to Starshine and mapped to Binaryen `-O`.
- Starshine `--shrink` is passed through to Starshine and mapped to Binaryen `-Os`.
- Binaryen-style `-O` and `-Os` are accepted as inputs and normalized to Starshine `--optimize` / `--shrink` respectively.
- Numeric presets such as `-O2` remain rejected by this helper until a Starshine-equivalent public mode is needed and tested.

A focused script test was added to prove `--optimize` invokes Starshine with `--optimize` and Binaryen with `-O`.

## Validation and retry evidence

Focused helper validation passed:

```sh
bun scripts/test/self-optimize-compare-command.ts
```

A direct SGO artifact rerun still shows the same open pass-local runtime gap:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --simplify-globals-optimizing --out-dir .tmp/sgo005-direct-rerun-20260526 --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Result: canonical comparison still differs first at `defined=55 abs=76`, the same representation-only default-local/carrier family described in `0700`; pass-local timing remained over the 2x floor (`248.050ms` Starshine vs `112.609ms` Binaryen).

The full optimize-path helper no longer rejects the preset flag, but the replay did not complete within a 300s cron-safe timeout:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --optimize --out-dir .tmp/sgo005-optimize-helper-20260526 --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Result: timed out after 300 seconds before writing compare artifacts. This confirms the prior helper rejection is fixed and the remaining full-preset blocker has moved back to the known `[WALL]001` optimize-path runtime/attribution problem rather than an argument-parsing blocker.

## Current classification

- Helper rejection: fixed.
- Direct artifact first diff: agent-classified as representation-only default-local/carrier drift, unchanged from `0700`; not a semantic mismatch or validation failure.
- Direct SGO artifact pass-local runtime: still an active `[SGO]005` blocker because it is slightly over the repo 2x floor.
- Full optimize-path comparison: still blocked by whole-command/preset runtime timeout; use `[WALL]001` evidence before expecting the full `--optimize` helper run to complete.

## Follow-up

Keep `[SGO]005` active. Next work should either reduce/accept the direct and late-tail SGO pass-local runtime gap, or make enough `[WALL]001` progress that the full `--optimize` self-compare can complete and classify final optimize-path diffs.
