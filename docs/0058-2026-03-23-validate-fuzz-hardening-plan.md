# Validator Fuzz Hardening Plan

Status: research pass only. No implementation in this change.

## Scope
- Audit the current validator fuzz lanes:
  - `src/validate/validate.mbt` `run_validate_valid_fuzz`
  - `src/validate/invalid_fuzzer.mbt` `run_validate_invalid_fuzz`
- Identify:
  - correctness bugs in the fuzzers themselves
  - code smells that make the lanes hard to trust or extend
  - missing feature work that would materially improve fuzzing depth
  - concrete validation gaps versus the validator surface already present in this repo
- Keep the recommendations compatible with the existing fuzz migration in [docs/0003-2026-03-12-fuzz-migration.md](./0003-2026-03-12-fuzz-migration.md): heavy workloads stay in `src/fuzz`, not `moon test`.

## Current Behavior
- `run_validate_valid_fuzz` lowercases the profile, generates modules with `gen_valid_module`, and only asserts that `validate_module` accepts them.
- `run_validate_invalid_fuzz` generates valid modules, applies a fixed list of 22 mutation strategies, and treats any validator rejection as success.
- `gen_valid_module` currently biases heavily toward mutation applicability:
  - always adds memory
  - always adds a table
  - always adds a start function
  - always adds at least one tag
  - never adds imports
  - never adds exports
  - uses a single `i32` memory and a single `funcref` table
  - builds only plain `SubType::comp_type(...)` entries, not richer recursive-group or subtype shapes
- On March 23, 2026, the current smoke lanes still pass:
  - `moon run src/fuzz -- validate-valid smoke --seed 0x5eed`
  - `moon run src/fuzz -- validate-invalid smoke --seed 0x5eed`
- That passing baseline is not strong evidence of coverage quality. The current invalid fuzzer already contains dead or misleading strategy coverage and still reports success.

## Correctness Issues

| Priority | Area | Finding | Evidence | Impact |
| --- | --- | --- | --- | --- |
| P0 | invalid fuzz | `HeapTypeSwap` is wired to `make_drop_insertion_mutator()` instead of a heap-type swap mutator. | `src/validate/invalid_fuzzer.mbt`, `apply_strategy`, `HeapTypeSwap` branch | The reported strategy name is false. Coverage and rejection stats for heap-type corruption are invalid. |
| P0 | invalid fuzz | `DuplicateExportName` is effectively dead in the main fuzz loop because `gen_valid_module` never produces an export section. | `src/validate/gen_valid.mbt` has no `with_export_sec`; `DuplicateExportName` requires `mod_.export_sec` | The strategy is listed, counted, and reported, but never exercised by the main fuzzer. |
| P1 | invalid fuzz | Success is possible even when strategy coverage collapses. Only strategies tested at least 10 times are checked, and there is no minimum for `modules_tested` or for per-strategy exercise counts. | `run_validate_invalid_fuzz` only flags `tested >= 10 && reject_rate < 80` | A broken generator or dead strategy can silently pass CI. |
| P1 | invalid fuzz | Any rejection counts as success. The fuzzer does not verify that the rejection matches the intended failure class. | `fuzz_invalid_module_with_coverage` treats any `Err(_)` as success | A mutation can be rejected for the wrong reason and still inflate coverage. |
| P1 | valid fuzz | The valid lane only checks the original AST module. It does not require validator stability across encode/decode or text roundtrips. | `run_validate_valid_fuzz` only calls `validate_module(mod)` | Validator bugs that appear after binary/text normalization are missed. |
| P2 | observability | Validator fuzz failures do not persist a repro artifact or minimized corpus input. | unlike `src/cmd/fuzz_harness.mbt`, validator lanes emit only strings/stats | Debugging real failures will be slower than necessary. |

## Code Smells
- Profile ladders are duplicated across fuzz suites instead of being centralized. `smoke|ci|stress` counts live separately in `validate`, `invalid_fuzzer`, `cmd`, `wat`, `wast`, and `binary`.
- ASCII lowercase helpers are duplicated across multiple packages instead of shared.
- Invalid strategy metadata is split across several hand-maintained sites:
  - enum cases
  - `apply_strategy`
  - `to_string`
  - the concrete strategy list
  - the `strategy_names` list
  The `HeapTypeSwap` bug is exactly the kind of drift this layout permits.
- The generator is hand-shaped to satisfy some invalid strategies rather than modeling the broader valid module space. That improves local mutation hit-rate but weakens trust in general validator coverage.
- The Bun wrapper and core runner have mismatched defaults:
  - `src/fuzz` defaults to `smoke`
  - `bun fuzz run` defaults to `ci`
  That makes workload expectations entrypoint-dependent.
- The Bun wrapper exposes fewer fuzz-runner features than `src/fuzz`:
  - no `--output`
  - no `--jsonl`
  - no list commands
  That blocks machine-readable validator fuzz reporting unless callers bypass the wrapper.

## Coverage Gaps

### Generator Shape Gaps
- No imports. This leaves import validation, imported-global const-expression rules, and imported-function reference rules outside the main validator fuzz path.
- No exports. This leaves export-specific validation almost entirely to bespoke unit tests.
- No modules without memory, table, tag, or start sections. The current generator forces presence, so absence-sensitive validation paths are under-sampled.
- Only one `i32` memory and one `funcref` table. This misses multi-memory, memory64, table64, alternate table element shapes, and many index-selection edge cases.
- Only plain type construction via `SubType::comp_type(...)`. This leaves richer recursive-group, subtype, and exact/descriptor-oriented surfaces underrepresented.
- No import/name/custom-section generation, even though validator logic already has deterministic checks for some of those areas.

