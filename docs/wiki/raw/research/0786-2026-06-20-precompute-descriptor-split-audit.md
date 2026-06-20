# Precompute descriptor split audit

## Question

Close the `[AUDIT001-E]` descriptor-metadata slice for canonical pass `precompute`: prove with focused test coverage that public direct `precompute` does not require SSA while the private nested helper `precompute-propagate-prefix` does.

## Files reviewed

- `docs/README.md` — repo wiki, validation, pass, and commit policy.
- `.pi/skills/recursive-handoff/SKILL.md` — bounded recursive continuation rules.
- `.pi/skills/starshine-pass-implementation/SKILL.md` — pass descriptor and closeout requirements.
- `.pi/skills/commit/SKILL.md` — commit policy.
- `agent-todo.md` — active `[O4Z-AUDIT-PC]` and `[AUDIT001-E]` / `[AUDIT001-F]` backlog state.
- `docs/wiki/binaryen/passes/precompute/` — precompute dossier and 2026-06-20 open release-gating status.
- `docs/wiki/raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md` — status refresh that identified this descriptor-test gap.
- `docs/wiki/ir2/pass-porting-checklist.md` — descriptor metadata contract.
- `src/passes/precompute.mbt` — descriptor definitions and the only `pass_require_ssa(...)` call.
- `src/passes/registry_test.mbt` — focused descriptor/registry test surface.

## Source findings

- `precompute_descriptor()` declares direct pass name `precompute` with no `requires` analyses and invalidates `ssa` along with the other stale analyses.
- `precompute_propagate_prefix_descriptor()` declares private helper name `precompute-propagate-prefix` with `requires=[ssa]` and the same invalidation family.
- Source search found the only `pass_require_ssa(...)` call in `src/passes/precompute.mbt` inside `precompute_propagate_prefix_fold_local_gets(...)`, which is called by `precompute_propagate_prefix_run(...)` before `precompute_run(...)`. Direct `precompute_run(...)` itself does not reach that SSA helper.

## Test added

Added `src/passes/registry_test.mbt` coverage named:

- `precompute descriptor split keeps direct pass SSA-free and prefix SSA-backed`

The test proves:

- direct descriptor name is `precompute`;
- private prefix descriptor name is `precompute-propagate-prefix`;
- direct `precompute` has no `requires` metadata;
- private prefix requires exactly `ssa`;
- both descriptors invalidate `ssa` after mutation;
- `precompute-propagate-prefix` remains outside the public pass registry.

Red-first note: this was an audit/coverage slice for already-correct metadata, not an implementation bug. The existing focused registry file passed before the new test (`6/6`), and the new focused test passed without pass-code changes (`7/7`). No artificial failing metadata edit was made.

## Commands and results

- `git status --short --branch && moon test --package jtenner/starshine/passes --file registry_test.mbt`
  - Result before edits: clean branch header `## starshine-gsi`; focused registry tests passed `6/6`.
- `moon test --package jtenner/starshine/passes --file registry_test.mbt`
  - Result after adding the descriptor split test: focused registry tests passed `7/7`.
- `moon fmt && moon test --package jtenner/starshine/passes --file registry_test.mbt && git diff --check`
  - Result: formatting completed, focused registry tests passed `7/7`, and `git diff --check` produced no whitespace errors.
- `moon info && moon test src/passes && git diff --check`
  - Result: `moon info` completed with three pre-existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`; pass package tests passed `2689/2689`; `git diff --check` produced no whitespace errors.

## Classification

- `[AUDIT001-E]`: closed for `precompute` descriptor split coverage.
- `[AUDIT001-F]`: not needed for this slice because source review plus focused descriptor coverage confirms only the private prefix helper requires SSA.
- `[O4Z-AUDIT-PC]`: remains open. This slice did not add the missing dedicated precompute GenValid profile, did not run compare-pass lanes, and did not decide/recover the current `o4z-precompute-noop` gate.

## Commands not run

- No compare-pass lane was run because this slice only added descriptor metadata coverage and did not change pass behavior.
- No native `src/cmd` build was run because no compare lane or executable pass behavior changed.
- No full repo `moon test` was run; the change is focused registry coverage, and both the focused registry test and `moon test src/passes` passed.

## Next work

The next bounded slice should target one of the remaining `[O4Z-AUDIT-PC]` blockers:

1. add the dedicated `precompute-all` (or final chosen name) GenValid profile plus generator tests;
2. decide whether the O4z `o4z-precompute-noop` gate is an accepted v0.1.0 release boundary or recover a narrow safe implementation slice under O4z;
3. rebuild native `src/cmd` and refresh direct/O4z compare evidence only after the profile and gate decision are explicit.
