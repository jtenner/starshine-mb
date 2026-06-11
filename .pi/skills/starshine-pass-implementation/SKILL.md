---
name: starshine-pass-implementation
description: Implement, port, or sign off Starshine optimizer passes with the repo-standard TDD, registry, Binaryen semantic parity, performance, validity, and documentation workflow. Use when working on pass creation, pass porting, pass parity, pass fuzz compare failures, optimizer registry wiring, preset changes, or pass signoff.
---

# Starshine Pass Implementation

Use this skill for optimizer pass creation, IR2 pass ports, pass parity fixes, registry/preset wiring, and pass signoff reports.

This skill is the detailed workflow referenced by `AGENTS.md` for pass work. Treat it as the pass-specific extension of the repo-wide rules, not as a replacement for them.

## Source of Truth

Read the relevant sources before substantial pass work:

- `AGENTS.md` sections **Working On Passes** and **Validation And Signoff** for top-level policy.
- `docs/README.md` sections **Working On Passes**, **Validation And Signoff**, and **Workflow Details** for mirrored docs/wiki policy and command notes.
- `docs/wiki/ir2/pass-porting-checklist.md` for the living IR2 pass-author contract.
- `docs/0062-2026-03-24-pass-porting-checklist.md` for the numbered source behind the checklist when needed.
- `agent-todo.md` for active pass blockers, exact slices, known failures, behavior-parity inventory links, and artifact status.
- `docs/wiki/raw/research/0714-2026-06-07-o4z-behavior-parity-inventory.md` when deciding whether a previously audited/removed pass can stay closed under the behavior-parity standard.
- `src/passes/pass_common.mbt` for shared analysis, mutation, and verification helpers.
- `src/passes/pass_test_helpers.mbt` for WAT fixture and public-pipeline test helpers.
- `src/passes/optimize.mbt` for registry entries, pass categories, and preset expansion.
- `src/passes/pass_manager.mbt` for active hot-pass dispatch and module-pass execution.
- `src/cmd/cmd.mbt` when CLI flag parsing, help, or command behavior changes.

## Non-Negotiables

- Correctness first.
- Target Binaryen **behavior parity** by default. Do not treat broad instruction families, root kinds, scheduler slots, or effect classes as permanently deferrable just because they are hard; continue shrinking and implementing them until Starshine matches Binaryen-observable behavior.
- Behavior parity is stronger than "the generated module still behaves the same" and weaker than output parity: Starshine should implement the semantically relevant Binaryen transform families for the agreed pass/preset scope, while preserving WebAssembly behavior and validation. A green randomized compare lane is evidence, not a substitute for source/test review when docs still list broad missing Binaryen behavior.
- Output parity is not the target: do not require byte-for-byte wasm, raw canonical wasm/text, helper-label shape, local-numbering, or transform-for-transform parity when normalized/canonical semantic evidence proves equivalent Binaryen behavior.
- A deferral is allowed only when it is narrow, evidence-backed, and explicitly accepted by the user or tied to a concrete missing local representation/tooling blocker. Record what evidence would reopen it. Prefer implementing net-positive semantic cleanups over classifying them as merely safe drift.
- Every transform must be safe and must produce a valid wasm module.
- Pass-local performance target: Starshine should be at least 50% as fast as Binaryen on comparable pass-local measurements (`starshine_time <= 2 * binaryen_time`) unless a slower result is explicitly accepted or attributed outside the pass.
- Use TDD: add or update tests first and confirm the intended failure when practical.
- Prefer canonical `--pass <name>` harness runs over broad combined-pass runs during pass development.
- Unknown pass names must reject; never land silent no-op behavior for missing passes.
- Keep hot pass descriptors truthful: `requires` must list needed analyses and `invalidates` must list stale analyses after mutation.
- Mutate through public hot-IR APIs and shared pass helpers; do not reach into storage internals directly.
- Do not widen `optimize`/`shrink` preset behavior before the direct pass is correct and separately signable.
- Do not remove or close an audit item while the pass dossier or inventory still says the pass is a narrow subset, lacks broad Binaryen behavior, or has unclassified behavior gaps. Either reopen/keep a backlog slice, or record a narrow explicit non-goal with user approval and reopening criteria.
- Keep release blockers and known failures visible in `agent-todo.md` until resolved.
- If signoff cannot be run, say exactly which command was not run and why; do not imply completion.

