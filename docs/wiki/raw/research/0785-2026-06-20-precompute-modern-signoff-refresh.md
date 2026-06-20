# Precompute modern signoff refresh

## Question

Refresh the current release-gating state for canonical pass `precompute` under the repo's modern pass-audit/signoff standard. Determine whether `[O4Z-AUDIT-PC]` is ready for final closeout or needs a docs/status refresh, pass-specific GenValid profile work, direct/O4z evidence refresh, descriptor metadata work, or an active implementation slice.

## Files reviewed

- `docs/README.md` — repo docs/wiki schema, pass signoff, validation, and commit policy.
- `.pi/skills/recursive-handoff/SKILL.md` — bounded recursive slice and continuation rules.
- `.pi/skills/starshine-pass-implementation/SKILL.md` — modern pass closeout matrix and pass-specific GenValid profile requirements.
- `.pi/skills/commit/SKILL.md` — commit policy for this slice.
- `agent-todo.md` — active `[O4Z-AUDIT-PC]` and descriptor audit `[AUDIT001-E]` / `[AUDIT001-F]` context.
- `docs/wiki/binaryen/passes/precompute/` — current precompute dossier, especially `index.md`, `fuzzing.md`, `starshine-hot-ir-strategy.md`, and `starshine-port-readiness-and-validation.md`.
- `docs/wiki/ir2/pass-porting-checklist.md` — descriptor and analysis metadata contract.
- `src/passes/precompute.mbt` — direct pass, private `precompute-propagate-prefix`, raw fast paths, and descriptors.
- `src/passes/precompute_test.mbt` and `src/passes/perf_test.mbt` — focused direct behavior, O4z raw skip, raw shortcut, and perf trace coverage.
- `src/passes/pass_manager.mbt` — direct dispatch, O4z raw no-op gate, nested cleanup use of `precompute-propagate-prefix`, and writeback guards.
- `src/passes/optimize.mbt` — registry and removed public `precompute-propagate` name.
- `src/validate/gen_valid.mbt` and `src/validate/gen_valid_tests.mbt` — available named GenValid profiles.

## Cheap discovery commands

- `git status --short && bun scripts/pass-fuzz-compare.ts --list-passes | grep precompute`
  - Result: worktree was clean and the supported compare-pass name printed `precompute`.
- `git status --short --branch`
  - Result: `## starshine-gsi`; no modified files at discovery time.
- `ls target/native/release/build/cmd`
  - Result: path missing, so no prebuilt native `cmd.exe` was available for a fresh compare lane.
- `find .tmp -name 'pass-fuzz-precompute*'`
  - Result: no local precompute compare output dirs were present in this checkout.
- `find .artifacts -name '*precompute*'`
  - Result: `.artifacts` is not present in this checkout, so older generated O4z replay paths remain historical identifiers only.
- Source search found no `precompute` GenValid profile constructors in `src/validate/gen_valid.mbt`; the broad modern named lane available today is `pass-fuzz-stress`.

## Findings

### 1. `[O4Z-AUDIT-PC]` is not closeable under the modern standard

The older branch-heavy direct lane remains useful evidence, but it is below the current final closeout bar. The modern pass skill requires four separate closeout lanes before claiming the pass closed: regular GenValid `100000`, explicit wasm-smith `10000`, a pass-specific GenValid profile `10000`, and a broad named/random all-profiles lane. `docs/wiki/binaryen/passes/precompute/fuzzing.md` still documented no dedicated profile before this refresh, so the final closeout matrix cannot be completed yet.

### 2. The O4z slot story is stale unless it explicitly mentions the current no-op gate

`src/passes/pass_manager.mbt` currently returns `o4z-precompute-noop` for direct `precompute` when `optimize_level >= 4 && shrink_level >= 1`. `src/passes/precompute_test.mbt` has focused coverage named `precompute skips O4z raw pass until self-opt ownership hazards are safe`.

That means a current O4z slot refresh cannot honestly say the PC slots are doing ordinary direct `precompute` work in `-O4z`. The release-gating state is: direct `--pass precompute` has useful behavior and older branch-heavy evidence, but current public O4z preset execution intentionally fail-closes/no-ops precompute slots until the self-opt ownership hazards are narrowed or the release explicitly accepts the no-op with reopening criteria.

### 3. Descriptor metadata likely splits as expected, but still needs the existing focused audit test

`precompute_descriptor()` declares no `requires`, while `precompute_propagate_prefix_descriptor()` declares `requires=[ssa]`. Source review found `pass_require_ssa(...)` only in `precompute_propagate_prefix_fold_local_gets(...)`, called by `precompute_propagate_prefix_run(...)`, not by direct `precompute_run(...)`. That supports the expected `[AUDIT001-E]` / `[AUDIT001-F]` split: direct `precompute` probably does not need `ssa`, while the private prefix helper does.

This refresh did not add the focused descriptor test, so the descriptor audit remains open as backlog rather than closed by prose.

### 4. No new semantic bug was implemented in this slice

I did not find a fresh reduced semantic mismatch during this bounded docs/status refresh. The newly highlighted release-gating gaps are evidence/profile/status gaps plus the existing O4z no-op gate, not a newly reduced direct-pass transform bug. Therefore no red-first behavior test or pass implementation was attempted in this iteration.

## Current classification

- Pass name: canonical `precompute`.
- Category: active direct hot/function pass; private nested helper `precompute-propagate-prefix` is also a hot pass descriptor but is not the public upstream `precompute-propagate` pass.
- Current release-gating state: open.
- Needed next work:
  1. add a dedicated precompute GenValid profile and focused generator tests;
  2. add focused descriptor metadata tests for direct `precompute` vs `precompute-propagate-prefix`;
  3. decide whether to recover safe O4z precompute work or keep the `o4z-precompute-noop` as an explicitly approved release boundary;
  4. rebuild native `src/cmd` and run modern direct/final closeout lanes only after the profile and O4z status are explicit;
  5. refresh O4z slot/neighborhood evidence with either the current skip traces or recovered behavior.

## Commands not run

- No `moon` validation was run because this slice changed docs/backlog only and did not change executable behavior.
- No fresh compare-pass lane was run because `target/native/release/build/cmd/cmd.exe` was missing and this iteration was intentionally a cheap discovery + docs/status refresh first.
- No final closeout lanes were run because the pass-specific GenValid profile does not exist yet.

## Backlog/docs updates made by this slice

- `agent-todo.md` should now make `[O4Z-AUDIT-PC]` explicit about the modern profile/four-lane evidence gap, the O4z no-op gate, the descriptor audit dependency, and the final closeout requirements.
- `docs/wiki/binaryen/passes/precompute/fuzzing.md` should now state that no dedicated precompute profile exists and describe the intended profile families before final signoff.
- `docs/wiki/binaryen/passes/precompute/index.md` and `starshine-port-readiness-and-validation.md` should now record the 2026-06-20 open release-gating state.
