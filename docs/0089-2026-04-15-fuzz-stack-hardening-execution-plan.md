# 0089 - Fuzz Stack Hardening Execution Plan

## Scope

- Make one canonical handoff document for widening Starshine's fuzz stack, especially valid-module generation and invalid/rejection coverage.
- Reconcile the current checked-in tree with older validator-fuzz docs that still describe suites and files that are no longer present in this workspace.
- Define an implementation order that a fresh agent can follow without needing this chat transcript.
- Keep the work split into atomic backlog slices with explicit validation, invariants, and cross-references.

## Canonical References

- Validator fuzz hardening summary: [`docs/wiki/validate/fuzz-hardening.md`](./wiki/validate/fuzz-hardening.md)
- Archived validator fuzz research: [`docs/wiki/raw/research/0058-2026-03-23-validate-fuzz-hardening-plan.md`](./wiki/raw/research/0058-2026-03-23-validate-fuzz-hardening-plan.md)
- Fuzz runner entrypoint: [`src/fuzz/main.mbt`](../src/fuzz/main.mbt)
- Fuzz runner tests: [`src/fuzz/main_test.mbt`](../src/fuzz/main_test.mbt)
- Valid generator: [`src/validate/gen_valid.mbt`](../src/validate/gen_valid.mbt)
- Validator entrypoints and exported valid-fuzz helper: [`src/validate/validate.mbt`](../src/validate/validate.mbt)
- Cmd fuzz harness and repro persistence helpers: [`src/cmd/fuzz_harness.mbt`](../src/cmd/fuzz_harness.mbt)
- Bun fuzz wrapper: [`scripts/lib/fuzz-task.ts`](../scripts/lib/fuzz-task.ts)
- Pass differential fuzz harness: [`scripts/lib/pass-fuzz-compare-task.ts`](../scripts/lib/pass-fuzz-compare-task.ts)
- Broad arbitrary IR/module generator: [`src/lib/arbitrary.mbt`](../src/lib/arbitrary.mbt)
- WAST/WAT arbitrary generators: [`src/wast/arbitrary.mbt`](../src/wast/arbitrary.mbt)
- WAST spec harness: [`src/wast/spec_harness.mbt`](../src/wast/spec_harness.mbt)
- Binary roundtrip fuzz surface: [`src/binary/tests.mbt`](../src/binary/tests.mbt)
- Vendored spec corpus: [`tests/spec/README.md`](../tests/spec/README.md)

## Current State Snapshot

### What is active in the checked-in tree

- `src/fuzz/main.mbt` currently exposes these **active** runnable suites:
  - `wast-roundtrip`
  - `wat-roundtrip`
  - `validate-valid`
  - `validate-invalid-ast`
  - `validate-invalid-binary`
  - `validate-invalid-text`
  - `validate-invalid-spec-seed`
  - `binary-roundtrip`
  - `cmd-harness`
