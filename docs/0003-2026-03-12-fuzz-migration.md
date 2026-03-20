# Fuzz Migration Plan

Status: completed migration to a dedicated runnable fuzz package.

## Objective
Move fuzz-heavy workloads out of `moon test` and into `moon run src/fuzz ...` so regular test runs stay deterministic and fast.

## Completed Work
- Added `src/fuzz/moon.pkg` (main package) and `src/fuzz/main.mbt`.
- Extracted fuzz runners from package tests into package-level functions:
  - WAST/WAT roundtrip
  - valid-module / invalid-module validation
  - binary roundtrip
  - `cmd` wasm-smith harness
- Removed heavy randomized loops from default `moon test`.
- Added runner CLI (`suite`, `profile`, `--seed`) and list/sum commands.
- Captured reproducibility requirements in logs (`suite`, `profile`, `seed`).

## Scope
- In-scope: deterministic tests remain in package-local test suites.
- Out-of-scope: changing optimization/validation semantics.

## Current Targeting
- Profile ladder: `smoke`, `ci`, `stress`.
- Suites now launched via:
  - `moon run src/fuzz all smoke`
  - `moon run src/fuzz -- validate-valid ci`

## Suggested CI Split
- PR/normal lane: `moon test` (deterministic only).
- Separate fuzz lanes:
  - `moon run src/fuzz all ci`
  - optional `moon run --target native src/fuzz all stress`

## Risks and Mitigations
- Coverage regressions if fuzz removed too early → extract runners first, keep deterministic tests.
- Profile drift → centralize profile-to-iteration mapping in one place.
- Native lane divergence → explicit native target in CI and docs.
- lock contention → keep moon commands sequential.

## Acceptance
- All heavy fuzz scenarios moved to `src/fuzz`.
- Deterministic suites still run in `moon test`.
- Reproducible rerun command is documented.
- `bun validate`/`moon test` path remains green.
