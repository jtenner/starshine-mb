# Fuzz Migration Plan

Last updated: 2026-03-12

## [x] 1) Objective And Scope
- [x] This section is documented.

Move fuzz-heavy and randomized stress coverage out of the default `moon test` path and into a dedicated runnable binary so normal validation/unit test cycles are faster.

In scope:
- Move current fuzz-style tests from primary test suite into reusable fuzz runners.
- Add a new main package at `src/fuzz` that can run targeted or full fuzz workloads.
- Keep deterministic correctness tests in package-local `*_test.mbt` files.
- Split CI so fuzzing runs in a dedicated lane (not in default PR test lane).

Out of scope:
- Changing optimization/validator semantics.
- Rewriting existing fuzz generators beyond minimal extraction needed for reuse.

## [x] 2) Current Fuzz Inventory (Source Of Truth)
- [x] This section is documented.

Current fuzz/randomized workloads identified:

1. WAST/WAT parser-printer fuzz loops
- `src/wast/fuzz_tests.mbt`
- `src/wat/fuzz_tests.mbt`
- Random `Arbitrary` generated modules/scripts with roundtrip stability checks.

2. Validator valid-module generation fuzz
- `src/validate/validate.mbt` (`test "Fuzz Modules"`, index `0`)
- `gen_valid_module` loop (100000 iterations).

3. Validator invalidation fuzz
- `src/validate/invalid_fuzzer.mbt` (`test "invalidation fuzzing with coverage"`, index `0`)
- Applies invalidation strategies and checks rejection-rate thresholds.

4. End-to-end wasm-smith harness fuzz
- `src/cmd/fuzz_harness.mbt`
- `src/cmd/fuzz_harness_test.mbt` (smoke + native 100k run + differential hooks).

5. Binary codec arbitrary roundtrip stress
- `src/binary/tests.mbt`
- Large `Arbitrary` loops over sections, instructions, module, numerics, etc.

## [x] 3) Target End State
- [x] This section is documented.

Add a dedicated package:
- `src/fuzz/moon.pkg` (`options("is-main": true)`).
- `src/fuzz/main.mbt` (CLI dispatcher).

Design goals:
- `moon test` remains deterministic and relatively fast.
- Fuzz runs are explicitly invoked via `moon run src/fuzz ...`.
- Reproducibility is first-class (`seed`, suite name, profile printed).
- Failure exits non-zero with enough info to rerun.

Suggested profiles:
- `smoke`: local quick check.
- `ci`: moderate but meaningful.
- `stress`: long runtime (e.g. current 100k-style workloads).

## [x] 4) CLI Design For `src/fuzz`
- [x] This section is documented.

Proposed invocation patterns:

```bash
# Run everything with smoke settings
moon run src/fuzz all smoke

# Run one suite with explicit seed
moon run src/fuzz validate-valid ci 0x5eed

# Native-only stress cases
moon run --target native src/fuzz cmd-harness stress 0x5eed5eed
```

Proposed suites:
- `all`
- `wast-roundtrip`
- `wat-roundtrip`
- `validate-valid`
- `validate-invalid`
- `binary-roundtrip`
- `cmd-harness`

Recommended output contract (single-line summary per suite):
- suite, profile, seed, attempts, pass/fail, elapsed_ms.

## [x] 5) Migration Work Packages (Split-Friendly)
- [x] This section is documented.

### Package A: Fuzz binary scaffold
- [ ] Create `src/fuzz/moon.pkg` importing required packages.
- [ ] Add `src/fuzz/main.mbt` argument parsing and suite dispatch.
- [ ] Add shared stats/result structs for consistent printing.
- [ ] Add exit behavior (`abort`/`fail`) on first failing suite.

### Package B: Extract reusable fuzz runners
- [ ] `src/wast`: expose `run_wast_roundtrip_fuzz(profile, seed)` function.
- [ ] `src/wat`: expose `run_wat_roundtrip_fuzz(profile, seed)` function.
- [ ] `src/validate`: expose `run_validate_valid_fuzz(profile, seed)` function.
- [ ] `src/validate`: expose `run_validate_invalid_fuzz(profile, seed)` function.
- [ ] `src/binary`: expose `run_binary_roundtrip_fuzz(profile, seed)` function.
- [ ] `src/cmd`: expose/extend `run_wasm_smith_fuzz_harness` profile adapters.

