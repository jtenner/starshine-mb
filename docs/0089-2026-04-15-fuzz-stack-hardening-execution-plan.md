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
  - `binary-roundtrip`
  - `cmd-harness`
- `src/fuzz/main.mbt` also reserves these accepted-but-not-yet-runnable suite ids for the later rejection lanes, and reports them as reserved in help/list output instead of pretending they are live:
  - `validate-invalid-ast`
  - `validate-invalid-binary`
  - `validate-invalid-text`
  - `validate-invalid-spec-seed`
- `src/fuzz/main.mbt` has a real `--emit-gen-valid-batch` surface, and `scripts/lib/pass-fuzz-compare-task.ts` depends on it for the `gen-valid` half of mixed pass fuzzing.
- `src/validate/gen_valid.mbt` currently produces a narrow valid module family:
  - singleton function-type rec entries
  - small defined-function set
  - optional globals
  - one function export named `main`
  - very small body statement vocabulary
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

---

## FUZ003 Multi-Mode Valid Topology Generator

**Slice id:** `[FUZ]003`

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

---

## FUZ004 Environment-Aware Body Generation And Type Widening

**Slice id:** `[FUZ]004`

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

### Validation

- `validate-valid` smoke must stay green
- binary roundtrip on emitted modules must stay green
- WAT companion stability must not collapse unexpectedly in CI/stress
- add focused tests for any new helper that manages labels, return types, or index selection

### Exit criteria

- Valid generated bodies exercise substantially more validator surface than the current flat stub generator.
- The generator can emit meaningful structured control flow and section-dependent instructions without frequent accidental invalidity.

---

## FUZ005 Generator Observability And Coverage Floors

**Slice id:** `[FUZ]005`

### Goal

Make generator breadth measurable so the new wider generator cannot silently regress back into a narrow shape.

### Why

Without explicit feature reporting, generation drift is invisible and later agents will not know whether the widened generator is still doing useful work.

### Files most likely to change

- [`src/validate/gen_valid.mbt`](../src/validate/gen_valid.mbt)
- [`src/fuzz/main.mbt`](../src/fuzz/main.mbt)
- exported stats surfaces if needed

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

---

## FUZ006 AST Invalid Mutator Registry And Diagnostic Accounting

**Slice id:** `[FUZ]006`

### Goal

Reintroduce an explicit AST-level invalid/rejection fuzz engine with honest per-strategy accounting.

### Why

This is the core missing rejection layer in the current tree. The older docs describe it, but the code is gone from this workspace.

### Files most likely to change

- likely a new [`src/validate/invalid_fuzzer.mbt`](../src/validate)
- [`src/fuzz/main.mbt`](../src/fuzz/main.mbt)
- [`src/fuzz/imports.mbt`](../src/fuzz/imports.mbt)
- [`src/validate/validate.mbt`](../src/validate/validate.mbt) only if new tests expose validator issues
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

### Validation

- dedicated unit tests proving selected strategies really mutate the module and map to the intended diagnostic family
- `moon run src/fuzz -- validate-invalid-ast smoke --seed 0x5eed` once suite exists
- smoke profile must exercise a curated required subset on every run

### Exit criteria

- The tree has a real AST invalid fuzz lane again.
- Coverage accounting is strategy-aware and diagnostic-aware rather than just “got some error”.

---

## FUZ007 Binary Invalid Corruption Lane

**Slice id:** `[FUZ]007`

### Goal

Add a binary corruption lane that can test malformed decode behavior and decode-valid / validate-invalid boundaries that AST mutation cannot express.

### Why

AST mutation alone cannot cover malformed section order, bad lengths, malformed LEBs, UTF-8 corruption, or other byte-level rejection families.

### Files most likely to change

- invalid fuzz implementation files under `src/validate/` and `src/fuzz/`
- possibly helpers under `src/binary/` only if reusable decode utilities are needed
- runner and wrapper tests

### Concrete tasks

- Encode valid seeds, then mutate bytes.
- Add corruption families such as:
  - duplicate sections
  - wrong section order
  - truncated payloads
  - incorrect section lengths
  - malformed LEB encodings
  - invalid immediates / alignments / lane values where practical
  - malformed UTF-8 in names or custom payloads
  - code count mismatch
  - trailing garbage
- Bucket results as:
  - decode malformed / parser rejected
  - decode succeeded but validate rejected
  - unexpectedly accepted
- Start with valid seeds from:
  - widened `gen_valid`
  - saved emitted batch artifacts
  - optional wasm-smith outputs later if needed

### Validation

- `moon run src/fuzz -- validate-invalid-binary smoke --seed 0x5eed`
- dedicated tests for a few deterministic corruption families
- verify persisted repros decode or fail in the expected stage

### Exit criteria

- The tree has a binary-invalid lane distinct from AST invalidation.
- Malformed-vs-invalid stage distinctions are visible in the report surface.

---

## FUZ008 Text And Spec-Seed Invalid Lane

**Slice id:** `[FUZ]008`

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

### Validation

- `moon run src/fuzz -- validate-invalid-text smoke --seed 0x5eed`
- `moon run src/fuzz -- validate-invalid-spec-seed smoke --seed 0x5eed`
- focused deterministic tests for seed extraction and categorization

### Exit criteria

- Text/parser rejection coverage exists as a first-class fuzz lane.
- Spec invalid/malformed/unlinkable fixtures can seed targeted randomized rejection work.

---

## FUZ009 Repro Persistence, Shrinkers, And Replay Corpus

**Slice id:** `[FUZ]009`

### Goal

Make invalid failures easy to replay, classify, and reduce.

### Why

The cmd fuzz harness already has useful persistence patterns. Invalid fuzz should reuse that discipline instead of returning opaque strings.

### Files most likely to change

- invalid fuzz implementation files
- [`src/cmd/fuzz_harness.mbt`](../src/cmd/fuzz_harness.mbt) if helper extraction/reuse is worth it
- [`src/fuzz/main.mbt`](../src/fuzz/main.mbt)
- wrapper/tests

### Concrete tasks

- Define a validator-invalid failure report shape that can persist:
  - suite
  - profile
  - seed
  - strategy id
  - stage
  - expected vs actual diagnostic family
  - source kind (AST / binary / text / spec-seed)
  - module/text/bytes artifacts where relevant
- Persist deterministic repro material to a stable directory layout.
- Add at least small, bounded shrink/reduce helpers for:
  - AST mutation replay
  - byte mutation replay
  - text mutation replay
- Make replay possible without the original random run.

### Validation

- deterministic persistence tests similar in spirit to the existing cmd harness persistence tests
- one replay test per source kind once the suites exist

### Exit criteria

- Real invalid-fuzz failures produce actionable artifacts, not just log lines.
- A fresh agent can replay a saved invalid failure directly from the persisted metadata.

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

- Should `--emit-gen-valid-batch` default to `natural` mode once that mode is strong enough, or remain pinned to a mutation-friendly batch mode for pass-fuzz stability?
- Should invalid fuzz rely on exact diagnostic families only, or also allow selected exact-message assertions where the message text itself is part of the contract?
- How much of the spec corpus should be sampled in smoke vs CI vs stress without making the smoke loop too parser-heavy?
- Which richer `lib` type surfaces can be generated validly with current runtime/validator support, and which require generator or representation work first?