### Mutation Gaps
- Fixed single-mutation strategy set with 22 entries. No multi-mutation composition, no depth-aware corruption, no mutation weighting, and no corpus feedback.
- No strategies for many validator classes already visible in deterministic tests:
  - const-expression violations
  - data count / passive-active segment mismatches
  - undeclared `ref.func` declaration-source errors
  - name-section index range failures
  - descriptor target reftype failures
  - `call_indirect` table/type mismatches beyond simple index corruption
  - lane-index / alignment / SIMD immediate errors
  - malformed UTF-8 and malformed binary/text surfaces
- The invalid fuzzer is AST-only. It does not fuzz:
  - malformed binary modules
  - malformed WAT/WAST input
  - decode-valid / validate-invalid binaries
  - unlinkable-but-validated multi-module scenarios

### Corpus Gaps
- `tests/spec` already contains a large invalid corpus:
  - about `2995` `assert_invalid`
  - about `2101` `assert_malformed`
  - about `270` `assert_unlinkable`
- The validator fuzz lanes do not currently mine those fixtures for seed inputs, mutation templates, or expected diagnostic families.

## Hardening Recommendations

### Phase 1: Make Current Results Trustworthy
1. Fix `HeapTypeSwap` dispatch and add a direct test that proves the actual mutator ran.
2. Replace the split strategy metadata with a single source of truth:
   - name
   - constructor
   - prerequisite(s)
   - expected error family
3. Fail `validate-invalid` when:
   - `modules_tested == 0`
   - a required strategy is never exercised
   - a strategy falls below a minimum exercised count
4. Track per-strategy counts in the stats object:
   - attempted
   - mutated
   - rejected
   - expected-diagnostic matched
5. Treat “rejected for the wrong reason” as a failure, not a pass.

### Phase 2: Widen Valid Module Coverage
1. Split generator modes:
   - `natural` profile for broad valid-shape sampling
   - `forced-coverage` profile for section-presence-heavy mutation prep
2. Add optional generation for:
   - imports
   - exports
   - no-start modules
   - no-memory / no-table modules
   - multiple memories and tables where supported
   - memory64 / table64 shapes where supported
   - name sections and selected custom sections
   - richer recursive and subtype forms
3. Add stability properties for valid fuzz:
   - `validate(gen)`
   - `validate(decode(encode(gen)))`
   - optional `validate(wat(parse(print(gen))))` where practical

### Phase 3: Widen Invalid Coverage
1. Add mutation families derived from existing validator tests and spec corpus categories, not just generic index corruption.
2. Add binary-level invalid fuzz:
   - mutate encoded valid binaries
   - check decode/validate behavior
   - bucket malformed vs invalid vs accepted
3. Add text-level invalid fuzz from WAT/WAST seeds:
   - parser accepts, validator rejects
   - parser rejects with stable error family
4. Add composed mutations:
   - two-stage corruption
   - section-order plus type mismatch
   - const-expression plus index corruption
5. Add mutation shrinking similar to `minimize_fuzz_passes`, but for invalidation strategies and byte/text edits.

### Phase 4: Improve Repro and CI Ergonomics
1. Reuse `FuzzFailureReport`-style persistence for validator lanes:
   - seed
   - profile
   - strategy
   - module index
   - expected vs actual diagnostic family
   - persisted `.wat` and/or `.wasm`
2. Add JSONL output for validator fuzz stats through the Bun wrapper, not just the core Moon entrypoint.
3. Add a spec-seed lane that samples from `tests/spec` invalid and malformed fixtures before randomized mutation.
4. Add a differential lane for valid/invalid acceptance against available external validators on native runs.

## Correctness Constraints
- A strategy only counts as covered if it:
  - actually mutates the module
  - produces the intended invalidation class
  - is rejected for the expected family of validator failure
- “Coverage” must distinguish:
  - strategy available
  - strategy exercised
  - strategy rejected
  - strategy rejected for the right reason
- The valid generator should not permanently bias the entire lane toward section presence just to help one invalid strategy.
- Keep fuzz-heavy work in `src/fuzz` and preserve deterministic `moon test` behavior.

## Validation Plan
1. Add red tests for the current known issues first:
   - `HeapTypeSwap` dispatch
   - duplicate-export strategy exercise in the main fuzz loop
   - failure on zero exercised strategies
2. Extend `ValidateInvalidFuzzStats` with per-strategy counters and assert them in smoke tests.
3. Add a smoke profile assertion that a curated set of high-value strategies is exercised on every run.
4. Introduce spec-seed and binary/text invalid lanes behind separate fuzz suites so they remain runnable from `src/fuzz`.
5. Keep Moon runs serialized to avoid `_build/.moon-lock` contention.

## Performance Impact
- Phase 1 should be cheap. It is mostly accounting, stricter assertions, and one obvious dispatch fix.
- Phase 2 and Phase 3 will add cost if enabled blindly. The safe default is:
  - keep current smoke runs small
  - add new lanes under separate suites or profiles
  - reserve differential and shrinking work for `ci` or `native` runs
- Existing smoke timings suggest there is room for modest metadata and accounting improvements without making the lane unusable:
  - `validate-valid smoke` completed in about `96 ms`
  - `validate-invalid smoke` completed in about `553 ms`
  - `cmd-harness smoke` completed in about `262 ms`

## Open Questions
- Which richer type features are already representable in `lib` but absent from `gen_valid_module`, and which require generator or IR work first?
- Should invalid fuzz target stable diagnostic families, exact messages, or both?
- How much of the spec invalid corpus can be reused directly without making the lane too parser-heavy for everyday smoke runs?
- Is it better to keep one generator with toggles, or split into:
  - a broad valid-module generator
  - a mutation-friendly strategy fixture generator
- Should external differential validation be treated as authoritative for invalid acceptance, or only as an advisory mismatch signal?