## Implementation Workflow

1. Frame the pass.
   - Identify the canonical Binaryen/Starshine pass name.
   - Use `bun scripts/pass-fuzz-compare.ts --list-passes` when the supported name is uncertain.
   - Decide whether the work is a new pass, IR2 port, parity fix, performance fix, preset ordering change, or signoff-only task.
   - Check `agent-todo.md` and relevant docs for active blockers, saved repro dirs, and known Binaryen divergences.

2. Classify the execution shape.
   - Hot/function pass: provide a `HotPassDescriptor`, registry entry, dispatcher arm, and `*_run` implementation.
   - Module pass: provide the registry entry and route through the module-pass application path.
   - Boundary-only or removed pass: keep registry classification explicit and reject active execution until the real port lands.
   - Preset work: prove the direct pass first, then update preset expansion/order only with dedicated tests and artifact evidence.

3. Write tests first.
   - Add or update adjacent `src/passes/<pass>_test.mbt` or `*_wbtest.mbt` coverage.
   - Prefer WAT fixtures and `pass_test_run_pipeline(...)` for public-pipeline behavior.
   - Add `src/passes/registry_test.mbt` or pass-manager tests when names, categories, dispatch, help entries, or public flags change.
   - Add `src/cmd` tests when CLI parsing or user-visible pass flags change.
   - Preserve reduced mismatch repros as focused tests when the bug came from `pass-fuzz-compare`.
   - Avoid telemetry-only tests: every test should guard behavior, an invariant, a regression, or a user-visible error.

4. Implement through shared helpers.
   - Use `pass_prepare_requirements(...)` or specific `pass_require_*` helpers instead of ad hoc overlay construction.
   - Use shared mutation wrappers such as `pass_replace_node(...)`, `pass_splice_region(...)`, and `pass_delete_detached_nodes(...)` where they fit.
   - Call `pass_mark_mutated(...)` for mutation flows outside shared wrappers.
   - Use `pass_node_use_count(...)` or `pass_node_is_unused(...)` before detached-node cleanup decisions.
   - Keep structured-region edits local and explicit.
   - Verify with `pass_verify_before_after(...)`.
   - Let revision-keyed invalidation clear stale overlays after mutation; do not hand-preserve caches unless the helper layer supports it.

5. Wire all public surfaces.
   - Implementation: usually `src/passes/<pass>.mbt`.
   - Registry and presets: `src/passes/optimize.mbt`.
   - Hot dispatch and module execution: `src/passes/pass_manager.mbt`.
   - CLI/pass flag exposure: usually `src/cmd/cmd.mbt`.
   - Package imports: `package*/imports.mbt` when new imports are needed.
   - Public API snapshots: review `.mbti` diffs when public surfaces change.
   - Docs/backlog: update relevant docs and `agent-todo.md` before commit when behavior or status changes; do not add per-commit changelog entries.

6. Handle mismatches and gaps deliberately.
   - Classify mismatch families as an agent judgment in the report, not as a script-determined truth. Use categories such as behavior-parity match despite output drift, representation-only, size-losing, unknown/risky, validation failure, tool/Binaryen failure, true semantic mismatch, or intentionally deferred with approval.
   - Do not call a mismatch semantically safe merely because both outputs validate or because Starshine's canonical output is smaller. Validity and size are supporting evidence only. A semantic-safe classification needs an inspected transform contract, diff-family analysis, replay evidence, or another explicit semantic argument.
   - Treat recurring representation drift as implementation work when it is a net-positive semantic cleanup or needed to clear direct compare lanes; do not default to “accepted drift.”
   - Classify semantic mismatches separately from decode, validation, tool, or Binaryen parser failures.
   - Replay saved failure dirs after fixes.
   - Promote durable repros into tests.
   - Document unresolved differences with exact command, seed, out dir, failure class, agent classification, why behavior parity is currently blocked, who approved the deferral if applicable, and what evidence or missing API would reopen it.