- `src/fuzz/main.mbt` no longer carries any reserved validator-rejection suite ids in help/list output; the next fuzz-stack work is now harness/docs cleanup under [`FUZ010`](#fuz010-harness-wrapper-and-docs-source-of-truth-alignment), not activating more placeholder suite names.
- `src/fuzz/main.mbt` has a real `--emit-gen-valid-batch` surface pinned to `coverage-forced` mode, and `scripts/lib/pass-fuzz-compare-task.ts` depends on it for the `gen-valid` half of mixed pass fuzzing.
- `src/validate/gen_valid.mbt` now produces a real two-mode valid topology surface:
  - `natural` mode keeps probabilistic section absence/presence variation for broad valid coverage
  - `coverage-forced` mode forces a mutation-friendly batch shape for pass fuzzing
  - shared type pools are reused across imports, defined functions, and tags instead of allocating one type per function
  - generated modules can now include func imports, defined tables/mems/globals/tags, start sections, active elem segments, active data segments, and matching data-count sections where valid
  - export coverage now includes function plus first table/memory/global/tag exports when those sections are present
  - body generation now uses recursive environment-aware control/value builders with direct calls, `call_indirect`, local/global traffic, memory/table ops, `block`/`loop`/`if`/`br`/`br_if`, and widened `v128` / `funcref` / `externref` value families; richer GC-specific recursive/subtype/struct/array generation is still deferred beyond the active hardening slices
- `src/validate/validate.mbt` remains the owner of the direct `validate-valid` generator loop through `run_validate_valid_fuzz`, and `src/fuzz/main.mbt` now delegates that direct loop instead of duplicating it.
- `src/cmd/fuzz_harness.mbt` now exposes the truthful generator-neutral name `run_cmd_fuzz_harness`; the current implementation still generates modules with `gen_valid_module(rnd)` and does not claim to be wasm-smith-backed.
- `scripts/lib/pass-fuzz-compare-task.ts` is currently the only checked-in mixed-generator harness that actually alternates between two distinct sources:
  - `wasm-tools smith`
  - in-repo `gen-valid` batch artifacts

### What is broader than the active valid generator already

- `src/lib/arbitrary.mbt` already knows how to generate much broader `Module`, `Instruction`, section, type, and index shapes, but it is not valid-by-construction and should not be dropped directly into the valid generator path.
- `src/wast/arbitrary.mbt` already generates broader text modules and scripts than `gen_valid_module`, including imports, memory, table, optional globals, start, elem/data segments, and invalid/malformed WAST command shapes.
- `tests/spec` already contains invalid, malformed, and unlinkable seed material reachable through the WAST parser/harness path.

### Important contradictions a future agent must not miss

- Older docs and changelog entries refer to `src/validate/invalid_fuzzer.mbt`, `validate-invalid`, `binary-invalid`, `text-invalid`, and `spec-seed` suites. Those are **not present in the current checked-in tree**.
- Do not assume those lanes still exist under renamed files. Treat them as missing implementation work until code is actually restored or replaced in-tree.
- The current tree is therefore much stronger at:
  - valid roundtrip stability
  - pass parity on valid inputs
  than it is at:
  - intentional invalid mutation coverage
  - malformed binary/text rejection coverage
  - persisted rejection repros

## Target End State

The target state after this plan lands is:

1. One truthful fuzz-suite surface in `src/fuzz/main.mbt` and `scripts/lib/fuzz-task.ts`.
2. One shared source of truth for fuzz profile ladders, generator modes, and generator statistics.
3. A split valid-generator story:
   - `natural` valid generation for broad valid coverage
   - `coverage-forced` valid generation for mutation applicability and targeted pass fuzzing
4. Much broader valid module topology and body generation, including imports, exports, tables, memories, tags, start/no-start, segments, richer control flow, and richer type families where already representable in `lib`.
5. Explicit invalid/rejection lanes for:
   - AST semantic invalidation
   - binary corruption / malformed decode cases
   - text/WAT/WAST invalidation
   - spec-seeded invalid/malformed/unlinkable replay
6. Per-strategy and per-feature coverage accounting that can fail on dead or unexercised slices.
7. Persisted repro artifacts and small replay contracts for invalid failures.
8. A fresh agent being able to restart from `agent-todo.md` + this doc alone.

## Non-Negotiable Invariants

- Heavy randomized work stays in `src/fuzz`, not `moon test`.
- Keep `suite` / `profile` / `seed` reproducibility for every fuzz lane.
- Keep `moon` commands serialized because of `_build/.moon-lock` contention.
- Do not silently break `--emit-gen-valid-batch`; `scripts/lib/pass-fuzz-compare-task.ts` depends on it.
- Separate broad valid coverage from mutation-friendly forced coverage instead of biasing every valid module toward mutation prerequisites.
- Count invalid fuzz coverage as distinct facts:
  - strategy available
  - strategy applicable
  - strategy mutated input
  - strategy rejected input
  - strategy rejected with the expected diagnostic family
- Prefer diagnostic families from `validation_error_diagnostic` / `ValidationIssue` over brittle raw message matching whenever possible.
- Do not describe a lane as `wasm-smith`-backed unless it actually consumes wasm-smith output.
- Keep public docs and help text conservative: only advertise suites, flags, and outputs that are really in-tree.

## Minimum Validation Per Slice

For every slice below:

- Write the failing test first.
- Run the narrowest relevant package tests while iterating.
- For generator or fuzz-runner changes, add or update `src/fuzz/main_test.mbt` coverage.
- For any public API change in `src/validate` or `src/fuzz`, review the generated `.mbti` diff.
- Before commit for any landed slice, run at minimum:
  - `moon info`
  - `moon fmt`
  - `moon test`
- When a slice changes the active fuzz surface, also run the narrowest relevant smoke lanes, for example:
  - `moon run src/fuzz -- validate-valid smoke --seed 0x5eed`
  - intended future invalid lanes once they exist
- When a slice changes `gen-valid` output shape, also rerun a small `pass-fuzz-compare` check to prove the batch surface still works.

## Execution Order

Work in this order unless a smaller prerequisite must be split out first:

1. `FUZ001` suite surface and truth-in-naming reconciliation
2. `FUZ002` shared config and stats plumbing
3. `FUZ003` valid topology widening and mode split
3a. `FUZ003A` `gen-valid`-seeded `RUME` imported-function parity follow-up
3b. `FUZ003B` `gen-valid`-seeded `RUME` no-op start-section parity follow-up
4. `FUZ004` body generation and type widening
5. `FUZ005` generator observability and coverage floors
6. `FUZ006` AST invalid mutator registry
7. `FUZ007` binary invalid lane
8. `FUZ008` text/spec-seed invalid lane
9. `FUZ009` repro persistence and shrinkers
10. `FUZ010` harness, wrapper, and docs source-of-truth cleanup

Do not try to land `FUZ006`-`FUZ009` before the suite-surface and config work exists. That is the easiest way to recreate drift.

---

## FUZ001 Suite Surface And Inventory Reconciliation

**Slice id:** `[FUZ]001`

**Status:** completed 2026-04-16.

### Goal

Make the active fuzz suite surface truthful again before widening it.

### Why first

The current repo has a documented mismatch between:

- older docs/research/changelog that describe missing invalid lanes, and
- the actual checked-in `src/fuzz/main.mbt` suite list.

If that mismatch is not resolved first, every later slice risks updating the wrong entrypoint or preserving dead docs.

### Files most likely to change

- [`src/fuzz/main.mbt`](../src/fuzz/main.mbt)
- [`src/fuzz/main_test.mbt`](../src/fuzz/main_test.mbt)
- [`src/fuzz/imports.mbt`](../src/fuzz/imports.mbt)
- [`scripts/lib/fuzz-task.ts`](../scripts/lib/fuzz-task.ts)
- wrapper tests under [`scripts/test/`](../scripts/test)
- possibly [`src/cmd/fuzz_harness.mbt`](../src/cmd/fuzz_harness.mbt) if naming is corrected here

### Outcome

- Chose these canonical reserved suite ids for the future rejection lanes:
  - `validate-invalid-ast`
  - `validate-invalid-binary`
  - `validate-invalid-text`
  - `validate-invalid-spec-seed`
- Added the suite ids to the Moon entrypoint inventory, help text, and `--list-suites` output, but marked them as `reserved` until their later implementation slices land.
- Added Bun wrapper command coverage so `--help`, `--list-suites`, and `--list-profiles` continue to forward exactly to the Moon entrypoint surface.
- Renamed the stale wasm-smith-labeled cmd helper surface to the truthful generator-neutral names `run_cmd_fuzz_harness`, `run_cmd_fuzz_harness_profile`, and `CmdFuzzStats`.
- Kept `run_validate_valid_fuzz` as the direct valid-generation owner and made `src/fuzz/main.mbt` delegate to it for the generator loop before adding the extra text-companion checks.

### Validation

- `moon test src/fuzz`
- `moon run src/fuzz -- --list-suites`
- `bun fuzz run --list-suites`
- add one parser/help regression per new or renamed suite surface

### Exit criteria

- Every active fuzz suite is visible from both Moon and Bun entrypoints.
- No checked-in help text advertises missing invalid suites.
- No checked-in function name falsely implies a generator source it does not use.

---

## FUZ002 Shared Fuzz Config And Feature-Fact Plumbing

**Slice id:** `[FUZ]002`

**Status:** completed 2026-04-16.

### Goal

Create one shared configuration vocabulary for valid generation, invalid generation, and statistics.

### Why

The current tree duplicates too much fuzz policy in separate places:

- profile ladders
- valid generation logic
- runner-level counts
- exported validate-level valid fuzz helper

The next slices need a shared way to say:

- which mode is being used
- what feature families are allowed or forced
- how large the module may grow
- what facts were actually exercised

### Files most likely to change

- [`src/validate/gen_valid.mbt`](../src/validate/gen_valid.mbt)
- [`src/validate/validate.mbt`](../src/validate/validate.mbt)
- [`src/fuzz/main.mbt`](../src/fuzz/main.mbt)
- [`src/fuzz/main_test.mbt`](../src/fuzz/main_test.mbt)
- generated package interface files if public types are exported

### Concrete tasks

- Add an explicit generator config structure rather than keeping `GenValidContext` as only `RandomState`.
- Model at least:
  - mode (`natural`, `coverage-forced`, future seed-backed variants)
  - size budgets
  - section probabilities / forcing
  - body-depth budgets
  - feature toggles or allowlists
- Add a feature-fact / stats structure that can record facts such as:
  - imports present
  - export kinds present
  - start/no-start
  - tables/mems/tags present
  - elem/data/datacount present
  - ref/v128 usage
  - call / call_indirect / branch-heavy control flow present
- Decide which parts are public API and which remain internal to the validate/fuzz packages.

### Validation

- generator config defaults remain deterministic for a fixed seed
- stats are deterministic for a fixed seed and mode
- existing `validate-valid` suite stays green under compatibility defaults

### Exit criteria

- Later slices can widen generation without re-inventing configuration plumbing.
- There is one explicit data structure that records generator mode and exercised features.

### Outcome

- Added shared public config vocabulary in [`src/validate/gen_valid.mbt`](../src/validate/gen_valid.mbt):
  - `GenValidMode`
  - `GenValidSectionBias`
  - `GenValidFeatureToggles`
  - `GenValidConfig`
  - `default_gen_valid_config()`
- Added generator feature reporting surfaces:
  - `GenValidFeatureFacts`
  - `GenValidFeatureStats`
  - `gen_valid_feature_facts(mod, mode)`
- Changed `GenValidContext` from random-state-only plumbing to config-aware plumbing, and taught the current valid generator to honor the compatibility-size budgets plus the first mode-sensitive section forcing (`globals` for `coverage-forced`).
- Added `gen_valid_module_with_config(rnd, config)` so later slices can widen topology without changing every caller again.
- Added `ValidateValidRunConfig` plus `validate_valid_run_config(profile)` so the profile ladder and generator defaults live in one place instead of being re-derived at each callsite.
- Extended `ValidateValidFuzzStats` to carry the resolved generator config plus deterministic aggregated feature stats for the run.
- Kept the default `gen_valid_module(rnd)` contract and `--emit-gen-valid-batch` behavior compatible for this slice; the broader topology controls stored in `GenValidConfig` are intentional foundation fields and do not all become active until [`FUZ003`](#fuz003-multi-mode-valid-topology-generator) and [`FUZ004`](#fuz004-environment-aware-body-generation-and-type-widening).

### Validation

- Added focused validate-package tests for:
  - profile-to-generator config resolution
  - deterministic `run_validate_valid_fuzz` stats on a fixed seed
  - feature-fact extraction across imports, exports, sections, and selected instruction families
- Added fuzz-package coverage that the emitted `gen-valid` batch still matches the shared default generator config for the same seed.
- This runtime still cannot execute `moon` / `bun` directly, so the required command-level verification remains pending for the next tool-enabled pass:
  - `moon test src/validate`
  - `moon test src/fuzz`
  - `moon run src/fuzz -- validate-valid smoke --seed 0x5eed`
  - `moon run src/fuzz -- --emit-gen-valid-batch --count 4 --seed 0x5eed --out-dir .tmp/gen-valid-smoke`

---

## FUZ003 Multi-Mode Valid Topology Generator

**Slice id:** `[FUZ]003`

**Status:** completed 2026-04-16.

### Goal

Split valid generation into at least two modes and widen module topology before touching deep body generation.

### Why

Current `gen_valid_module` is topology-poor. It mostly emits a tiny core shape. Topology widening gives immediate coverage gains even before bodies become sophisticated.

### Files most likely to change

- [`src/validate/gen_valid.mbt`](../src/validate/gen_valid.mbt)
- [`src/fuzz/main.mbt`](../src/fuzz/main.mbt)
- [`src/fuzz/main_test.mbt`](../src/fuzz/main_test.mbt)
- batch emission logic if default mode selection changes

### Concrete tasks

- Split valid generation into at least:
  - `natural` mode for broad valid coverage
  - `coverage-forced` mode for mutation-friendly and pass-fuzz-oriented generation
- Build module topology first, before bodies:
  - type pool
  - imports
  - defined functions
  - tables
  - memories
  - globals
  - tags
  - elem/data/data-count sections where valid
  - exports
  - start section when valid
  - optional name/custom sections if the representation already supports them cleanly
- Add section absence variation too; do **not** force every module to contain all sections.
- Reuse function types across multiple funcs/imports/tags rather than allocating a unique type for every function.
- Decide which mode `--emit-gen-valid-batch` should use and document it.
  - Recommendation: keep the batch mode explicit and stable rather than implicit.

### Validation

- `moon run src/fuzz -- validate-valid smoke --seed 0x5eed`
- `moon run src/fuzz -- --emit-gen-valid-batch --count 4 --seed 0x5eed --out-dir .tmp/gen-valid-smoke`
- decode and validate the emitted artifacts
- rerun at least one small `pass-fuzz-compare` `gen-valid` lane after any batch-mode change

### Exit criteria

- Valid generator can emit modules with meaningful section diversity.
- `natural` and `coverage-forced` mode distinction is real, not only documented.
- `pass-fuzz-compare` still works against the emitted batch contract.

### Outcome

- Rebuilt [`src/validate/gen_valid.mbt`](../src/validate/gen_valid.mbt) around a topology-first module generator instead of the previous function-only shape.
- `natural` mode now exercises probabilistic section absence/presence across func imports, defined tables/mems/globals/tags, start sections, active elem segments, active data segments, and matching data-count sections.
- `coverage-forced` mode now makes the split real in checked-in behavior by forcing the widened topology families on while still reusing a shared function-type pool across imports, defined functions, and tags.
- `--emit-gen-valid-batch` is now explicitly pinned to `coverage-forced` generation, and the runner help text calls that out so the batch contract stays stable for pass fuzzing instead of following the default generator mode implicitly.
- The direct `validate-valid` runner remains on `natural` mode, so broad valid coverage and mutation-friendly batch generation are now separate checked-in paths instead of one implicit default.
- That earlier shallow-body limitation is now superseded by [`FUZ004`](#fuz004-environment-aware-body-generation-and-type-widening), which lands recursive environment-aware body generation plus the first widened `v128` / ref-type value surface.

### Validation

- Added focused validate-package coverage that a fixed-seed `coverage-forced` module validates, emits the widened topology facts, and reuses a shared type pool instead of allocating one type per import/function/tag user.
- Updated the fixed-seed `run_validate_valid_fuzz` stats test to lock in the widened natural-mode topology breadth (`imports`, `tables`, `mems`, `globals`, `tags`, `elems`, `datas`, mixed `start`/`no-start` facts) while preserving deterministic stats for the same seed.
- Updated fuzz-package coverage so `--emit-gen-valid-batch` is pinned to the documented `coverage-forced` config and the usage text advertises that batch mode explicitly.
- This runtime still cannot execute `moon` / `bun` directly, so the command-level verification that should be rerun in a tool-enabled pass remains:
  - `moon test src/validate`
  - `moon test src/fuzz`
  - `moon run src/fuzz -- validate-valid smoke --seed 0x5eed`
  - `moon run src/fuzz -- --emit-gen-valid-batch --count 4 --seed 0x5eed --out-dir .tmp/gen-valid-smoke`
  - a small `bun scripts/pass-fuzz-compare.ts --pass <one-pass> --generator gen-valid ...` smoke to confirm the pinned batch contract still feeds the compare harness cleanly

---

## FUZ003A Gen-valid `RUME` Imported-Function Parity Follow-Up

**Slice id:** `[FUZ]003A`

**Status:** completed 2026-04-16.

### Goal

Close the exact `remove-unused-module-elements` mismatch that widened `gen-valid` topology exposed immediately after [`FUZ003`](#fuz003-multi-mode-valid-topology-generator).

### Why before `FUZ004`

The widened topology is now live enough to exercise module-element trimming in ways the older generator never hit. Before widening body generation further, the fuzz stack should stop carrying a known deterministic compare-pass mismatch on the new `coverage-forced` batch contract.

### Exact trigger

Focused smoke run:

- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator gen-valid --count 20 --max-failures 5 --out-dir .tmp/pass-fuzz-fuz003-genvalid-smoke`

Observed result:

- `comparedCount=5`
- `normalizedMatchCount=0`
- `mismatchCount=5`
- `validationFailureCount=0`
- `generatorFailureCount=0`
- `commandFailureCount=0`

Saved primary repro:

- `.tmp/pass-fuzz-fuz003-genvalid-smoke/failures/case-000001-gen-valid/`

Exact case write-up:

- [`docs/wiki/raw/research/0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md`](./wiki/raw/research/0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md)

### What the repro shows

- The widened `coverage-forced` generator now emits a live defined `main` function alongside an unused imported function.
- Binaryen drops the unused imported function and its dead type from the normalized `RUME` output.
- Starshine still preserves both, even though imported memory/table/global/tag pruning is already fixed in-tree.

### Files most likely to change

- [`src/passes/remove_unused_module_elements.mbt`](../src/passes/remove_unused_module_elements.mbt)
- [`src/passes/remove_unused_module_elements_test.mbt`](../src/passes/remove_unused_module_elements_test.mbt)
- this handoff doc and [`agent-todo.md`](../agent-todo.md) for follow-up state

### Concrete tasks

- Add a focused imported-function regression beside the existing imported memory/table/global/tag `RUME` tests.
- Make `RUME` drop unused imported functions, not only imported memories/tables/globals/tags.
- Rewrite any surviving function/type/name/export/start/elem references correctly after the import disappears.
- Re-run the small `gen-valid` compare-pass smoke to prove the mismatch family is gone before resuming broader fuzz widening.

### Validation

- `moon test src/passes`
- `moon test src/cmd` if CLI-facing replay coverage changes
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator gen-valid --count 20 --max-failures 5 --out-dir .tmp/pass-fuzz-fuz003a-genvalid-smoke`

### Exit criteria

- The saved imported-function repro matches Binaryen.
- The small `gen-valid` `RUME` compare-pass smoke no longer fails on this family.
- `FUZ004` can resume from a widened topology baseline without carrying this known deterministic parity hole.

### Outcome

- Added a focused imported-function regression in [`src/passes/remove_unused_module_elements_test.mbt`](../src/passes/remove_unused_module_elements_test.mbt) that keeps a live exported/start/elem-defined function while demanding that an unused imported function and its dead simple function type disappear.
- Updated [`src/passes/remove_unused_module_elements.mbt`](../src/passes/remove_unused_module_elements.mbt) so module-pass `RUME` now:
  - remaps functions through the actual used-function bitset instead of assuming every imported function survives
  - drops unused function imports from `import_sec`
  - compacts dead simple function types after import removal by reusing the shared type-index rewrite machinery already present in the passes package
- The focused rerun `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator gen-valid --count 20 --max-failures 5 --out-dir .tmp/pass-fuzz-fuz003a-genvalid-smoke` now proves the targeted imported-function family is gone: the old saved repro `.tmp/pass-fuzz-fuz003-genvalid-smoke/failures/case-000001-gen-valid/` matches Binaryen after the fix.
- The same rerun still reports two remaining mismatches at `.tmp/pass-fuzz-fuz003a-genvalid-smoke/failures/case-000002-gen-valid/` and `case-000020-gen-valid/`, but those are a distinct no-op start-section pruning family where Binaryen drops the `start` section and Starshine currently preserves it. That follow-up is not imported-function retention and is tracked under [`FUZ003B`](#fuz003b-gen-valid-rume-no-op-start-section-parity-follow-up).

### Validation

- `moon test --package jtenner/starshine/passes --file remove_unused_module_elements_test.mbt`
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator gen-valid --count 20 --max-failures 5 --out-dir .tmp/pass-fuzz-fuz003a-genvalid-smoke`
  - `comparedCount=20`
  - `normalizedMatchCount=18`
  - `mismatchCount=2`
  - `validationFailureCount=0`
  - `generatorFailureCount=0`
  - `commandFailureCount=0`

---

## FUZ003B Gen-valid `RUME` No-Op Start-Section Parity Follow-Up

**Slice id:** `[FUZ]003B`

**Status:** completed 2026-04-16.

### Goal

Close the next deterministic `remove-unused-module-elements` mismatch family still exposed by the widened `coverage-forced` `gen-valid` batch after [`FUZ003A`](#fuz003a-gen-valid-rume-imported-function-parity-follow-up).

### Why before `FUZ004`

The widened topology baseline was good enough to expose a second exact `RUME` parity family on the same small smoke lane. Closing that known deterministic mismatch before widening body generation again keeps the valid-generator baseline clean instead of carrying a known downstream compare-pass hole into broader fuzz work.

### Exact trigger

Focused smoke rerun after the imported-function fix:

- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator gen-valid --count 20 --max-failures 5 --out-dir .tmp/pass-fuzz-fuz003a-genvalid-smoke`

Observed result before this slice:

- `comparedCount=20`
- `normalizedMatchCount=18`
- `mismatchCount=2`
- `validationFailureCount=0`
- `generatorFailureCount=0`
- `commandFailureCount=0`

Saved repros:

- `.tmp/pass-fuzz-fuz003a-genvalid-smoke/failures/case-000002-gen-valid/`
- `.tmp/pass-fuzz-fuz003a-genvalid-smoke/failures/case-000020-gen-valid/`

Exact case write-up:

- [`docs/wiki/raw/research/0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md`](./wiki/raw/research/0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md)

### Outcome

- Added focused `start`-section regressions in [`src/passes/remove_unused_module_elements_test.mbt`](../src/passes/remove_unused_module_elements_test.mbt) for:
  - a surviving exported + elem-linked nullary `nop` start function
  - the same family with locals still present
  - the nearby negative boundary where an empty-body start must remain
  - a start-only `nop` function that Binaryen removes entirely once `start` stops keeping it alive
- Updated [`src/passes/remove_unused_module_elements.mbt`](../src/passes/remove_unused_module_elements.mbt) so `RUME` now matches the proved Binaryen rule for this family:
  - treat `start` as removable only when it targets a **defined** function whose body is exactly a single `nop`
  - ignore local declarations when checking that exact body shape
  - skip `start`-rooted liveness for that exact family, so a start-only single-`nop` function disappears entirely while otherwise-live exported/elem-linked functions remain
  - suppress the rewritten `start_sec` in the final module whenever that exact family is detected
- The imported-function follow-up from [`FUZ003A`](#fuz003a-gen-valid-rume-imported-function-parity-follow-up) remains intact; its focused regression now correctly expects the remapped live function to stay while the now-no-op `start` section disappears.
- The follow-up smoke lane is now clean again, so [`FUZ004`](#fuz004-environment-aware-body-generation-and-type-widening) can resume from a widened topology baseline without this deterministic `RUME` parity hole.

### Validation

- `moon info`
- `moon fmt`
- `moon test --package jtenner/starshine/passes --file remove_unused_module_elements_test.mbt`
- `moon test src/passes`
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator gen-valid --count 20 --max-failures 5 --out-dir .tmp/pass-fuzz-fuz003b-genvalid-smoke`
  - `comparedCount=20`
  - `normalizedMatchCount=20`
  - `mismatchCount=0`
  - `validationFailureCount=0`
  - `generatorFailureCount=0`
  - `commandFailureCount=0`
- `moon test`

### Exit criteria

- The saved `case-000002-gen-valid` and `case-000020-gen-valid` repros now match Binaryen.
- The follow-up smoke no longer reports this `start`-section-only mismatch family.
- `FUZ005` is now the next unfinished fuzz-stack slice.

---

## FUZ004 Environment-Aware Body Generation And Type Widening

**Slice id:** `[FUZ]004`

**Status:** completed 2026-04-16.

### Goal

Replace the current flat body stub generation with environment-aware structured bodies and widen the actual value/type surface that bodies can use.

### Why

Topology alone will not exercise much validator logic if bodies still only emit `nop`, `drop`, `local.set`, and trivial `if`/`block` shapes.

### Files most likely to change

- [`src/validate/gen_valid.mbt`](../src/validate/gen_valid.mbt)
- possibly helper files extracted from it if the generator becomes too large
- [`src/validate/validate.mbt`](../src/validate/validate.mbt) tests if new valid families reveal latent validator gaps

### Concrete tasks

- Introduce recursive, fuel-based body generation.
- Track enough environment to emit valid:
  - labels / block result shapes
  - direct calls
  - indirect calls if the current type/table surface is ready
  - local/global gets and sets
  - memory ops when memory exists
  - table ops when table exists
  - `ref.func` only when declaration rules are satisfied
- Broaden control flow from the current tiny set to include at least:
  - `block`
  - `loop`
  - `if`
  - `br`
  - `br_if`
  - eventually `br_table`
- Widen value and type choices beyond numeric scalars where already safe:
  - `v128`
  - `funcref`
  - `externref`
- After the simpler widening is stable, add richer type shapes already modeled in `lib` where valid generation can support them without lying about validity:
  - recursive groups
  - subtype chains
  - struct/array types
  - exact refs / richer heap types
- Keep this slice incremental. Land the smallest valid widening first, then push into richer GC-like surfaces.

### Planned validation

- `validate-valid` smoke must stay green
- binary roundtrip on emitted modules must stay green
- WAT companion stability must not collapse unexpectedly in CI/stress
- add focused tests for any new helper that manages labels, return types, or index selection

### Exit criteria

- Valid generated bodies exercise substantially more validator surface than the current flat stub generator.
- The generator can emit meaningful structured control flow and section-dependent instructions without frequent accidental invalidity.

### Outcome

- Replaced the old flat stub body builder in [`src/validate/gen_valid.mbt`](../src/validate/gen_valid.mbt) with recursive environment-aware generation keyed off explicit local/global/table/memory/function context plus bounded body-depth fuel from `GenValidConfig`.
- `natural` and `coverage-forced` generation now both widen the live value/type surface by enabling `v128`, `funcref`, and `externref` in generated params, locals, globals, returns, and body expressions where valid.
- Value generation now knows how to build valid direct calls, `call_indirect`, ref-producing table reads, memory loads, `memory.size`, `table.size`, `ref.func` (only for declared/exported generated targets), `ref.null`, and structured value wrappers through result-typed `block` / `if` builders.
- Void statement generation now emits meaningful structured control and section-dependent traffic: `block`, `loop`, `if`, `br`, `br_if`, local/global sets, memory `load` / `store` / `grow`, and table `get` / `set` / `grow` / `size` when those sections exist.
- `coverage-forced` mode now prepends a deterministic widened-surface prelude so `--emit-gen-valid-batch` continues to be a stable mutation-friendly contract while guaranteeing that the batch lane still exercises the new call / table / memory / branch / ref / `v128` families on every module.
- The incremental note inside this slice remains intentional: this run lands the smaller environment-aware body widening first, while richer GC-like recursive/subtype/struct/array generation stays explicitly deferred rather than being claimed live.

### Validation

- Added focused validate-package coverage that fixed-seed `coverage-forced` generation now proves the widened body surface directly: `block`, `loop`, `if`, `br`, `br_if`, memory ops, table ops, `v128`, ref types, direct calls, and `call_indirect`.
- Updated the deterministic `run_validate_valid_fuzz("smoke", seed)` stats test so natural-mode runs now have to exercise `ref_types`, `v128`, direct calls, `call_indirect`, and branch-heavy control instead of only widened topology facts.
- `moon test --package jtenner/starshine/validate --file validate.mbt`
- `moon test src/validate`
- `moon test src/fuzz`
- `moon run src/fuzz -- validate-valid smoke --seed 0x5eed`
- `mkdir -p .tmp/gen-valid-smoke && moon run src/fuzz -- --emit-gen-valid-batch --count 4 --seed 0x5eed --out-dir .tmp/gen-valid-smoke`
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator gen-valid --count 20 --max-failures 5 --out-dir .tmp/pass-fuzz-fuz004-genvalid-smoke`
  - `comparedCount=20`
  - `normalizedMatchCount=20`
  - `mismatchCount=0`
  - `validationFailureCount=0`
  - `generatorFailureCount=0`
  - `commandFailureCount=0`

---

## FUZ005 Generator Observability And Coverage Floors

**Slice id:** `[FUZ]005`

**Status:** completed 2026-04-16.

### Goal

Make generator breadth measurable so the new wider generator cannot silently regress back into a narrow shape.

### Why

Without explicit feature reporting, generation drift is invisible and later agents will not know whether the widened generator is still doing useful work.

### Files most likely to change

- [`src/validate/validate.mbt`](../src/validate/validate.mbt)
- [`src/fuzz/main_test.mbt`](../src/fuzz/main_test.mbt)
- generated package interface files if public stats surfaces change

### Concrete tasks

- Record feature facts for each generated module.
- Aggregate them per run.
- Define minimum exercised floors by profile for high-value families.
  - Smoke should only require a small curated subset.
  - CI/stress should require a broader matrix.
- Fail runs when required feature families never appear.
- Keep the reporting machine-readable enough to feed future JSONL or persisted reports.

### Validation

- deterministic stats for fixed seeds
- smoke floors are realistic and not flaky
- CI/stress floors are stricter but still achievable on intended seeds

### Exit criteria

- A broken generator mode or dead feature family can no longer pass invisibly.
- Feature breadth is visible in stats rather than inferred from hope.

### Outcome

- Extended [`src/validate/validate.mbt`](../src/validate/validate.mbt) with a public machine-readable coverage-floor surface for `validate-valid` runs:
  - `ValidateValidFeatureKey`
  - `ValidateValidFeatureFloor`
  - `ValidateValidFeatureFloorFailure`
  - `validate_valid_feature_actual_count(...)`
  - `check_validate_valid_feature_floors(...)`
- `ValidateValidRunConfig` now resolves per-profile coverage floors alongside the generator config, so the profile ladder owns both generation budgets and minimum required breadth facts in one place.
- `ValidateValidFuzzStats` now carries the resolved coverage floors with the aggregated `GenValidFeatureStats`, making the success surface explicit about both observed breadth and what the run required.
- `run_validate_valid_fuzz(...)` now fails with a detailed floor-miss error if the required curated feature families do not clear their per-profile minimums, instead of only checking that generated modules validate.
- The landed floor matrix is intentionally split by profile:
  - `smoke` requires only a curated subset (`imports`, `start`/`no-start`, `tables`, `mems`, `ref_types`, `v128`, direct calls, `call_indirect`, branch-heavy control)
  - `ci` / `stress` require a broader section/export/data/control matrix with stricter counts so dead generator families are visible before the invalid-lane work starts in [`FUZ006`](#fuz006-ast-invalid-mutator-registry-and-diagnostic-accounting)
- Added focused tests for the new floor-check helper and updated the fixed-seed deterministic stats test so it locks in the resolved floor set as part of the public `validate-valid` result surface. Added fuzz-runner coverage in [`src/fuzz/main_test.mbt`](../src/fuzz/main_test.mbt) that `validate-valid` profile errors still route through the validator runner cleanly.

### Validation

- `moon test --package jtenner/starshine/validate --file validate.mbt`
- `moon test --package jtenner/starshine/fuzz --file main_test.mbt`
- `moon info`
- `moon fmt`
- `moon test src/validate`
- `moon test src/fuzz`
- `moon test`
- `moon run src/fuzz -- validate-valid smoke --seed 0x5eed`
- `moon run src/fuzz -- validate-valid ci --seed 0x5eed`

---

## FUZ006 AST Invalid Mutator Registry And Diagnostic Accounting

**Slice id:** `[FUZ]006`

**Status:** completed 2026-04-16.

### Goal

Reintroduce an explicit AST-level invalid/rejection fuzz engine with honest per-strategy accounting.

### Why

This was the core missing rejection layer in the current tree. The older docs described it, but the code was gone from this workspace until this slice restored an active AST lane.

### Files most likely to change

- [`src/validate/invalid_fuzzer.mbt`](../src/validate/invalid_fuzzer.mbt)
- [`src/fuzz/main.mbt`](../src/fuzz/main.mbt)
- [`src/fuzz/imports.mbt`](../src/fuzz/imports.mbt)
- [`src/fuzz/main_test.mbt`](../src/fuzz/main_test.mbt)
- package interfaces/tests

### Concrete tasks

- Add one strategy registry as the single source of truth.
- For each strategy, record:
  - stable id
  - display name
  - layer (`ast`)
  - prerequisite / applicability check
  - mutator
  - expected diagnostic family
- Count at least:
  - attempted
  - applicable
  - mutated
  - rejected
  - rejected-with-expected-family
- Start with high-value AST-invalid families:
  - duplicate export names
  - invalid start signature
  - invalid func/table/mem/global/tag/type indices
  - invalid active elem/data targets
  - missing or mismatched datacount
  - invalid const expr usage
  - undeclared `ref.func`
  - bad name-section indices
  - type/stack mismatch families reachable from local rewrites
  - `call_indirect` mismatch once valid generation can seed the family
- Make required strategies fail the suite if they are never exercised.

### Outcome

- Added a new public AST invalid-fuzz engine in [`src/validate/invalid_fuzzer.mbt`](../src/validate/invalid_fuzzer.mbt) with one checked-in registry driving the current strategy ids, stable names, layer tag, expected diagnostic families, smoke-required set, and fixed profile ladder.
- Restored `validate-invalid-ast` as a real active fuzz suite in [`src/fuzz/main.mbt`](../src/fuzz/main.mbt). [`FUZ007`](#fuz007-binary-invalid-corruption-lane) later promotes `validate-invalid-binary` to active, and [`FUZ008`](#fuz008-text-and-spec-seed-invalid-lane) finishes the remaining text/spec-seed suite activations.
- Landed honest per-strategy accounting in `run_validate_invalid_ast_fuzz(...)` with deterministic stats for:
  - attempted
  - applicable
  - mutated
  - rejected
  - rejected-with-expected-family
- The initial curated AST strategy set now exercises and checks these exact high-value families on every smoke run:
  - duplicate export names
  - invalid start signature
  - missing datacount for `memory.init`
  - undeclared `ref.func`
  - out-of-range function indices in the structured name section
- The runner now fails if any required smoke strategy never becomes applicable, never mutates, or never reaches its expected diagnostic family, instead of treating any rejection as good enough.
- The mutators intentionally start from widened `coverage-forced` valid modules and then add the smallest targeted invalidating rewrite needed for the strategy, so this slice restores the AST rejection lane without rebiasing the main broad valid generator path.

### Validation

- Added dedicated validate-package tests proving the curated strategies really mutate a fixed-seed valid module and reject with the intended diagnostic family (`ExportSection`, `StartSection`, `FunctionBody`, or `NameSection` as appropriate).
- Added a fixed-seed deterministic stats test for `run_validate_invalid_ast_fuzz("smoke", 0x5eed)` that requires every landed strategy to record non-zero attempted/applicable/mutated/rejected/rejected-with-expected-family counts.
- Updated fuzz-package coverage so suite inventory/help now treats `validate-invalid-ast` as active and routes profile errors through the AST invalid runner instead of the old reserved-suite message.
- `moon test src/validate`
- `moon test src/fuzz`
- `moon run src/fuzz -- validate-invalid-ast smoke --seed 0x5eed`

### Exit criteria

- The tree has a real AST invalid fuzz lane again.
- Coverage accounting is strategy-aware and diagnostic-aware rather than just “got some error”.
- `[FUZ]007` is now the next unfinished validator fuzz slice.

---

## FUZ007 Binary Invalid Corruption Lane

**Slice id:** `[FUZ]007`

**Status:** completed 2026-04-16.

### Goal

Add a binary corruption lane that can test malformed decode behavior and decode-valid / validate-invalid boundaries that AST mutation cannot express.

### Why

AST mutation alone cannot cover malformed section order, bad lengths, malformed LEBs, UTF-8 corruption, or other byte-level rejection families.

### Files most likely to change

- invalid fuzz implementation files under `src/fuzz/`
- runner and wrapper tests

### Outcome

- Added a new binary invalid runner in [`src/fuzz/invalid_binary.mbt`](../src/fuzz/invalid_binary.mbt) instead of trying to force a circular `validate` ↔ `binary` package dependency.
- Landed one checked-in byte-corruption registry with deterministic smoke/ci/stress profile resolution and stable strategy ids:
  - `trailing-garbage`
  - `truncated-module`
  - `duplicate-type-section`
  - `wrong-section-order`
  - `invalid-func-type-index`
- The runner now records honest per-strategy stage facts for:
  - `attempted`
  - `applicable`
  - `mutated`
  - `decode_rejected`
  - `validate_rejected`
  - `rejected_expected`
  - `accepted`
- The initial curated family set proves both major byte-level buckets on widened `coverage-forced` `gen-valid` seeds:
  - decode malformed / parser rejected via trailing garbage, truncation, duplicate type sections, and wrong section order
  - decode succeeded but validator rejected via out-of-range function-section type indices
- Promoted `validate-invalid-binary` to a real active suite in [`src/fuzz/main.mbt`](../src/fuzz/main.mbt). [`FUZ008`](#fuz008-text-and-spec-seed-invalid-lane) later activates the remaining text/spec-seed lanes too, so help and `--list-suites` no longer advertise any reserved validator-rejection suites.

### Validation

- Added focused blackbox coverage in [`src/fuzz/invalid_binary_test.mbt`](../src/fuzz/invalid_binary_test.mbt) for:
  - registry surface and expected-stage labels
  - a deterministic decode-stage rejection (`trailing-garbage`)
  - a deterministic validate-stage rejection (`invalid-func-type-index`)
  - fixed-seed deterministic run stats with both decode and validate buckets exercised
- Updated [`src/fuzz/main_test.mbt`](../src/fuzz/main_test.mbt) so suite inventory/help and profile-error routing now treat `validate-invalid-binary` as active instead of reserved.
- Verification run for this slice:
  - `moon test --package jtenner/starshine/fuzz --file invalid_binary_test.mbt`
  - `moon test --package jtenner/starshine/fuzz --file main_test.mbt`
  - `moon test src/fuzz`
  - `moon test src/validate`
  - `moon run src/fuzz -- validate-invalid-binary smoke --seed 0x5eed`

### Exit criteria

- The tree has a binary-invalid lane distinct from AST invalidation.
- Malformed-vs-invalid stage distinctions are visible in the report surface.
- `[FUZ]008` is now the next unfinished validator fuzz slice.

---

## FUZ008 Text And Spec-Seed Invalid Lane

**Slice id:** `[FUZ]008`

**Status:** completed 2026-04-16.

### Goal

Add text-level invalidation and spec-seeded replay so parser/lower/validate rejection coverage is not limited to random AST mutation.

### Why

`src/wast/arbitrary.mbt` and `tests/spec` already contain excellent seed material that the current active tree barely uses for rejection testing.

### Files most likely to change

- invalid fuzz implementation files
- [`src/wast/arbitrary.mbt`](../src/wast/arbitrary.mbt) if more seed helpers are needed
- [`src/wast/spec_harness.mbt`](../src/wast/spec_harness.mbt) only if reusable command extraction helpers are added
- [`src/fuzz/main.mbt`](../src/fuzz/main.mbt)

### Concrete tasks

- Add a text-invalid lane that mutates WAT/WAST or uses arbitrary text seeds.
- Add a spec-seed lane that samples from `tests/spec` categories such as:
  - `assert_invalid`
  - `assert_malformed`
  - `assert_unlinkable`
- Preserve the stage distinction:
  - parse/lower rejected
  - lowered successfully but validator rejected
  - valid before link-time failure for unlinkable seeds
- Keep smoke profiles small and deterministic; do not try to replay the whole spec corpus in every fuzz run.
- Reuse the existing spec harness behavior rather than inventing a second interpretation of spec command meaning.

### Outcome

- Added a new shared text/spec-seed invalid runner surface in [`src/fuzz/invalid_text.mbt`](../src/fuzz/invalid_text.mbt) instead of pushing text rejection logic into `src/validate`.
- Promoted both `validate-invalid-text` and `validate-invalid-spec-seed` to real active suites in [`src/fuzz/main.mbt`](../src/fuzz/main.mbt); the fuzz runner now advertises no reserved validator-rejection suite ids.
- Landed a curated inline text registry with stable strategy ids and deterministic smoke/ci/stress profile resolution:
  - `malformed-quote-missing-paren`
  - `invalid-result-stack`
  - `unlinkable-unknown-import`
- The text-invalid runner now records explicit per-strategy stage facts for:
  - `attempted`
  - `applicable`
  - `parse_or_lower_rejected`
  - `validate_rejected`
  - `valid_before_link`
  - `matched_expected`
- Landed a curated spec-seed registry that samples one deterministic `tests/spec` fixture from each desired category by extracting the raw assertion command text and then reusing the shared WAST static-assertion evaluator:
  - `const-malformed-quote-1`
  - `f32-invalid-type-mismatch-1`
  - `imports-unlinkable-unknown-import-1`
- Added shared WAST static-assertion support in [`src/wast/spec_harness.mbt`](../src/wast/spec_harness.mbt):
  - `evaluate_wast_static_assertion(...)`
  - public `WastStaticAssertionKind` / `WastStaticAssertionStage` / `WastStaticAssertionResult`
  so the spec harness and the new fuzz runners now share one interpretation of `assert_malformed`, `assert_invalid`, and `assert_unlinkable` instead of drifting.
- The spec-seed lane intentionally extracts the target raw assertion S-expression from each selected `tests/spec` file before parsing it, which keeps the lane deterministic and faithful to the corpus while avoiding unrelated whole-file parser gaps later in the same large fixture.

### Validation

- Added focused fuzz-package coverage in [`src/fuzz/invalid_text_test.mbt`](../src/fuzz/invalid_text_test.mbt) for:
  - inline text strategy registry/stage coverage
  - spec-seed registry/stage coverage
  - fixed-seed deterministic text-lane stats
  - fixed-seed deterministic spec-seed stats
- Updated [`src/fuzz/main_test.mbt`](../src/fuzz/main_test.mbt) so suite inventory/help and profile-error routing now treat both `validate-invalid-text` and `validate-invalid-spec-seed` as active instead of reserved.
- Verification run for this slice:
  - `moon info`
  - `moon fmt`
  - `moon test --package jtenner/starshine/wast --file spec_harness.mbt`
  - `moon test --package jtenner/starshine/fuzz --file invalid_text_test.mbt`
  - `moon test --package jtenner/starshine/fuzz --file main_test.mbt`
  - `moon test src/wast`
  - `moon test src/fuzz`
  - `moon test src/validate`
  - `moon run src/fuzz -- validate-invalid-text smoke --seed 0x5eed`
  - `moon run src/fuzz -- validate-invalid-spec-seed smoke --seed 0x5eed`
  - `moon test`

### Exit criteria

- Text/parser rejection coverage exists as a first-class fuzz lane.
- Spec invalid/malformed/unlinkable fixtures can seed targeted randomized rejection work.
- `[FUZ]009` is complete, so `[FUZ]010` is now the next unfinished validator fuzz slice.

---

## FUZ009 Repro Persistence, Shrinkers, And Replay Corpus

**Slice id:** `[FUZ]009`

**Status:** completed 2026-04-16.

### Goal

Make invalid failures easy to replay, classify, and reduce.

### Why

The cmd fuzz harness already has useful persistence patterns. Invalid fuzz should reuse that discipline instead of returning opaque strings.

### Files most likely to change

- invalid fuzz implementation files
- [`src/validate/invalid_fuzzer.mbt`](../src/validate/invalid_fuzzer.mbt)
- [`src/fuzz/invalid_binary.mbt`](../src/fuzz/invalid_binary.mbt)
- [`src/fuzz/invalid_text.mbt`](../src/fuzz/invalid_text.mbt)
- [`src/fuzz/invalid_repro.mbt`](../src/fuzz/invalid_repro.mbt)
- [`src/fuzz/invalid_repro_test.mbt`](../src/fuzz/invalid_repro_test.mbt)

### Outcome

- Added a new shared invalid-fuzz repro surface in [`src/fuzz/invalid_repro.mbt`](../src/fuzz/invalid_repro.mbt):
  - `InvalidFuzzFailureReport`
  - `InvalidFuzzArtifact`
  - `InvalidFuzzReplayResult`
  - `InvalidFuzzPersistIO`
  - `persist_invalid_fuzz_failure_report(...)`
  - `parse_invalid_fuzz_failure_report(...)`
  - `shrink_invalid_fuzz_failure_report(...)`
  - `replay_invalid_fuzz_failure_report(...)`
- The persisted report shape now records the required deterministic repro facts in one place:
  - suite
  - profile
  - seed
  - attempt
  - strategy id
  - source kind (`ast`, `binary`, `text`, `spec-seed`)
  - expected vs actual stage
  - expected vs actual diagnostic family when relevant
  - original plus reduced artifacts
- Persistence now uses a stable per-suite/per-strategy directory layout rooted at `fuzz-corpus/invalid/<suite>/<strategy>/seed-<seed>-attempt-<attempt>/` with deterministic artifact names plus `repro.meta.txt` metadata.
- Added bounded shrink/reduce helpers for every current invalid source kind:
  - AST replay now reduces to strategy-specific minimal invalid modules via new public minimal-repro builders in [`src/validate/invalid_fuzzer.mbt`](../src/validate/invalid_fuzzer.mbt)
  - binary replay now reduces to strategy-specific minimal corrupted wasm bytes via new public minimal-repro builders in [`src/fuzz/invalid_binary.mbt`](../src/fuzz/invalid_binary.mbt)
  - inline text replay now reduces to the exact canonical single-assertion source for the chosen stable strategy id
  - spec-seed replay now reduces large `tests/spec` fixtures down to the exact extracted raw assertion S-expression already used by the lane
- Replay no longer depends on rerunning the original random loop: the saved metadata plus persisted artifact bytes are enough to re-check the rejection stage/family for AST, binary, text, and spec-seed cases directly.

### Validation

- Added focused fuzz-package coverage in [`src/fuzz/invalid_repro_test.mbt`](../src/fuzz/invalid_repro_test.mbt) for:
  - deterministic persistence layout and metadata contents
  - metadata parse/load roundtrip from persisted artifacts
  - reduced AST replay
  - reduced binary replay
  - reduced inline-text replay
  - reduced spec-seed replay
- Verification run for this slice:
  - `moon test --package jtenner/starshine/fuzz --file invalid_repro_test.mbt`
  - `moon test src/fuzz`
  - `moon test src/validate`
  - `moon run src/fuzz -- validate-invalid-ast smoke --seed 0x5eed`
  - `moon run src/fuzz -- validate-invalid-binary smoke --seed 0x5eed`
  - `moon run src/fuzz -- validate-invalid-text smoke --seed 0x5eed`
  - `moon run src/fuzz -- validate-invalid-spec-seed smoke --seed 0x5eed`

### Exit criteria

- Real invalid-fuzz failures now have a checked-in report/persistence/replay shape instead of only opaque strings.
- A fresh agent can replay or shrink a saved invalid failure directly from the persisted metadata and artifact bytes.
- `[FUZ]010` is now the next unfinished validator fuzz slice.

---

## FUZ010 Harness, Wrapper, And Docs Source-Of-Truth Alignment

**Slice id:** `[FUZ]010`

### Goal

Finish by removing drift between exported helpers, runner entrypoints, wrapper surfaces, and docs.

### Why

Without a cleanup slice, the repo will end up with widened generators and invalid lanes but still carry stale names, duplicate logic, and misleading docs.

### Files most likely to change

- [`src/fuzz/main.mbt`](../src/fuzz/main.mbt)
- [`src/validate/validate.mbt`](../src/validate/validate.mbt)
- [`src/cmd/fuzz_harness.mbt`](../src/cmd/fuzz_harness.mbt)
- [`scripts/lib/fuzz-task.ts`](../scripts/lib/fuzz-task.ts)
- README surfaces that document fuzz entrypoints
- validator-fuzz wiki pages once the active implementation catches up
- `agent-todo.md` and this doc as slices complete

### Concrete tasks

- Eliminate or intentionally justify duplicate valid-fuzz logic between:
  - `run_validate_valid_fuzz`
  - `run_validate_valid_suite`
- Keep the truthful cmd-harness helper naming aligned across Moon package interfaces, Node typings, wrapper docs, and any future generator-source changes.
- Ensure Bun wrapper surface matches Moon suite/help/output surface.
- Update active docs and wiki pages to describe only current live behavior.
- Keep this handoff doc current until the work is absorbed into more durable docs/wiki pages.

### Validation

- `moon test src/fuzz`
- wrapper command tests under `scripts/test/`
- `bun fuzz run --help`
- `bun fuzz run --list-suites`
- `bun validate readme-api-sync` if README surfaces change

### Exit criteria

- No active doc or wrapper help text lies about the fuzz stack.
- There is one source of truth for suite names, profile expectations, and runner surface behavior.

## Handoff Rules

- Keep this file as the canonical orientation document while the fuzz-stack rebuild is active.
- When a slice lands, update `agent-todo.md` first, then refresh the relevant section here if the plan or assumptions changed.
- If a slice turns into a substantial one-off investigation, archive that research under `docs/wiki/raw/research/` and link it back here.
- If the widened fuzz stack produces durable repo policy, move that policy into living docs/wiki pages and eventually retire this handoff doc.
- Keep future docs conservative: do not describe invalid lanes, generators, or reporting features until they are actually in-tree.

## Open Questions

- `--emit-gen-valid-batch` is currently pinned to `coverage-forced` mode for pass-fuzz stability; should it ever switch back to `natural` once that mode is broad enough, or should the mutation-friendly batch contract stay fixed long-term?
- Should invalid fuzz rely on exact diagnostic families only, or also allow selected exact-message assertions where the message text itself is part of the contract?
- How much of the spec corpus should be sampled in smoke vs CI vs stress without making the smoke loop too parser-heavy?
- Which richer `lib` type surfaces can be generated validly with current runtime/validator support, and which require generator or representation work first?
