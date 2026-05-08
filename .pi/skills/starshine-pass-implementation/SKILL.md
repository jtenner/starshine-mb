---
name: starshine-pass-implementation
description: Implement, port, or sign off Starshine optimizer passes with the repo-standard TDD, registry, Binaryen parity, performance, and documentation workflow. Use when working on pass creation, pass porting, pass parity, pass fuzz compare failures, optimizer registry wiring, preset changes, or pass signoff.
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
- `agent-todo.md` for active pass blockers, exact slices, known failures, and artifact status.
- `src/passes/pass_common.mbt` for shared analysis, mutation, and verification helpers.
- `src/passes/pass_test_helpers.mbt` for WAT fixture and public-pipeline test helpers.
- `src/passes/optimize.mbt` for registry entries, pass categories, and preset expansion.
- `src/passes/pass_manager.mbt` for active hot-pass dispatch and module-pass execution.
- `src/cmd/cmd.mbt` when CLI flag parsing, help, or command behavior changes.

## Non-Negotiables

- Correctness first.
- Match Binaryen oracle behavior at minimum, unless a deliberate divergence is explicitly documented.
- Use TDD: add or update tests first and confirm the intended failure when practical.
- Prefer canonical `--pass <name>` harness runs over broad combined-pass runs during pass development.
- Unknown pass names must reject; never land silent no-op behavior for missing passes.
- Keep hot pass descriptors truthful: `requires` must list needed analyses and `invalidates` must list stale analyses after mutation.
- Mutate through public hot-IR APIs and shared pass helpers; do not reach into storage internals directly.
- Do not widen `optimize`/`shrink` preset behavior before the direct pass is correct and separately signable.
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
   - Docs/backlog: update relevant docs, `CHANGELOG.md`, and `agent-todo.md` before commit when behavior or status changes.

6. Handle mismatches deliberately.
   - Classify semantic mismatches separately from decode, validation, tool, or Binaryen parser failures.
   - Replay saved failure dirs after fixes.
   - Promote durable repros into tests.
   - Document unresolved differences with exact command, seed, out dir, failure class, and reason they are deferred.

## Signoff Ladder

Run Moon commands serially because `_build/.moon-lock` is shared.

### Focused pass signoff

Use during the implementation loop:

1. `moon test src/passes`
2. `moon test src/cmd` when CLI, registry, flags, or pass dispatch changed
3. Focused replay for saved repros or reduced cases
4. Any package-specific Moon test touched by the change

### Standard pass signoff

Use before declaring a pass complete:

1. `moon info`
2. `moon fmt`
3. `moon test`
4. `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass <canonical-name> --out-dir .tmp/pass-fuzz-<name>`

Equivalent direct entrypoint:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass <canonical-name> --out-dir .tmp/pass-fuzz-<name>
```

Required result:

- Binaryen parity at minimum.
- `10000` compared cases when the harness can complete that many valid comparisons.
- Zero semantic mismatches.
- Command failures classified separately from semantic mismatches.
- Replayable failure dirs preserved until fixed, documented, or intentionally discarded after triage.

### Performance and artifact signoff

Add when the pass affects hot paths, a preset, or a known artifact:

1. Record pass-local Starshine and Binaryen timings where the harness reports them.
2. Attribute aggregate whole-command wall-time gaps to the top-level `[WALL]001` backlog slice unless the root cause is clearly inside the pass implementation.
3. Compare the relevant artifact, ordered prefix, or preset run when the pass participates in a documented optimize path.
4. Ask before running long self-optimize commands, especially:

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

1. Update relevant docs and `CHANGELOG.md`.
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
- `10000` compare-pass command, seed, out dir, compared count, normalized match count, mismatch count, and command-failure classification
- replayed failure dirs and their outcomes, if any
- pass-local performance numbers, artifact comparisons, any `[WALL]001` attribution, or why they were not applicable
- docs, changelog, and backlog updates
- remaining blockers, uncertainty, or explicitly deferred Binaryen differences
- commands not run and why

## Done Definition

A pass is done only when:

- public behavior is protected by tests
- registry, dispatcher, CLI, and preset surfaces are wired or explicitly out of scope
- direct pass execution matches Binaryen on the standard compare-pass run or any divergence is approved and documented
- relevant performance/artifact evidence is captured when applicable
- docs/changelog/backlog updates are complete
- the final report states exact evidence instead of broad claims