## Signoff Ladder

Run Moon commands serially because `_build/.moon-lock` is shared.

### Focused pass signoff

Use during the implementation loop:

1. `moon test src/passes`
2. `moon test src/cmd` when CLI, registry, flags, or pass dispatch changed
3. Focused replay for saved repros or reduced cases
4. Any package-specific Moon test touched by the change

### Standard pass signoff

Use during implementation and before ordinary commit-sized parity slices:

1. `moon info`
2. `moon fmt`
3. `moon test`
4. `moon build --target native --release src/cmd`
5. `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass <canonical-name> --out-dir .tmp/pass-fuzz-<name> --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`

Equivalent direct entrypoint:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass <canonical-name> --out-dir .tmp/pass-fuzz-<name> --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

### Final pass closeout signoff

Use before declaring a pass closed, audit-complete, or behavior-parity complete. This is stronger than ordinary slice signoff:

1. `moon info`
2. `moon fmt`
3. focused pass tests, e.g. `moon test --package jtenner/starshine/passes --file <pass>_test.mbt`
4. `moon test src/passes`
5. `moon test`
6. `moon build --target native --release src/cmd`
7. `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass <canonical-name> --out-dir .tmp/pass-fuzz-<name>-final-100000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`

Final closeout must use the `100000`-case direct pass lane, not the ordinary `10000`-case slice lane, unless the user explicitly approves a smaller run for that specific closeout.

### Pass-specific generator fuzz lanes

Some passes have dedicated in-repo GenValid profiles that intentionally generate shapes the general alternating smith/GenValid lane may hit only rarely. When a pass has a named profile, when you change `src/validate/gen_valid*`, or when an audit mentions pass-specific generated shapes, add a separate `compare-pass` lane with `--gen-valid-profile <profile>` after the standard direct lane.

For ordinary implementation slices, use at least `10000` requested cases for the dedicated profile. For final closeout or audit-close claims, use a wider dedicated-profile lane unless the user explicitly approves a smaller run:

```sh
bun scripts/pass-fuzz-compare.ts --count 50000 --seed 0x551a --pass <canonical-name> --gen-valid-profile <profile> --out-dir .tmp/pass-fuzz-<name>-genvalid-<profile>-50000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Current dedicated pass-profile examples:

- `ssa-nomerge`: run `ssa-nomerge-coverage` for shape breadth, `ssa-nomerge-smoke` for quick structured-branch SSA coverage smoke, and `ssa-nomerge-parity` when the slice specifically changed parity-safe SSA generator templates. Use explicit out dirs such as `.tmp/pass-fuzz-ssa-nomerge-genvalid-coverage-50000`. If the user asks for “ssa-genvalid fuzz”, treat this as `--pass ssa-nomerge --gen-valid-profile ssa-nomerge-coverage` unless they specify another SSA profile.

Report dedicated-profile lanes separately from the general compare lane: profile name, requested count, compared count, normalized matches, cleanup-normalized matches, raw mismatches, command failures, and any profile-specific feature-floor or generation failures.

For DAE / `dae-optimizing` mixed-generator lanes, add the documented compare normalizer so generated dropped-constant debris does not consume the mismatch budget:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Report exact `normalizedMatchCount`, `cleanupNormalizedMatchCount`, remaining `mismatchCount`, and command-failure classes separately.

Required result:

- Binaryen behavior parity for the targeted pass, not merely “no known catastrophic semantic bug.”
- `10000` compared cases for ordinary implementation slices, and `100000` requested cases for final pass closeout when the harness can complete that many valid comparisons.
- Dedicated GenValid pass-profile lanes run when applicable (`10000` ordinary; wider, e.g. `50000`, for final/audit-close or generator-widening work), and their results are reported separately from the general lane.
- Zero true semantic mismatches, and no broad unapproved family deferrals hidden behind “safe drift.”
- Command failures classified separately from semantic mismatches.
- Raw wasm/text or transform-shape differences are not failures when normalized/canonical semantic comparison is green and the observed behavior matches Binaryen.
- Replayable failure dirs preserved until fixed, documented with explicit approval for a narrow deferral, or intentionally discarded after triage.

### Performance and artifact signoff

Add when the pass affects hot paths, a preset, or a known artifact:

1. Record pass-local Starshine and Binaryen timings where the harness reports them.
2. Treat pass-local performance as acceptable when Starshine is at least 50% as fast as Binaryen (`starshine_time <= 2 * binaryen_time`), unless the user sets a stricter target for the pass.
3. Attribute aggregate whole-command wall-time gaps to the top-level `[WALL]001` backlog slice unless the root cause is clearly inside the pass implementation.
4. Compare the relevant artifact, ordered prefix, or preset run when the pass participates in a documented optimize path; prefer semantic/canonical equality over raw wasm/text equality unless raw bytes are explicitly in scope.
5. Ask before running long self-optimize commands, especially:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --optimize
```