### Package C: Remove fuzz loops from default `moon test`
- [ ] Remove heavy fuzz `test` blocks from:
  - `src/validate/validate.mbt` (`Fuzz Modules`)
  - `src/validate/invalid_fuzzer.mbt` (`invalidation fuzzing with coverage`)
  - `src/wast/fuzz_tests.mbt` (randomized loops)
  - `src/wat/fuzz_tests.mbt` (randomized loops)
  - `src/binary/tests.mbt` (high-iteration arbitrary stress)
  - `src/cmd/fuzz_harness_test.mbt` (harness fuzz loops)
- [ ] Keep deterministic API/unit assertions so behavior remains covered.

### Package D: CI and scripts
- [ ] Keep existing PR lane: `moon test`.
- [ ] Add fuzz lane command:
  - `moon run src/fuzz all ci`
- [ ] Add optional scheduled stress lane:
  - `moon run --target native src/fuzz all stress`
- [ ] Add helper script `scripts/run-fuzz.sh`.

### Package E: Documentation + onboarding
- [ ] Update `README.mbt.md` with new fuzz commands and profile definitions.
- [ ] Note that default `moon test` intentionally excludes stress fuzzing.
- [ ] Add reproduction instructions using suite/profile/seed.

## [x] 6) Detailed Implementation Steps
- [x] This section is documented.

1. Add `src/fuzz/moon.pkg`.
- Include imports: `cmd`, `validate`, `wast`, `wat`, `binary`, `lib`, and `splitmix` as needed.
- Set `"is-main": true`.

2. Implement `src/fuzz/main.mbt`.
- Parse args as `(suite, profile, seed?)` with defaults.
- Normalize seed parsing for decimal or hex forms.
- Route to suite-specific runner functions.
- Print summary lines and return non-zero failure on any error.

3. Extract runners from tests (without behavior changes).
- Copy existing fuzz loop logic from tests into package-level functions.
- Keep existing thresholds/ratios first; only tune counts through profile multipliers.
- Ensure each runner can be invoked independently and returns `Result`.

4. Replace heavy test blocks with deterministic coverage tests.
- Keep API shape tests, error message tests, and minimal smoke where needed.
- Do not keep long loops in default suite.

5. Wire profile counts centrally.
- Example: `smoke=small`, `ci=medium`, `stress=current-or-higher`.
- Use one shared mapping to avoid drift between suites.

6. Update CI and scripts.
- Introduce fuzz job using `moon run src/fuzz`.
- Keep `moon` commands sequential in scripts to avoid `_build/.moon-lock` contention.

7. Run verification sequence.
- `moon info && moon fmt`
- `moon test`
- `moon run src/fuzz all smoke`
- `moon run src/fuzz all ci`
- Native (optional/scheduled): `moon run --target native src/fuzz all stress`

## [x] 7) Acceptance Criteria
- [x] This section is documented.

- [ ] Default `moon test` no longer executes heavy fuzz loops.
- [ ] All prior fuzz families are runnable via `moon run src/fuzz ...`.
- [ ] Fuzz binary prints seed/profile/suite for reproducibility.
- [ ] CI has separate fuzz lane(s).
- [ ] README documents new operational flow.
- [ ] Measured wall-time improvement for default `moon test` is recorded.

## [x] 8) Risks And Mitigations
- [x] This section is documented.

Risk: coverage regression if fuzz tests are removed before runners exist.
- Mitigation: extract runners first, then delete heavy `test` blocks.

Risk: profile drift across suites.
- Mitigation: centralize profile-to-iteration mapping in `src/fuzz/main.mbt` or shared helper.

Risk: native-only fuzz behavior divergence.
- Mitigation: keep explicit native lane and document target requirements.

Risk: lock contention in automation.
- Mitigation: keep moon commands sequential.

## [x] 9) Suggested Commit Plan
- [x] This section is documented.

1. `feat(fuzz): add src/fuzz runner scaffold and CLI`
2. `refactor(fuzz): extract reusable fuzz runners from package tests`
3. `test: remove heavy fuzz loops from default moon test suite`
4. `ci: add dedicated fuzz lane and optional native stress lane`
5. `docs: document fuzz workflow and reproduction commands`