### Preset signoff

Use when changing `optimize`, `shrink`, or pass order:

1. Prove each directly touched pass under its own `--pass <name>` run first.
2. Add tests that lock the new preset expansion or ordering.
3. Compare the documented artifact or ordered-prefix path that motivated the preset change.
4. Document repeated cleanup slots; do not collapse repeated Binaryen slots unless the divergence is intentional and recorded.

### Commit-ready signoff

Use before committing pass work:

1. Update relevant docs.
2. Prune completed pass items from `agent-todo.md`; keep active blockers visible.
3. Prefer `bun validate` before commit.
4. Use `bun validate readme-api-sync` for README/API drift.
5. Use `bun validate full --profile ci --target wasm-gc` for the local full gate when requested or warranted.
6. Review the staged diff, including `.mbti` changes.
7. Commit with a message that includes changed files plus reasons.

## Signoff Report Template

When reporting pass signoff, include:

- pass name and category: hot/function, module, boundary-only/removed, or preset
- goal and scope of the change
- files changed
- tests added or updated
- focused Moon command results
- standard Moon signoff results: `moon info`, `moon fmt`, `moon test`
- general compare-pass command, seed, out dir, explicit `--jobs auto`, explicit `--starshine-bin`, requested count (`10000` for ordinary slices or `100000` for final closeout), compared count, normalized match count, cleanup-normalized match count when `--normalize ...` is used, raw mismatch count, and command-failure classification
- pass-specific GenValid compare-pass lanes, if applicable: `--gen-valid-profile`, seed, out dir, requested count (`10000` for ordinary slices, wider e.g. `50000` for final/audit-close lanes), compared count, normalized match count, cleanup-normalized match count, raw mismatch count, command failures, and feature-generation/floor failures
- agent-classified mismatch breakdown, with explicit rationale for any semantic-safe/size-winning mismatch family; never imply the harness proved semantic safety
- replayed failure dirs and their outcomes, if any
- pass-local performance numbers, artifact comparisons, any `[WALL]001` attribution, or why they were not applicable
- docs and backlog updates
- remaining blockers, uncertainty, or explicitly deferred Binaryen differences
- commands not run and why

## Done Definition

A pass is done only when:

- public behavior is protected by tests
- registry, dispatcher, CLI, and preset surfaces are wired or explicitly out of scope
- direct pass execution matches Binaryen behavior on the required compare-pass run: `10000` for ordinary slices and `100000` for final pass closeout; a green lane must be cross-checked against source/docs so broad missing transform families are not hidden as "no mismatches"
- any dedicated GenValid pass profile relevant to the pass or touched generator code has its own reported compare lane (`10000` ordinary, wider e.g. `50000` for final/audit-close), or the report explicitly states why it was not applicable or not run
- any remaining behavior divergence or unimplemented family is narrow, evidence-backed, explicitly approved, and documented with reopening criteria; otherwise the audit stays active or is reopened
- every transform is covered as safe and valid, with validation evidence for changed modules when applicable
- relevant performance/artifact evidence is captured when applicable, and pass-local Starshine timing is at least 50% of Binaryen speed unless explicitly accepted
- docs/backlog updates are complete
- the final report states exact evidence instead of broad claims
