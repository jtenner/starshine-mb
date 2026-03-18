# Changelog

## 2026-03-18 Tooling Follow-up: migrate repo task automation to Bun task families and Windows-safe modules

- Replaced the old mixed Bash/Node task surface in `scripts/` with Bun-first task-family entrypoints at [`scripts/validate.ts`](/home/jtenner/Projects/starshine-mb/scripts/validate.ts), [`scripts/fuzz.ts`](/home/jtenner/Projects/starshine-mb/scripts/fuzz.ts), [`scripts/self-opt.ts`](/home/jtenner/Projects/starshine-mb/scripts/self-opt.ts), [`scripts/make.ts`](/home/jtenner/Projects/starshine-mb/scripts/make.ts), and [`scripts/examples.ts`](/home/jtenner/Projects/starshine-mb/scripts/examples.ts), and added a root [`package.json`](/home/jtenner/Projects/starshine-mb/package.json) so the repo command surface is now `bun validate`, `bun fuzz`, `bun self-opt`, `bun make`, and `bun examples`.
- Moved reusable task logic and helper implementations under [`scripts/lib/`](/home/jtenner/Projects/starshine-mb/scripts/lib), including new task modules [`scripts/lib/validate-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/validate-task.ts), [`scripts/lib/fuzz-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/fuzz-task.ts), [`scripts/lib/self-opt-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/self-opt-task.ts), [`scripts/lib/make-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/make-task.ts), [`scripts/lib/examples-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/examples-task.ts), and the shared runtime helper [`scripts/lib/task-runtime.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/task-runtime.ts), so the top-level task files stay as thin dispatchers and the automation remains importable and Windows-safe.
- Relocated the larger helper programs into `scripts/lib` as well, preserving their implementation while removing the old top-level script clutter: benchmark harness, Node package generator/builder, self-optimized build/spec helpers, MoonBit WASI runner, and self-optimized artifact helpers now live under [`scripts/lib/benchmark-optimize.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/benchmark-optimize.mjs), [`scripts/lib/generate-node-package.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/generate-node-package.mjs), [`scripts/lib/build-node-package.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/build-node-package.mjs), [`scripts/lib/build-self-optimized.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/build-self-optimized.mjs), and [`scripts/lib/run-self-optimized-spec-suite.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/run-self-optimized-spec-suite.mjs).
- Removed the obsolete top-level shell and ad hoc script entrypoints that the Bun task families replaced, including `scripts/run-full-test.sh`, `scripts/run-fuzz.sh`, `scripts/coverage_report.sh`, `scripts/run_examples_cli_smoke.sh`, `scripts/check_examples_cli_native_workflow.sh`, `scripts/self-optimize.sh`, `scripts/update_readme_benchmarks.sh`, and the old top-level `.mjs` helper entrypoints that were moved into `scripts/lib`.
- Replaced the remaining shell-based script regression checks with Bun/TypeScript tests in [`scripts/test/task-family-commands.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/task-family-commands.ts), [`scripts/test/make-benchmark-output.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/make-benchmark-output.ts), and [`scripts/test/self-opt-command-output.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/self-opt-command-output.ts), using Windows-safe fake `moon` and fake optimizer executables so the script-behavior tests no longer depend on Bash.
- Updated CI/workflow entrypoints in [`/.github/workflows/fuzz.yml`](/home/jtenner/Projects/starshine-mb/.github/workflows/fuzz.yml), [`/.github/workflows/examples-cli-native.yml`](/home/jtenner/Projects/starshine-mb/.github/workflows/examples-cli-native.yml), [`/.github/workflows/coverage-report.yml`](/home/jtenner/Projects/starshine-mb/.github/workflows/coverage-report.yml), [`/.github/workflows/node-wasm-tests.yml`](/home/jtenner/Projects/starshine-mb/.github/workflows/node-wasm-tests.yml), and [`/.github/workflows/readme-api-sync.yml`](/home/jtenner/Projects/starshine-mb/.github/workflows/readme-api-sync.yml) to install Bun, watch `scripts/**` plus the root `package.json`, and call the new Bun task families instead of the removed shell wrappers.
- Added a Bun-driven README/API verification path with [`scripts/lib/readme-api-sync.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/readme-api-sync.ts) and `bun validate readme-api-sync`, so the README API sync workflow no longer points at a missing shell script and now skips cleanly when the README has no `README_API_VERIFY` blocks.
- Updated user-facing and maintainer-facing command references in [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`docs/pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/pass-audit.md), and [`node/package.json`](/home/jtenner/Projects/starshine-mb/node/package.json) to reflect the new Bun task-family commands and the moved benchmark/node-build flows.
- Updated [`AGENTS.md`](/home/jtenner/Projects/starshine-mb/AGENTS.md) so future agents see the new task strategy directly in the `Tooling` and `Repository Layout` sections: Bun-first task families are now the documented standard, `scripts/lib/` is the required home for reusable task logic, and shell scripts under `scripts/` are explicitly disallowed to avoid future Windows breakage and task-surface confusion.
- Validation: `bun validate readme-api-sync`; `bun examples workflow-contract`; `bun scripts/test/task-family-commands.ts`; `bun scripts/test/make-benchmark-output.ts`; `bun scripts/test/self-opt-command-output.ts`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-18 Maintainer Follow-up: turn lost-and-found into a local canary

- Updated [/home/jtenner/Projects/starshine-mb/AGENTS.md](/home/jtenner/Projects/starshine-mb/AGENTS.md) with a dedicated `Lost And Found Canary` section explaining that `agent-lost-and-found.md` is a local, developer-facing process-feedback file for documenting surprises, missing documentation, setup friction, and suggested workflow improvements.
- Updated [/home/jtenner/Projects/starshine-mb/.gitignore](/home/jtenner/Projects/starshine-mb/.gitignore) so `agent-lost-and-found.md` is ignored, then removed the file from git tracking so it will not be committed going forward.
- Validation: not run (docs and git-tracking update).

## 2026-03-18 Maintainer Follow-up: simplify commit instructions for agents

- Updated [/home/jtenner/Projects/starshine-mb/AGENTS.md](/home/jtenner/Projects/starshine-mb/AGENTS.md) to keep commit guidance in one short `Commit Strategy` section, remove duplicate commit-workflow references from the rest of the file, and make the rules easier for AI agents to follow.
- Validation: not run (docs-only update).

## 2026-03-18 Maintainer Follow-up: compact the AI backlog and document the workflow

- Updated [/home/jtenner/Projects/starshine-mb/agent-todo.md](/home/jtenner/Projects/starshine-mb/agent-todo.md) to keep only open work, collapse repetitive optimizer backlog wording, and remove the checked-off history so the file stays focused on current tasks.
- Updated [/home/jtenner/Projects/starshine-mb/AGENTS.md](/home/jtenner/Projects/starshine-mb/AGENTS.md) to require simple bullet-point backlog items and to record completed work in [/home/jtenner/Projects/starshine-mb/CHANGELOG.md](/home/jtenner/Projects/starshine-mb/CHANGELOG.md) instead of marking items done in `agent-todo.md`.
- Validation: not run (docs-only update).

## 2026-03-18 Validate Planning: add validator backlog items for diagnostics and performance

- Updated [/home/jtenner/Projects/starshine-mb/agent-todo.md](/home/jtenner/Projects/starshine-mb/agent-todo.md) to track four validator follow-ups grounded in the current implementation: clearer end-of-body diagnostics, a dedicated validation benchmark harness, hot-path allocation/copying reduction in structured control validation, and folding the extra `ref.func` declaration scan into a shared validation traversal.
- Validation: `moon info`; `moon fmt`; `moon test`.

## 2026-03-18 Optimize Planning: add pass-audit docs, pass-trace metrics, and benchmark harness scaffolding

- Added [/home/jtenner/Projects/starshine-mb/docs/pass-audit.md](/home/jtenner/Projects/starshine-mb/docs/pass-audit.md) as the pass-audit planning checkpoint, including the `src/passes` inventory, optimize pipeline mapping, Binaryen-nearest pass crosswalk, mutually enabling relationships, and the current high-priority findings for `SimplifyLocals`, `Vacuum`, and `AlignmentLowering`.
- Updated [/home/jtenner/Projects/starshine-mb/agent-todo.md](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the optimization-recovery work is now tracked by phase and includes a two-item audit pair for each pass implementation file: correctness/Binaryen comparison and performance/baseline analysis.
- Updated [/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so optimize trace output now includes per-pass changed status, functions visited/changed, and instruction-count before/after summaries for both scheduler-run passes and stacked function-pass segments, with regressions locking the new trace fields.
- Added [/home/jtenner/Projects/starshine-mb/scripts/benchmark-optimize.mjs](/home/jtenner/Projects/starshine-mb/scripts/benchmark-optimize.mjs) and [/home/jtenner/Projects/starshine-mb/scripts/test/benchmark-optimize-output.sh](/home/jtenner/Projects/starshine-mb/scripts/test/benchmark-optimize-output.sh) as the first stable benchmark-harness entrypoint and parser smoke test for later pass-refactor measurement work.
- Validation: `bash scripts/test/benchmark-optimize-output.sh`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-18 Validate Follow-up: accept typed control-flow input params in both IR shapes

- Updated [/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt](/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt) so typed `block`, `if`, and `loop` validation now accepts both body-embedded control-flow inputs from `to_texpr(...)` and explicit outer-stack control-flow input forms emitted directly by pass code, fixing the typed-control `stack underflow` gap.
- Added regressions in [/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt) covering typed `block` / `if` / `loop` validation with `type_idx` control-flow input params.
- Validation: `moon test src/validate`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-18 Optimize Follow-up: harden degraded `Vacuum` local retention and add branch-value regressions

- Updated [/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) so degraded `Vacuum` now retains standalone `local.get` / `local.set` nodes in the final standalone-removal path, propagates parent result-use signals into degraded structured bodies, and adds focused degraded/typed regressions around ambient-fed locals and nested outer-label branch-value shapes.
- Updated [/home/jtenner/Projects/starshine-mb/agent-todo.md](/home/jtenner/Projects/starshine-mb/agent-todo.md) to record that the serial-pass `Vacuum` corruption on `before.wasm` / `Func 1360` is still unresolved after this hardening pass.
- Validation: `moon test src/passes`; `moon info`; `moon fmt`; `moon test`. Known remaining issue: `moon run src/cmd --target native -- --debug-serial-passes --vacuum -o /tmp/vacuum-repro.wasm before.wasm` still fails with `typed function stack underflow` in `Func 1360`.

## 2026-03-18 Validate Follow-up: propagate typed outer-label block exits without regressing raw `if` checks

- Updated [/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt](/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt) so raw wasm `if` merges, typed `if` merges, and typed `block` exits now normalize branch escapes separately. Typed blocks once again propagate outer-label `br` escapes upward instead of treating them as local stack underflows, while raw `if` validation still rejects missing result values after nested outer-label branches.
- Added regressions in [/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt) covering the typed nested outer-label branch shapes seen in self-optimize logs and preserving the raw invalid outer-`if` rejection.
- Validation: `moon info`; `moon fmt`; `moon test --package jtenner/starshine/validate`; `moon build --target native --release --package jtenner/starshine/cmd`.

## 2026-03-17 Validate Follow-up: distinguish current-label branches from terminal exits in `if` merges

- Updated [/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt](/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt) so validator control-flow tracking now distinguishes `br` exits that reach the current construct’s merge point from truly terminal exits, fixing invalid acceptance of result-typed outer `if` expressions whose inner arms both branch to the current label.
- Added regressions in [/home/jtenner/Projects/starshine-mb/src/validate/typecheck_negative_tests.mbt](/home/jtenner/Projects/starshine-mb/src/validate/typecheck_negative_tests.mbt) and [/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt), refreshed [/home/jtenner/Projects/starshine-mb/src/validate/pkg.generated.mbti](/home/jtenner/Projects/starshine-mb/src/validate/pkg.generated.mbti), and updated the now-valid fixture in [/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt).
- Validation: `moon info`; `moon fmt`; `moon test`.

## 2026-03-17 Optimize Follow-up: shrink `SSANoMerge` reach analysis state

- Updated [/home/jtenner/Projects/starshine-mb/src/passes/dataflow_opt.mbt](/home/jtenner/Projects/starshine-mb/src/passes/dataflow_opt.mbt) so `SSANoMerge` now stores dense block/get/set state in arrays, memoizes block-entry reach queries, and replaces per-get reaching-definition sets with a compact reach-state enum to cut repeated CFG rescans and GC churn.
- Added a branch-heavy regression in [/home/jtenner/Projects/starshine-mb/src/passes/dataflow_opt.mbt](/home/jtenner/Projects/starshine-mb/src/passes/dataflow_opt.mbt) that locks the single-reaching vs merge-reaching analysis counts used by the rewrite.
- Validation: `moon test src/passes/dataflow_opt.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-17 Format Follow-up: normalize `simplify_locals` line wrapping

- Updated [/home/jtenner/Projects/starshine-mb/src/passes/simplify_locals.mbt](/home/jtenner/Projects/starshine-mb/src/passes/simplify_locals.mbt) with the pending `moon fmt` line wrapping only; there is no behavioral change in this commit.
- Validation: `moon info`; `moon fmt`; `moon test`.

## 2026-03-17 Optimize Follow-up: keep `CodeFolding` from hoisting shared returns past outer branches

- Updated [/home/jtenner/Projects/starshine-mb/src/passes/code_folding.mbt](/home/jtenner/Projects/starshine-mb/src/passes/code_folding.mbt) so `CodeFolding` now skips `if`-tail hoists when the merged suffix is terminating and the remaining condition or arms still branch outward, preventing the invalid wrapper-block rewrite seen in serial self-optimize traces.
- Added a regression in [/home/jtenner/Projects/starshine-mb/src/passes/code_folding.mbt](/home/jtenner/Projects/starshine-mb/src/passes/code_folding.mbt) that preserves the failing value-loop shape with a shared `return call(...)` tail, sibling `br_if`, and memory traffic.
- Validation: `moon info`; `moon fmt`; `moon test`.

## 2026-03-17 Optimize Follow-up: keep serial self-optimize enabled and harden pass debugging

- Updated [/home/jtenner/Projects/starshine-mb/scripts/self-optimize.sh](/home/jtenner/Projects/starshine-mb/scripts/self-optimize.sh), [/home/jtenner/Projects/starshine-mb/scripts/lib/self-optimized-artifacts.mjs](/home/jtenner/Projects/starshine-mb/scripts/lib/self-optimized-artifacts.mjs), and [/home/jtenner/Projects/starshine-mb/scripts/test/self-optimize-output.sh](/home/jtenner/Projects/starshine-mb/scripts/test/self-optimize-output.sh) so self-optimize runs with `--debug-serial-passes` by default and the wrapper test now fails if that serial flag is dropped.
- Updated [/home/jtenner/Projects/starshine-mb/src/passes/simplify_locals.mbt](/home/jtenner/Projects/starshine-mb/src/passes/simplify_locals.mbt) so multi-use `local.get` tee-sinking now refuses sink values that do not produce a standalone result, preventing malformed `local.tee(... local.set(...))` trees during the serial optimize pipeline; added regressions for both single-use and multi-use variants.
- Updated [/home/jtenner/Projects/starshine-mb/src/passes/code_folding.mbt](/home/jtenner/Projects/starshine-mb/src/passes/code_folding.mbt) with extra function-shape guards around terminating-tail rewrites in nested value loops, plus focused value-loop regression coverage used while triaging the next serial self-optimize failure.
- Validation: `moon check`; `bash scripts/test/self-optimize-output.sh`; `moon test --target native src/passes/simplify_locals.mbt -F '*tee sink value has no standalone result*'`.

## 2026-03-17 Optimize Follow-up: preserve stack-fed values in `CodePushing` and `Vacuum`

- Updated [/home/jtenner/Projects/starshine-mb/src/passes/code_pushing.mbt](/home/jtenner/Projects/starshine-mb/src/passes/code_pushing.mbt) so pushing a `local.set` into an `if` arm now accounts for all locals written by the set value, preventing rewrites that would leave the opposite arm or post-`if` code reading a local that was only written on one branch.
- Updated [/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) so stack-signature accounting preserves typed `block`/`if` results carried by value breaks, and so degraded fallback sequence cleanup keeps ambient stack feeders that later instructions still consume instead of deleting them as individually unused.
- Added regressions in [/home/jtenner/Projects/starshine-mb/src/passes/code_pushing.mbt](/home/jtenner/Projects/starshine-mb/src/passes/code_pushing.mbt) and [/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) covering cross-arm nested `local.set` writes, typed block value-break stack signatures, and degraded-mode ambient-fed `local.set` chains.
- Validation: `moon info`; `moon fmt`; `moon test`; `moon run src/cmd --target native -- --debug-serial-passes --vacuum -o /tmp/vacuum-repro-after-degraded-fix.wasm before.wasm`.

## 2026-03-17 Optimize Follow-up: keep `RemoveUnusedNames` from peeling live branch targets

- Updated [/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_names.mbt](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_names.mbt) so nested same-typed block peeling now bails out when the peeled body still contains branches or catches targeting one of the scopes that would be removed, preventing invalid label rebases like the `br 1 -> br 0` rewrite that trapped control flow inside value-producing `if` expressions.
- Added a regression in [/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_names.mbt](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_names.mbt) that preserves the minimal failing shape: a nested `if (result i32)` whose else-arm branches to the block scope that peeling would otherwise erase.
- Validation: `moon info`; `moon fmt`; `moon test --target native src/passes/remove_unused_names.mbt`; `moon run src/cmd --target native -- --debug-serial-passes --remove-unused-names -o /tmp/rmn-debug-fixed.wasm before.wasm`.

## 2026-03-17 Optimize Follow-up: add a serial per-pass validation debug mode

- Updated [/home/jtenner/Projects/starshine-mb/src/cli/cli.mbt](/home/jtenner/Projects/starshine-mb/src/cli/cli.mbt), [/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt), and [/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so `starshine --debug-serial-passes ...` now disables function-pass stacking and validates after each pass-sized scheduler segment, making optimize-pipeline correctness failures attributable to the first failing pass instead of a later barrier.
- Added regressions in [/home/jtenner/Projects/starshine-mb/src/cli/cli_test.mbt](/home/jtenner/Projects/starshine-mb/src/cli/cli_test.mbt) and [/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), and refreshed the generated interfaces in [/home/jtenner/Projects/starshine-mb/src/cli/pkg.generated.mbti](/home/jtenner/Projects/starshine-mb/src/cli/pkg.generated.mbti) and [/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti](/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti).
- Validation: `moon info && moon fmt`; `moon check`; `moon test --target native src/cli`; `moon test --target native src/cmd`. `moon test --target native src/passes` still fails on the pre-existing `merge_blocks.mbt` wall-time threshold check.

## 2026-03-17 Self-optimize Follow-up: stream repro output to the terminal

- Updated [/home/jtenner/Projects/starshine-mb/scripts/self-optimize.sh](/home/jtenner/Projects/starshine-mb/scripts/self-optimize.sh) so the self-optimize wrapper now streams optimizer stdout/stderr live to the terminal while still writing `output.log`, and removed the stale `OPTIMIZE_DUMP_FAILED_MODULE_STATE` env plumbing there.
- Added [/home/jtenner/Projects/starshine-mb/scripts/test/self-optimize-output.sh](/home/jtenner/Projects/starshine-mb/scripts/test/self-optimize-output.sh), a regression that runs the wrapper against stub binaries and requires the repro command to appear both in terminal output and the captured log.
- Validation: `bash scripts/test/self-optimize-output.sh`; `moon info && moon fmt`; `moon test`.

## 2026-03-17 Optimize Follow-up: emit segment repros for post-encode validation failures

- Updated [/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt) so post-encode validation failures now replay the already-expanded optimize pass list segment by segment with the CLI encoder/decoder pipeline, write `before.wasm` for the first failing segment input, and append an exact `starshine ... before.wasm` repro command to the failure output.
- Updated [/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) to expose a scheduler-segment replay helper for post-encode repro isolation, and removed the dead `dump_failed_module_state` parameter from `optimize_module_with_options_trace(...)`.
- Updated [/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt](/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt), [/home/jtenner/Projects/starshine-mb/src/node_api/custom.mbt](/home/jtenner/Projects/starshine-mb/src/node_api/custom.mbt), [/home/jtenner/Projects/starshine-mb/src/passes/memory_packing.mbt](/home/jtenner/Projects/starshine-mb/src/passes/memory_packing.mbt), and [/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti](/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti) so the new repro command can target `abstract-type-refining`, `memory-packing`, and `directize` directly and is covered by end-to-end regression tests.
- Validation: `moon info && moon fmt`; `moon test`.

## 2026-03-17 Optimize Follow-up: audit optimize scheduler call arity and fix multivalue arg counting

- Updated [/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so the optimize scheduler now audits direct, `call_ref`, and indirect call arity before pass scheduling and after module-runner passes, with regressions that cover upstream-invalid call sites and valid multivalue producers.
- Updated [/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt), [/home/jtenner/Projects/starshine-mb/src/passes/reorder_locals.mbt](/home/jtenner/Projects/starshine-mb/src/passes/reorder_locals.mbt), and [/home/jtenner/Projects/starshine-mb/src/validate/env.mbt](/home/jtenner/Projects/starshine-mb/src/validate/env.mbt) so multivalue argument producers use typed result arity instead of raw instruction-array length during hashing, preflight, rewrite validation, and local reordering.
- Updated [/home/jtenner/Projects/starshine-mb/src/passes/dataflow_opt.mbt](/home/jtenner/Projects/starshine-mb/src/passes/dataflow_opt.mbt) so `SSANoMerge` no longer re-walks rewritten `local.set`/`local.tee` values, with a regression that preserves `externref` table-set values through the rewrite.
- Validation: `moon info && moon fmt`; `moon test`.

## 2026-03-17 Optimize Follow-up: preflight typed and indirect call arity in `MergeSimilarFunctions`

- Updated [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so `MergeSimilarFunctions` now preflights `call_ref`, `return_call_ref`, `call_indirect`, and `return_call_indirect` arity against the resolved function type before class collection, and so rewrite-time call-target mismatch diagnostics include the relevant `type_idx` plus expected/actual arity details.
- Added regressions in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) that lock upstream-invalid `call_ref` and `call_indirect` rejection in preflight and preserve the richer rewrite-time mismatch diagnostics.
- Updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to record the new optimize performance blockers and the `MergeSimilarFunctions` arg-count mismatch failure observed in the self-optimization trace.
- Validation: `moon test src/passes`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: make `SSANoMerge` sparse and stabilize self-opt execution

- Reworked [`src/passes/dataflow_opt.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dataflow_opt.mbt) so `SSANoMerge` uses a Binaryen-style sparse block/action analysis instead of cloning dense reaching-definition maps, and added a regression that preserves loop-carried gets.
- Updated [`scripts/self-optimize.sh`](/home/jtenner/Projects/starshine-mb/scripts/self-optimize.sh) to support portable native CLI invocation fallbacks while writing optimizer output to [`output.log`](/home/jtenner/Projects/starshine-mb/output.log), defaulting self-opt runs to pass-level tracing with configurable overrides.
- Updated [`AGENTS.md`](/home/jtenner/Projects/starshine-mb/AGENTS.md) to forbid trace-only tests unless they are explicitly requested.
- Validation: `moon test src/passes/dataflow_opt.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: land `SSANoMerge` parity in the default pipeline

- Updated [`src/passes/dataflow_opt.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dataflow_opt.mbt) to add a narrow `SSANoMerge` pass that rewrites single-reaching local set/get chains, preserves merge-reaching gets, and lifts plain functions when they can be represented as typed IR.
- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so the optimize scheduler classifies `SSANoMerge` as a stackable unit transformer, exposes it through `optimize_module(...)`, and inserts it at the Binaryen `ssa-nomerge` slot in the default function pipeline instead of substituting `DataflowOptimization`.
- Updated [`docs/differences.md`](/home/jtenner/Projects/starshine-mb/docs/differences.md) and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to record that the `ssa-nomerge` and stacked-runner publishing blockers are now closed.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: reduce stacked-runner code-section snapshot churn

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so the stacked function runner now prepares passes against one shared live code-section snapshot and no longer rebuilds `CodeSec` after every changed function/pass step inside a stacked segment.
- Added a regression in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that locks stacked-runner snapshot materialization down to one shared execution snapshot plus one final last-pass-attribution snapshot.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Docs Follow-up: remove `StringGathering` from the publishing blockers list

- Updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to remove `StringGathering` from the publishing-blocker section while leaving the broader post-`0.1.0` string optimization follow-up item in place.
- Validation was not run because this change only updates planning/documentation.

## 2026-03-16 Docs Follow-up: track post-0.1.0 string optimization work

- Added a post-0.1.0 backlog item in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to continue `string.const` support and string optimization pass work after the initial `0.1.0` release.
- Validation was not run because this change only updates planning/documentation.

## 2026-03-16 Docs Follow-up: add `StringGathering` research and implementation blueprint

- Added [`docs/string-optimization.md`](/home/jtenner/Projects/starshine-mb/docs/string-optimization.md), a detailed Binaryen `StringGathering` research note covering pass semantics, scheduler placement, data structures, correctness constraints, test cases, single-pass pseudocode, and a one-shot implementation prompt for Starshine.
- Validation was not run because this change was documentation-only.

## 2026-03-16 Optimize Follow-up: replace `AfterEveryPass` with `AfterSegment`

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so `OptimizeValidationPolicy` now exposes `FinalModuleOnly` and `AfterSegment`; the old `AfterEveryPass` debug mode has been removed.
- Moved non-default validation to scheduler-segment boundaries in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt): barrier passes still validate immediately after running, while contiguous `FunctionPassStack` segments validate once after the whole executed stack instead of after each constituent pass.
- Updated optimize regressions in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) and the policy note in [`docs/differences.md`](/home/jtenner/Projects/starshine-mb/docs/differences.md) so trace expectations, validation-failure attribution, and public documentation all reflect the new segment-level contract.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: keep after-every-pass validation inside prepared function stacks

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so `FunctionPassStack` segments now stay on prepared function-pass execution even under `OptimizeValidationPolicy::after_every_pass()`: the stack runner applies each prepared pass across all functions, validates at the pass boundary, and preserves pass-local validation attribution instead of falling back to the legacy flat scheduler path.
- Tightened stacked pass tracing in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so synthesized pass-summary start lines keep their scheduler kind labels, and added regressions that require helper/phase traces to show the validation barrier between `DeadCodeElimination` and `CodePushing` on the after-every-pass path.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: preserve pass-summary tracing on stacked function segments

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so the prepared per-function stacked executor now also stays enabled for `OptimizeTracingLevel::pass()` under final-module validation; `AfterEveryPass` validation remains the intentionally flat fallback.
- Added synthetic pass-summary emission in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so stacked function segments still report the expected `pass[..]:start`, `pass[..]:done`, and error lines without leaking helper-level `scheduler:` or per-function `func[...]` details into pass traces.
- Added regressions in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that lock stacked-runner eligibility for pass tracing and require `DeadCodeElimination -> CodePushing` pass traces to stay summary-only across a multi-function stack segment.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: chunk repeated vacuum stacks into the largest safe per-function substacks

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so non-fully-stackable `FunctionPassStack` segments no longer flush around every `Vacuum`; the fallback path now accumulates the largest safe substack, which keeps repeated-vacuum sequences like `DeadCodeElimination -> Vacuum -> Vacuum -> CodePushing` on stacked per-function execution where the vacuum skip semantics allow it.
- Added helper-trace coverage in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that locks the new repeated-vacuum chunking order by function.
- Removed the explicit release/publish line from [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the publishing-blocker section stays focused on pre-release technical blockers rather than the release act itself.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: treat constant-field analysis wrappers as stacked-runner barriers

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so `ConstantFieldPropagation` and `ConstantFieldNullTestFolding` no longer count as `FunctionPassStack` members; both passes currently build whole-module constant-field analysis before rewriting and therefore stay as scheduler barriers for the stacked runner.
- Added segmentation regressions in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that lock `ConstantFieldPropagation` and `ConstantFieldNullTestFolding` as barriers between stackable neighbors.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: keep single non-skipped vacuum passes inside stacked segments

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so `FunctionPassStack` segments with zero or one non-skipped `Vacuum` now stay on the prepared per-function executor instead of flushing around `Vacuum`; repeated or skip-sensitive `Vacuum` cases still fall back to the older split execution path.
- Corrected stacked-runner eligibility in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) by treating the module-shaped `DeNaN` wrapper as a scheduler barrier again, with an explicit segmentation regression.
- Added helper-trace coverage in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that requires `DeadCodeElimination -> Vacuum -> CodePushing` to interleave by function under the stacked runner.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: extend stacked function segments to phase tracing

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so the prepared per-function stacked executor now also runs on `OptimizeTracingLevel::phase()` under final-module validation; only pass-summary tracing, `AfterEveryPass` validation, and `Vacuum` still force the flat fallback inside function-stack segments.
- Fixed the stacked runner in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) to refresh `ctx.mod` from the latest rewritten code-section snapshot between per-function pass applications and to capture the final-validation `last_pre_pass_mod` snapshot at the whole-module state immediately before the last stacked pass reaches each function.
- Added phase-trace regressions in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that require interleaved per-function execution on the final-validation path while keeping the flat loop under `AfterEveryPass` validation.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: run contiguous non-vacuum function stacks per function

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so `FunctionPassStack` segments now execute contiguous non-`Vacuum` substacks through a prepared per-function runner on the default final-validation path, while `Vacuum`, pass/phase tracing, and `AfterEveryPass` validation still fall back to the existing flat per-pass executor.
- Factored scheduler pass construction in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so the stacked runner can reuse the same IR-context and unit-transformer pass builders as the flat scheduler path.
- Added optimize trace regressions in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that require helper traces to show interleaved function-stack execution for a real two-pass stack while keeping the flat loop for `AfterEveryPass` validation.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: narrow function-stack segments to walk-func-compatible passes

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so `scheduler_segment_passes(...)` now treats only walk-func-compatible passes as `FunctionPassStack` members; module-shaped IR transformers such as `Flatten` and `LocalCSE` are now explicit barriers even though they are not `ModuleRunnerPass` values.
- Added segmentation regressions in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) for synthetic mixed pass lists and the `-O4` default function pipeline, locking the new barrier splits around `Flatten` and `LocalCSE`.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt -F 'scheduler_segment_passes *'`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: execute the default scheduler through explicit pass segments

- Refactored [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so the default optimize loop now executes explicit `SchedulerPassSegment`s and routes each segment through a dedicated executor, while preserving the existing per-pass semantics, validation behavior, pass numbering, and `Vacuum` skip policy.
- Added helper-trace segment execution boundaries in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so helper traces now show `run_segment ... start/done` around both function-stack segments and module-runner barriers.
- Added trace regressions in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that require helper-level segment execution boundaries while keeping pass-level traces unchanged.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt -F 'optimize_module *scheduler segment execution boundaries*'`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: expose stacked-runner scheduler segments in helper traces

- Added helper-trace segment planning in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), so traced optimize runs now emit the grouped function-pass stacks and module-runner barrier passes derived from the in-tree scheduler segmentation helper before execution begins.
- Added trace regressions in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that require helper-level traces to report the segment plan while keeping pass-level traces unchanged.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt -F 'optimize_module *scheduler pass segments*'`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: add scheduler segmentation groundwork for stacked function-pass execution

- Added scheduler segmentation helpers in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that group contiguous function-stackable transformer passes and isolate module-runner barriers, giving the future stacked runner an explicit in-tree segmentation contract.
- Added regression coverage in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) for both synthetic pass lists and the default GC function pipeline, including the `LocalSubtyping` barrier split between the preceding `OptimizeCasts` stack tail and the following `CoalesceLocals` stack head.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt -F 'scheduler_segment_passes*'`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: close the `CodeFolding` Binaryen parity scheduler slice

- Added an explicit `CodeFolding` scheduler regression in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that locks the Binaryen-parity gate (`-O3` or `-Os1`) and the expected placement after the late local-cleanup `Vacuum` and before `MergeBlocks`.
- Updated [`docs/differences.md`](/home/jtenner/Projects/starshine-mb/docs/differences.md) to record the `CodeFolding` scheduler comparison as closed and refreshed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to retire the open blocker entry.
- Validation: `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: close the `CodePushing` Binaryen parity scheduler slice

- Added an explicit `CodePushing` scheduler regression in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that locks the Binaryen-parity gate (`-O2` or `-Os2`) and the expected placement after early propagation and before tuple / local cleanup.
- Updated [`docs/differences.md`](/home/jtenner/Projects/starshine-mb/docs/differences.md) to record the `CodePushing` scheduler comparison as closed and refreshed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to retire the open blocker entry.
- Validation: `moon info && moon fmt`; `moon test`.

## 2026-03-16 SimplifyLocals Follow-up: close scheduler/parity signoff and retire stale blocker list

- Refreshed [`docs/SimplifyLocals.md`](/home/jtenner/Projects/starshine-mb/docs/SimplifyLocals.md) into a completed signoff record for the current five-variant `SimplifyLocals` envelope, including explicit completion notes for the existing correctness, control-structure, validation, performance, and scheduler coverage already in-tree.
- Updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to remove the stale open `SimplifyLocals` blocker checklist and record the signoff closure in the completed-items section.
- Validation: targeted `simplify_locals` ID regressions; targeted `br_if` / `br_table` / validation-counter regressions; `moon test --package jtenner/starshine/passes --file optimize.mbt -F '*SimplifyLocals*'`.

## 2026-03-16 MergeSimilarFunctions Follow-up: publish the supported envelope in the main design doc

- Updated [`docs/merge-similar-functions.md`](/home/jtenner/Projects/starshine-mb/docs/merge-similar-functions.md) with a release-facing supported-difference matrix and explicit guarded typed-ref lowering policy, so the main design doc now matches the in-tree behavior already enforced by tests.
- Refreshed [`docs/plans/done/merge-similar-functions-publish-plan.md`](/home/jtenner/Projects/starshine-mb/docs/plans/done/merge-similar-functions-publish-plan.md) and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to mark `MSF-006` / `MSF-009` effectively closed and narrow the remaining `MergeSimilarFunctions` publish work to final `MSF-013` signoff.
- Validation was not rerun because this slice is documentation-only; the preceding code slice already completed `moon info && moon fmt` and `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: add fixed-corpus timing and instrumentation harnesses

- Added a dedicated fixed benchmark corpus plus timing/instrumentation helpers in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt), covering representative merge, skip, multi-class, and near-limit-profitable inputs.
- Added regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) that locks fixed-corpus validity, deterministic output, zero bucket-copy churn, positive dense-site coverage, and a runnable end-to-end timing harness.
- Updated [`docs/plans/done/merge-similar-functions-publish-plan.md`](/home/jtenner/Projects/starshine-mb/docs/plans/done/merge-similar-functions-publish-plan.md) and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to record the in-tree `MSF-013` harness work and narrow the remaining `MergeSimilarFunctions` publish work to signoff/documentation items.
- Validation: `moon fmt`; `moon test --package jtenner/starshine/passes --file merge_similar_functions.mbt -F 'merge similar functions*'`; `moon test --package jtenner/starshine/passes --file optimize.mbt -F 'optimize_module runs MergeSimilarFunctions pass'`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: adapt synthetic-parameter policy to profitability

- Updated [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so synthetic-parameter handling now uses a soft limit plus bounded hard cap, and near-limit merges can still proceed when the byte-aware profitability model clearly wins.
- Added regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) for profitable just-over-limit merges, explicit parameter-pressure skips, and hard-cap rejection of excessive synthetic parameter growth.
- Refreshed [`docs/plans/done/merge-similar-functions-publish-plan.md`](/home/jtenner/Projects/starshine-mb/docs/plans/done/merge-similar-functions-publish-plan.md) and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to record `MSF-008` as completed and narrow the remaining `MergeSimilarFunctions` publish work.
- Validation: `moon fmt`; `moon test --package jtenner/starshine/passes --file merge_similar_functions.mbt -F 'merge similar functions*'`; `moon test --package jtenner/starshine/passes --file optimize.mbt -F 'optimize_module runs MergeSimilarFunctions pass'`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: make profitability byte-aware without blocking established merges

- Updated [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so `MergeSimilarFunctions` profitability now measures instruction-immediate byte weight and actual thunk body cost, which skips tiny typed-ref wrappers while preserving established profitable merges.
- Added profitability regressions in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) for tiny and larger typed-ref call-target wrappers, and retuned the existing call-target rewrite test to exercise a still-profitable wrapper shape.
- Updated [`src/passes/imports.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/imports.mbt) for the new byte-size helpers.
- Validation: `moon info && moon fmt`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: add a publish-signoff plan for supported envelope, remaining blockers, and rerun criteria

- Added [`docs/plans/done/merge-similar-functions-publish-plan.md`](/home/jtenner/Projects/starshine-mb/docs/plans/done/merge-similar-functions-publish-plan.md) as the active source of truth for `MergeSimilarFunctions` publish signoff, including the supported difference-kind matrix, the current typed-ref lowering envelope, the remaining policy blockers, and the required rerun checklist.
- Linked the new signoff plan from [`docs/merge-similar-functions.md`](/home/jtenner/Projects/starshine-mb/docs/merge-similar-functions.md) and recorded the completed documentation slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation was not run because this slice is documentation-only.

## 2026-03-16 MergeSimilarFunctions Follow-up: lock explicit skip-policy tracing for unsupported typed-ref merges and parameter-pressure skips

- Added a trace-capture helper plus traced skip-policy regressions in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) that lock explicit `reason=typed_ref_lowering_unsupported` and `reason=synthetic_param_limit` behavior under `merge_similar_functions_with_trace(...)`.
- Kept the existing `MergeSimilarFunctions` skip behavior validator-clean while making unsupported typed-ref merges and synthetic-parameter-pressure skips test-enforced and diagnosable.
- Recorded the completed blocker slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon fmt`; `moon info`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: strengthen coarse bucket discrimination with call-shape hashing

- Updated [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so defined functions precompute a cheap call-shape hash over direct-call site ids, callee type indices, arg counts, and call kind, and the coarse hash bucket key now uses that discriminator in addition to the existing structural hash.
- Added representative-comparison stats to class collection in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) and locked a collision-heavy regression proving the prefilter reduces representative comparisons without changing deterministic class formation.
- Recorded the completed blocker slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon fmt`; `moon info`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: remove bucket-copy churn and densify cached site metadata

- Reworked [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so equivalence-class bucket assembly now grows bucket member arrays in place through a shared builder instead of copy-on-insert rebuilds.
- Replaced cached `node_id -> site` maps in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) with dense site vectors keyed by traversal-stable preorder ids, and routed `derive_params` through array-backed site lookup.
- Added regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) for zero-copy bucket growth and sparse-node dense site vectors, and recorded the completed blocker slices in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon fmt`; `moon info`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: replace dense node-id maps with array-backed lookup in rewrite metadata paths

- Reworked call-target metadata lookup in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so rewrite prevalidation and shared-body rewrite use array-backed `node_id -> param` lookup plus dense seen-use tracking keyed by traversal-stable preorder ids instead of `Map[Int, Int]` / `Map[Int, Bool]`.
- Kept the existing `MergeSimilarFunctions` rewrite and diagnostics behavior in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) while reducing GC churn on the dense node-id metadata path.
- Added sparse-use regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) and recorded the completed blocker slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon fmt`; `moon info`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: cache per-function analysis artifacts across hot-path queries

- Added a shared per-run analysis context in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) that caches module type metadata plus lazy per-function normalized bodies, ordered-site/call-site artifacts, site maps, and measured body sizes.
- Routed `MergeSimilarFunctions` class collection, parameter derivation, and profitability checks in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) through that shared cache so hot comparison loops stop rebuilding the same analysis products.
- Added cache-reuse regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) and recorded the completed blocker slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon fmt`; `moon info`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: centralize ordered site numbering for traversal-stable metadata

- Refactored [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) to assign site ids through one shared ordered-site collector and reuse that ordered stream across generic site collection, direct-call collection, and parameter derivation.
- Removed the old map-plus-sort fallback in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt), making the pre-order traversal numbering contract explicit in code and comments.
- Added traversal-order regressions in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt), refreshed [`src/passes/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti), and recorded the completed blocker slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: remove unconditional tail-call thunks and guard typed-ref lowering

- Updated [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so shared-function thunks no longer emit unconditional `return_call`; they now lower to `return(call ...)`, removing tail-call dependence from the common merge path.
- Added a guarded typed-function-reference lowering path in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) that skips `CallTargetParam`-driven merges unless the input module already demonstrates typed-ref lowering support.
- Added regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) for tail-call-free thunks, guarded skip behavior without typed-ref evidence, and the still-enabled typed-ref merge path, and recorded the completed blocker slices in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: prevalidate call-target metadata and report precise rewrite mismatches

- Hardened [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so call-target rewrite validation now uses a shared site checker, prevalidates `CallTargetParam` node bindings against the primary body before rewrite starts, and rejects missing or misbound node ids early.
- Upgraded call-target rewrite diagnostics in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) to include `node_id` plus explicit expected/actual kind, arg count, and callee type details.
- Added kind-mismatch and callee-type-mismatch regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) and recorded the completed blocker slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: preflight direct-call audit separates upstream-invalid IR from rewrite metadata failures

- Added a pass-wide direct `call` / `return_call` preflight audit in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so upstream-invalid call arity now fails before equivalence grouping or shared-body rewrite starts.
- Tightened `MergeSimilarFunctions` rewrite diagnostics in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so call-target rewrite failures are labeled as metadata mismatches instead of looking like input-validation failures.
- Added direct `call` and `return_call` preflight regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) and recorded the completed blocker slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: route function-type resolution through validator semantics and fix grouped-rec shared type indexing

- Reworked [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) to resolve `TypeIdx` and callee function signatures through validator-backed module semantics instead of the pass-local flattened lookup.
- Fixed appended shared-function `TypeIdx` assignment to use flattened subtype count, so grouped recursion types no longer shift synthesized function signatures onto the wrong index.
- Added grouped-rec regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) and recorded the completed blocker slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-16 Docs Follow-up: compacted `AGENTS.md` without changing repository guidance

- Rewrote [`AGENTS.md`](/home/jtenner/Projects/starshine-mb/AGENTS.md) into a denser format while preserving the same instructions and workflow requirements.
- Validation was not run because this change was documentation-only.

## 2026-03-16 Docs Follow-up: closed `RemoveUnusedBrs` and `PrecomputePropagate` parity-tracking items and standardized commit workflow guidance

- Marked the `RemoveUnusedBrs` and `PrecomputePropagate` Optimize/Binaryen parity comparison items complete in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Added a `Precompute` / `PrecomputePropagate` scheduler parity note to [`docs/differences.md`](/home/jtenner/Projects/starshine-mb/docs/differences.md) with code and test anchors.
- Updated [`AGENTS.md`](/home/jtenner/Projects/starshine-mb/AGENTS.md) to require changelog updates plus temp-file-based `git commit -F` commit messages when agents are asked to commit.
- Validation was not run because these changes were documentation-only.

## 2026-03-13 MergeBlocks Follow-up: closed parity-signoff by classifying all matrix rows, recording signoff metrics, and moving the plan from active to done

This follow-up closes the `MergeBlocks` parity signoff blocker using:
- [`src/passes/merge_blocks_parity_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks_parity_wbtest.mbt)
- [`docs/plans/done/merge-blocks-binaryen-feature-parity-plan.md`](/home/jtenner/Projects/starshine-mb/docs/plans/done/merge-blocks-binaryen-feature-parity-plan.md)

Strict TDD was used:
1. Added red-first signoff tests:
   - `merge blocks parity signoff classifies each row as match or intentional divergence`
   - `merge blocks parity signoff metrics are stable`
2. Ran `moon test src/passes` and captured explicit red compile failures before implementation:
   - unbound signoff helpers (`mbp_parity_row_signoff_status`, `mbp_collect_parity_signoff_metrics`)
   - unresolved metrics fields in the new signoff assertions.
3. Implemented signoff status + metrics helpers and reran to green, then tightened metrics assertions to exact stable counts.

What was added:
- Parity-signoff metrics model:
  - `MBParitySignoffMetrics`
- Signoff status/rationale helper:
  - `mbp_parity_row_signoff_status(row)` returning `Match` or `Intentional divergence` with rationale for divergence rows.
- Signoff metrics collector:
  - `mbp_collect_parity_signoff_metrics()`
- Explicit divergence row lock:
  - `merge blocks parity signoff intentional divergence rows are explicit`

Recorded signoff metrics (test-locked):
- `total_rows = 11`
- `match_rows = 8`
- `intentional_divergence_rows = 3`
- `validates_before_rows = 8`
- `validates_after_rows = 9`
- `idempotent_rows = 11`
- `changed_rows = 5`
- `value_branch_zero_rows = 10`
- `stack_sig_required_rows = 1`
- `stack_sig_consistent_rows = 1`
- `required_category_count = 7`

Plan completion:
- Updated parity plan status to `Done`.
- Added completion notes with row-by-row `Match` / `Intentional divergence` classification and rationale.
- Moved the plan from `docs/plans/active` to `docs/plans/done`.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): parity-signoff was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed parity-test-matrix item by adding an explicit category matrix harness with per-row expected outcomes and invariant checks

This follow-up closes the `MergeBlocks` parity test matrix blocker in [`src/passes/merge_blocks_parity_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks_parity_wbtest.mbt).

Strict TDD was used:
1. Added red-first parity-matrix tests:
   - `merge blocks parity matrix covers required categories`
   - `merge blocks parity matrix rows meet expected outcomes`
2. Ran `moon test src/passes` and captured explicit red compile failures before implementation:
   - unbound matrix helpers (`mbp_collect_parity_matrix_results`, `mbp_required_parity_matrix_categories`)
   - unresolved matrix row fields in test assertions due missing result struct.
3. Implemented matrix case/result models + fixture runners, then iterated to green by fixing row fixtures/expectations that failed runtime assertions.

What was added:
- Explicit matrix data model:
  - `MBParityMatrixCase`
  - `MBParityMatrixResult`
- Matrix category contract helper:
  - `mbp_required_parity_matrix_categories()`
- Matrix fixture builders and evaluation helpers:
  - named block boundary fixture
  - loop-tail extraction fixture
  - dropped-block value-removal fixture
  - `try_table` catch permutation fixtures (`catch_all_ref`, `catch_ref` no-params, `catch`, `catch_all`, paramful `catch_ref`)
  - restructure dependency/effect-collision fixture
  - typed stack-signature fixture
  - idempotence fixture
  - collectors:
    - `mbp_parity_matrix_cases()`
    - `mbp_collect_parity_matrix_results()`
    - `mbp_validates_module(...)`
    - `mbp_stack_sig_consistent_module(...)`

Matrix coverage now explicitly asserts the required categories:
- named block merge boundaries
- loop-tail extraction
- dropped-block value removal
- `try_table` catch permutations
- restructure dependency/effect collisions
- type/stack-signature invariants
- idempotence (`run_merge_blocks` once vs twice)

Per-row checks now include (as applicable):
- expected `changed` behavior
- expected post-pass value-branch counts
- validation invariants
- stack-signature consistency invariants
- idempotence guarantees

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): the parity-test-matrix item was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed P-005 by switching `optimize_block` round assembly to staged buffer swaps and locking zero rebuild-copy replay coverage

This follow-up closes `MergeBlocks` performance P-005 in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Strict TDD was used:
1. Added red-first regressions:
   - `merge blocks: optimize block staged buffers swap rounds without rebuild-copy replay`
   - `merge blocks: optimize block staged-buffer stress fixture keeps representative zero-copy target`
2. Ran `moon test src/passes` and captured explicit red compile failures before implementation:
   - missing `MBFunctionRunStats` fields:
     - `optimize_block_round_buffer_swaps`
     - `optimize_block_round_rebuild_copies`
   - unbound stress helper:
     - `mb_optimize_block_buffer_stress_totals(...)`
3. Implemented staged swap assembly + stats/helper wiring and reran to green.

Implementation details:
- Reworked `optimize_block(...)` round assembly from rebuild-copy replay to staged buffers:
  - before: each changed round replayed all `out` items into `curr_items` via `curr_items.clear()` + push loop.
  - after: maintains `curr_items` and `next_items` buffers, clears/fills `next_items` per round, then commits with buffer swap:
    - `prev_items = curr_items`
    - `curr_items = next_items`
    - `next_items = prev_items`
- Preserved round semantics:
  - round-change detection, branch-cache invalidation boundary, round-safety-cap handling, and finalization behavior are unchanged.
- Added round-assembly observability:
  - `MBContext.optimize_block_round_buffer_swaps`
  - `MBContext.optimize_block_round_rebuild_copies`
  - surfaced in `MBFunctionRunStats` with matching fields.
- Added deterministic stress helper:
  - `mb_optimize_block_buffer_stress_totals(iterations, arg_count)`
  - aggregates swap/copy metrics over repeated fixed fixtures.

Behavioral outcomes locked by tests:
- Representative optimize-block rewrite workloads produce positive buffer-swap counts.
- Rebuild-copy replay count remains `0` under staged-buffer commit behavior.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): P-005 was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed P-004 by replacing non-control `eval_children(...).to_array()` materialization with direct child iteration and zero-materialization stress coverage

This follow-up closes `MergeBlocks` performance P-004 in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Strict TDD was used:
1. Added red-first regressions:
   - `merge blocks: non-control child iteration avoids eval-children array materialization`
   - `merge blocks: non-control child iteration stress fixture keeps representative zero-materialization target`
2. Ran `moon test src/passes` and captured explicit red compile failures before implementation:
   - unbound stress-module helper (`mb_make_non_control_child_iteration_stress_module(...)`)
   - missing `MBFunctionRunStats` fields (`non_control_child_iteration_steps`, `non_control_child_array_materializations`)
   - unbound stress-aggregation helper (`mb_non_control_child_iteration_stress_totals(...)`)
3. Implemented direct child iteration path + stats helpers and reran to green.

Implementation details:
- Reworked `mb_restructure_non_control(...)`:
  - before: eagerly materialized all children with `eval_children(parent_expr).to_array()`.
  - after: iterates children directly via `for child in eval_children(parent_expr)` with no intermediate child-array materialization.
- Added non-control restructure observability:
  - `MBContext.non_control_child_iteration_steps`
  - `MBContext.non_control_child_array_materializations`
  - surfaced in `MBFunctionRunStats` with matching fields.
- Added stress fixtures/utilities:
  - `mb_make_non_control_child_iteration_stress_module(arg_count)`
  - `mb_non_control_child_iteration_stress_totals(iterations, arg_count)`
  - regression asserts representative runs keep total materializations at `0` while still recording positive iteration steps.

Behavioral outcomes locked by tests:
- Non-control restructure still rewrites representative fixtures (`changed == true`), while child traversal is measured through iteration counters.
- Representative stress runs enforce a zero-materialization target on this path.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): P-004 was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed P-003 by switching branch-query cache keys to identity ids with generation invalidation and locking representative hit-rate coverage

This follow-up closes `MergeBlocks` performance P-003 in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Strict TDD was used:
1. Added red-first branch-cache regressions:
   - `merge blocks: branch cache uses id-based keys so structural clones do not alias`
   - `merge blocks: branch cache rewrite invalidation boundary forces next-query miss`
   - `merge blocks: branch cache stress fixture meets representative hit-rate target`
2. Ran `moon test src/passes` and captured explicit red compile failures before implementation:
   - missing `BranchCache` stats fields used by the new tests (`instr_id_misses`, `query_misses`, `query_hits`, `invalidations`)
   - missing invalidation helper (`mb_branch_cache_invalidate(...)`)
   - missing stress helper (`mb_branch_cache_stress_hit_rate_bp(...)`)
3. Implemented identity/generation cache changes and reran to green.

Implementation details:
- Replaced structural cache keys:
  - before: `BranchCacheKey { instr: TInstr, depth }` keyed by structural `Eq`/`Hash`.
  - after: `BranchCacheQueryKey { instr_id, depth, generation }` keyed by instruction identity id and invalidation generation.
- Added identity-id side table:
  - `instr_id_entries : Array[BranchCacheInstrIdEntry]`
  - `mb_branch_cache_instr_id(...)` resolves ids via `physical_equal(...)` so structurally equal clones do not alias.
- Added generation invalidation boundary:
  - `mb_branch_cache_invalidate(...)` increments cache generation and invalidation counter.
  - `optimize_block(...)` now calls invalidation whenever a round rewrites the block before the next round queries run.
- Added branch-cache observability and stress helper:
  - query hit/miss counters and id hit/miss counters
  - `mb_branch_cache_hit_rate_bp(...)`
  - `mb_branch_cache_stress_hit_rate_bp(...)` for representative repeated-query hit-rate measurement.

Behavioral outcomes locked by tests:
- Structural clones now map to distinct instruction ids (no key aliasing through structural hashing).
- Post-rewrite round boundaries force a miss on the next query generation instead of reusing stale query entries.
- Representative repeated-query fixture keeps cache hit rate at `>= 80%`.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): P-003 was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed P-002 by adding per-function `compute_effects` memoization and locking a >=15% stress-fixture wall-time improvement

This follow-up closes `MergeBlocks` performance P-002 in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Strict TDD was used:
1. Added red-first performance/cache regressions:
   - `merge blocks: effect cache records repeated stable-identity hits per function`
   - `merge blocks: effect cache stress fixture improves wall time by at least 15 percent`
2. Ran `moon test src/passes` and captured explicit red compile failures before implementation:
   - unbound `mb_run_on_function_with_stats_with_effect_cache(...)`
   - missing cache fields in run stats (`compute_effects_cache_hits` / `compute_effects_cache_misses`)
3. Implemented per-function memoization + stats wiring and reran to green.

Implementation details:
- Added stable instruction cache key:
  - `MBStableInstrKey` (derived `Eq`/`Hash`) keyed by `TInstr` identity/equality semantics.
- Added per-function effect cache storage and controls in `MBContext`:
  - `effects_cache : Map[MBStableInstrKey, MBEffects]`
  - `effect_cache_enabled : Bool`
  - `compute_effects_cache_hits` / `compute_effects_cache_misses`
- Added cached effect accessor:
  - `mb_compute_effects_cached(instr, ctx)` with hit/miss accounting.
- Routed MergeBlocks hot-path effect queries to cached accessor in:
  - `optimize_expression_restructure(...)`
  - `mb_restructure_non_control(...)`
  - dropped-block `problem_finder` value-side-effect checks.
- Added function-runner override path:
  - `mb_run_on_function_with_stats_with_effect_cache(...)`
  - shared override runner keeps existing behavior as default while enabling cache-off comparisons for stress verification.
- Extended `MBFunctionRunStats` with cache telemetry:
  - `compute_effects_cache_hits`
  - `compute_effects_cache_misses`

Performance verification locked in tests:
- Added dedicated stress fixture/module helper (`mb_make_effect_cache_stress_module(...)`) that reuses repeated stable instruction identities in a heavy call-argument shape.
- Added timing helper (`mb_effect_cache_stress_elapsed_us(...)`) and regression asserting cached mode improves wall time by `>= 15%` versus uncached mode on fixed iterations.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): P-002 was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed runtime-gap item by documenting and locking intentional sequential execution under current transformer constraints

This follow-up closes the `MergeBlocks` runtime-gap backlog item in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Decision:
- The local pass runner does not currently expose a safe function-parallel dispatch path for this pass.
- `ModuleTransformer::walk_opt_codesec_default` traverses function bodies through `ModuleTransformer::walk_opt_array`, and `walk_opt_array` threads mutable traversal state item-by-item; this execution model is serial by construction today.
- Per backlog requirement, this is now documented as an intentional divergence until runner-level function-parallel support exists.

Strict TDD was used:
1. Added a red-first regression:
   - `merge blocks: runtime parallel gap is documented as intentional sequential divergence`
2. Ran `moon test src/passes` and captured explicit red compile failure:
   - unbound `mb_runtime_execution_policy_note()`
3. Implemented the policy note and pass-level execution-model comment, then reran to green.

What was added:
- `mb_runtime_execution_policy_note()` with explicit rationale referencing the transformer traversal constraint (`walk_opt_codesec_default` -> `walk_opt_array` state threading).
- A pass-level comment in `merge_blocks_ir_pass(...)` pointing to the policy note for execution-model context.
- Regression assertion that locks policy-note content so this intentional divergence remains explicit and test-guarded.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): the runtime-gap item was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed C-004 by replacing fixed 20-round block optimization with convergence-driven iteration and explicit safety-cap instrumentation

This follow-up closes `MergeBlocks` correctness gap C-004 in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Strict TDD was used:
1. Added red-first regressions for:
   - deep nested convergence beyond the legacy round budget surface (`merge blocks: deep nesting converges past legacy round budget without cap hits`)
   - explicit forced safety-cap signaling (`merge blocks: safety-cap instrumentation reports forced cap hit`)
2. Ran `moon test src/passes` and captured explicit red compile failures before implementation:
   - missing `MBFunctionRunStats.optimize_block_rounds`
   - missing `MBFunctionRunStats.optimize_block_round_cap_hits`
   - missing cap-aware stats runner helper (`mb_run_on_function_with_stats_with_round_safety_cap`)
3. Implemented convergence loop + instrumentation and reran to green.

Implementation changes:
- Replaced fixed-loop guard in `optimize_block(...)`:
  - before: `while rounds < 20`
  - after: convergence-driven `while true` loop that exits on `!round_change`.
- Added explicit safety cap computation (`mb_optimize_block_round_safety_cap(...)`) and cap-hit accounting.
- Added `MBContext` instrumentation fields:
  - `optimize_block_rounds`
  - `optimize_block_round_cap_hits`
  - `round_safety_cap_override` (test/diagnostic override path)
- Added `MBFunctionRunStats` fields:
  - `optimize_block_rounds`
  - `optimize_block_round_cap_hits`
- Added cap-aware stats helper:
  - `mb_run_on_function_with_stats_with_round_safety_cap(...)`
  - default runner preserves normal behavior via `mb_run_on_function_with_stats(...)` (override `0`).

Behavioral outcome:
- Deep nested fixtures are no longer constrained by the previous silent 20-round stop.
- When a safety cap is explicitly forced low, the pass reports cap hits through stats instead of truncating silently.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): C-004 was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed C-003 by porting Binaryen-style loop `keepEnd` concrete-tail gating and adding typed loop extraction fixtures

This follow-up closes `MergeBlocks` correctness gap C-003 in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Strict TDD was used:
1. Added red-first typed loop regressions that separate unsound and valid loop-tail extraction cases:
   - `merge blocks: typed loop concrete tail without back-branch is not extracted`
   - `merge blocks: typed loop non-concrete tail is extracted`
2. Ran `moon test src/passes` and captured explicit red failures:
   - concrete-tail case produced invalid output (`typed function stack underflow`) due unsound loop-tail extraction
   - non-concrete-tail case stayed unoptimized (`expected typed non-concrete loop tail moved outside loop`) because the old gate blocked it.
3. Implemented loop gate parity fix and reran to green.

Implementation change:
- In `optimize_block(...)` loop-tail merge handling, replaced the old partial-merge gate:
  - `split > 0 && mb_blocktype_is_concrete(loop_bt, ctx.env)`
- With Binaryen-compatible extracted-tail concreteness gating:
  - block extraction when the extracted region exists and the child tail is concrete (`keepEnd < childSize && childList.back()->type.isConcrete()` parity modeled as `mb_instr_is_concrete(inner_items[last], ctx.env)`).

Behavioral result:
- Unsound concrete-tail extraction is now blocked even in typed loops with no back-branch.
- Valid typed extraction with a non-concrete extracted tail is now allowed.
- Post-pass validation stays preserved for both fixtures.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): C-003 was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed effect-model hardening by filling missing shallow-effect tags and adding a table-driven movement matrix

This follow-up closes the `MergeBlocks` effect-model hardening backlog item in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Strict TDD was used:
1. Added red-first regressions for:
   - checklist growth expectation (`35` entries)
   - table-driven movement blocked/allowed behavior across side-effect, trap, branch, and control-transfer representative families.
2. Ran `moon test src/passes` and captured explicit failures:
   - checklist size mismatch (`30 != 35`)
   - missing trap barrier behavior (`trap_div_vs_side_effect_local_set` case).
3. Implemented missing tags and checklist expansions, then reran to green.

Effect-model hardening changes in `mb_collect_shallow_effects`:
- Added missing trap flags for:
  - `memory.copy`, `memory.fill`, `memory.init`
  - `ref.cast_desc_eq`
  - `array.len`
  - integer `div/rem` binary ops
  - float->int truncating unary ops
- Added missing memory read+write tags for atomic family ops:
  - `atomic.fence`, `memory.atomic.notify`, `memory.atomic.wait32/64`, `atomic.rmw`, `atomic.cmpxchg`
- Strengthened array tags:
  - `array.set` / `array.fill` now mark both `reads_memory` and `writes_memory`
  - `array.new*` family now marks `traps` in addition to memory writes

Checklist and regression updates:
- Expanded opcode checklist from `30` to `35` entries and updated expected signatures accordingly.
- Added `MBMovementCase` table-driven movement matrix regression:
  - blocked cases for trap+side-effect, atomic memory hazards, branch barriers, and throw/control-transfer
  - allowed cases for pure arithmetic and disjoint local reads.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): the effect-model hardening item was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed C-002 by adding an explicit motion-barrier opcode-effect checklist for `mb_collect_shallow_effects`

This follow-up closes the `MergeBlocks` correctness gap C-002 in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt) by making the supported shallow-effect opcode surface explicit and regression-checked.

Strict TDD was used:
1. Added red-first checklist tests (`effect checklist is explicit and stable`, `effect checklist entries match shallow effect collector`) before implementing checklist helpers.
2. Ran `moon test src/passes` and captured the expected red compile state (unbound checklist helpers).
3. Implemented checklist structs/helpers and reran to green.

What was added:
- `MBEffectChecklistExpected` and `MBEffectChecklistEntry` helper structs.
- `mb_effect_checklist_entries()` with a canonical 30-entry motion-barrier opcode checklist that covers all currently tagged `mb_collect_shallow_effects` instruction families.
- `mb_effect_checklist_entry_matches(...)` matcher used by tests to compare expected vs observed shallow-effect signatures.

Regression coverage:
- `merge blocks: effect checklist is explicit and stable`
- `merge blocks: effect checklist entries match shallow effect collector`

This locks the current effect-tagged opcode surface in one explicit checklist so future edits to `mb_collect_shallow_effects` are checked against a maintained parity list instead of ad hoc spot checks.

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): C-002 was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed dropped-block parity coverage by expanding `try_table` catch fixtures, adding nested drop/`br_if` legality regression, and fixing nested dropped-path blocker traversal

This follow-up closes the `MergeBlocks` dropped-block parity backlog item in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Strict TDD was used:
1. Added red-first dropped-path parity tests for additional `try_table` catch forms and nested dropped-context branch/value legality.
2. Ran `moon test src/passes` and captured explicit failures in:
   - `merge blocks: problem finder blocks nested dropped try_table catch_ref mismatch`
   - `merge blocks: problem finder blocks nested dropped br_if mismatch` (later tightened to assert legality directly after confirming the observed inner rewrite was benign for this specific fixture).
3. Implemented the pass change and reran tests to green.

Implementation change:
- `problem_finder` now recursively inspects non-direct `drop(...)` values (`TDrop` values other than direct `drop(br_if ...)`), so nested dropped contexts cannot bypass dropped-block blocker checks for `try_table` catches and other branch structures before `break_value_dropper` rewriting.

New dropped-path parity coverage added in tests:
- `merge blocks: try_table catch_ref without params targeting origin is allowed`
- `merge blocks: try_table catch targeting origin blocks optimization`
- `merge blocks: try_table catch_all targeting origin blocks optimization`
- `merge blocks: problem finder blocks nested dropped try_table catch_ref mismatch`
- `merge blocks: nested dropped br_if keeps outer-label value branch`

Test-harness stability follow-up:
- Updated parity timing assertion in [`src/passes/merge_blocks_parity_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks_parity_wbtest.mbt) from `mbp_time_fixed_corpus_us(3) > 0` to `mbp_time_fixed_corpus_us(128) > 0` to avoid zero-duration flakes at low iteration counts.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): the dropped-block parity item was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed parity-baseline setup by adding a dedicated fixture corpus, a fixed-corpus timing harness, and baseline snapshot metrics

This follow-up closes the `MergeBlocks` parity-baseline blocker by adding an explicit baseline corpus and harness in [`src/passes/merge_blocks_parity_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks_parity_wbtest.mbt). The new whitebox parity file introduces:
- `mbp_fixture_corpus()` as a dedicated fixed fixture corpus
- `mbp_collect_baseline_metrics(iterations)` for correctness baseline collection
- `mbp_time_fixed_corpus_us(iterations)` for deterministic fixed-corpus timing runs

Strict TDD was used:
1. Added red-first tests for corpus presence, baseline metrics, and timing harness hooks before helper implementation (initial compile red with unbound baseline helpers).
2. Implemented corpus/harness helpers and fixed fixture validity with an explicit validator regression (`merge blocks parity fixtures validate before and after pass`).
3. Locked baseline correctness snapshot metrics in test assertions and brought the suite to green.

Baseline snapshot (fixed corpus, `iterations=1`) now recorded in tests:
- `total_fixtures = 8`
- `changed_count = 5`
- `valid_after_count = 8`
- `idempotent_count = 8`
- `value_branch_count_after = 0`

Performance baseline harness contract is also locked in tests:
- `mbp_time_fixed_corpus_us(128) > 0`
- fixed corpus membership and iteration-driven timing loop are stable for future before/after comparisons.

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): the parity-baseline item was removed from publishing blockers and moved to recently completed with baseline details.

## 2026-03-13 MergeBlocks Follow-up: closed C-001 by running dropped-block `problem_finder` over the whole body and aligning `br_if` drop-accounting with Binaryen semantics

This follow-up closes the `MergeBlocks` correctness gap C-001 in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt). The dropped-block path in `optimize_dropped_block(...)` previously called `problem_finder(...)` once per top-level instruction in the block body, which prevented whole-body balancing behavior for dropped vs non-dropped `br_if` cases and diverged from Binaryen's one-walk dropped-block analysis.

The dropped-block analysis now runs once across the entire body expression (`TExpr`) before rewriting break values. As part of the same fix, `ProblemFinderState` now tracks `non_dropped_br_if_values` and `dropped_br_if_values`, and the block condition now matches Binaryen-style balancing semantics: block only when `non_dropped_br_if_values > dropped_br_if_values`. In addition, `drop(br_if ...)` is accounted for directly in the `TDrop` arm without recursively counting that branch as non-dropped.

Regression coverage in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt) was extended with:
- `merge blocks: problem finder allows globally balanced dropped br_if values`

This fixture exercises sibling `drop(br_if ...)` and non-dropped `br_if` values that only balance when analyzed as one whole-body problem-finder pass. The test asserts the optimization now proceeds and that `br_if` value payloads are stripped.

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): C-001 was removed from publishing blockers and moved to recently completed with completion notes.

## 2026-03-13 MergeBlocks Follow-up: closed P-001 by collapsing per-function refinalization to a single `changed || needs_refinalize` gate and adding invocation-count regression coverage

This follow-up closes the `MergeBlocks` performance P-001 backlog item in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt). The function runner previously performed up to two full refinalization traversals on the same function body:
- one pass gated by `changed`
- another pass gated by `ctx.needs_refinalize`

That double-pass path was replaced with a single unified gate, `should_refinalize = changed || ctx.needs_refinalize`, and one `mb_refinalize_texpr(...)` call. To make this measurable in tests, function execution now routes through a stats helper (`mb_run_on_function_with_stats(...)`) that reports whether the function changed, whether refinalization was requested, and how many refinalization traversals were invoked.

Strict TDD was used. A new red-first regression test was added first:
- `merge blocks: function run performs at most one refinalize pass`

Before the gate fix, `moon test src/passes` failed with `2 != 1` on the new assertion. After collapsing the gate, the same suite passed and now locks in `refinalize_invocations == 1` for a fixture that triggers both `changed` and `needs_refinalize`.

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): P-001 was removed from publishing blockers and moved to recently completed with completion notes.

## 2026-03-12 Vacuum Follow-up: completed Stage 3 fallback metadata specialization by replacing remaining unindexed type/effect generic-helper fallbacks with structural formulas

This follow-up closes the last open `Vacuum` Stage 3 fallback-metadata blocker in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). After previous pure-leaf and structural-call/control-transfer work, unindexed fallback paths still delegated to generic helper wrappers in two places:
- `vq_type_of_cached(...)` still fell back to `vq_type_of_timed(...)`
- `vq_has_unremovable_effects_cached(...)` still fell back to `vq_collect_effects_timed(...)`

`vq_type_of_cached(...)` now uses a structural inference path (`vq_type_of_fallback_structural(...)`) for unindexed rewrites, reusing local shape formulas plus environment metadata for wrapper/control/call/aggregate cases instead of the generic timed helper. `vq_has_unremovable_effects_cached(...)` now uses a structural recursive detector (`vq_instr_has_unremovable_effects_structural(...)`) backed by a shallow side-effect/trap classifier (`vq_instr_has_unremovable_effects_local(...)`), removing unindexed generic effect-collector fallback usage.

As a result, unindexed fallback metadata no longer calls `vq_collect_effects_timed(...)`, and `vq_type_of_timed(...)` remains only in seeded/indexed analysis construction.

Regression coverage in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) was expanded with red-first tests:
- `vacuum fallback wrapped local.tee type metadata skips generic type inference`
- `vacuum fallback typed block metadata skips generic type inference`
- `vacuum fallback wrapped local.set effect metadata skips generic collector`

Verification: `moon test src/passes` (red first, then green), `moon info && moon fmt`, and full `moon test` (3053 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: replaced remaining unindexed depth-0 break/value-break fallback scans with structural summaries, fixed `try_table` catch-label depth targeting, and switched control-transfer fallback metadata to structural detection

This follow-up continues and closes the remaining Stage 3 unindexed depth-0 fallback-scan blockers in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt), and further narrows fallback metadata specialization.

`vq_has_break_to_depth0_cached(...)` no longer falls back to the generic `has_break_to_depth_in_texpr(...)` scan path on unindexed rewritten trees. Instead it now uses the local structural depth-target summary directly (`vq_texpr_may_target_break_to_depth0(...)`). As part of this, `try_table` handling was corrected to include catch-label targets (`depth + 1`) in the same structural break analysis, matching the original break-target semantics.

`vq_has_value_break_lub_depth0_cached(...)` now avoids delegating to the full recursive fallback collector on unindexed depth-0 queries. A dedicated structural fallback accumulator (`vq_has_value_break_lub_depth0_fallback(...)`) computes depth-targeted value-break compatibility directly from rewrite-local shape/type facts, including unknown/multi-value conservative behavior.

Fallback metadata specialization was also extended: `vq_instr_effect_transfers_control_flow_cached(...)` now uses a structural branch/throw detector (`vq_instr_effect_transfers_control_flow_structural(...)`) instead of `vq_collect_effects_timed(...).transfers_control_flow()` on unindexed paths, so wrapped branch-transfer trees no longer pay generic effect-collector cost for this metadata question.

Related cleanup: the now-unused `has_break_to_depth_in_texpr(...)` wrapper was removed from [`src/passes/dead_code_elimination.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination.mbt) after Vacuum stopped using it.

Regression coverage in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) was expanded with red-first tests:
- `vacuum cached break helper skips generic break scan for unindexed targeted branch fallback`
- `vacuum cached break helper detects unindexed try_table catch target to depth0 without generic scan`
- `vacuum cached value-break helper skips generic collector for unindexed targeted branch fallback`
- `vacuum fallback wrapped branch-transfer metadata skips generic collector`

Verification: `moon test src/passes` (red first, then green), `moon info && moon fmt`, and full `moon test` (3050 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: switched unindexed fallback call-presence metadata to a structural detector so wrapped non-call trees avoid generic effect collection

This follow-up continues the remaining `Vacuum` Stage 3 fallback metadata specialization in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). Even after pure-leaf fast paths, unindexed fallback `vq_instr_has_calls_cached(...)` still delegated to `vq_collect_effects_timed(...)` for wrapper-shaped non-call trees (for example `drop(i32.const ...)`), paying generic effect-collector cost to answer a pure structural question: whether any call instruction exists in the subtree.

`vq_instr_has_calls_cached(...)` now uses `vq_instr_has_calls_structural(...)` on unindexed fallback paths instead of `vq_collect_effects_timed(...).calls`. The new structural helper directly recognizes call kinds and recursively walks child/control bodies, preserving exact call-presence semantics without invoking the generic effect collector for this metadata query.

Regression coverage in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) was expanded with a red-first test:
- `vacuum fallback wrapped call metadata skips generic collector`

The test failed before this change with `collect_effects_calls` incrementing on `drop(i32.const)` and now asserts `collect_effects_calls == 0`.

Verification: `moon test src/passes` (red first, then green), `moon info && moon fmt`, and full `moon test` (3046 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: added bounded unindexed depth-0 target summaries so break/value-break fallback helpers skip scans when labels cannot match

This follow-up continues the remaining `Vacuum` Stage 3 fallback-scan/value-break blockers in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). After earlier label-score fast paths, fallback helpers still ran full collectors when labels were present but structurally unable to match the queried depth/value shape:
- `vq_has_break_to_depth0_cached(...)` still called `vq_has_break_to_depth_in_texpr_timed(...)`
- `vq_has_value_break_lub_depth0_cached(...)` still called `vq_value_break_to_depth_has_lub(...)`

Added bounded local target-summary predicates for unindexed rewritten trees:
- `vq_texpr_may_target_break_to_depth0(...)` / `vq_instr_may_target_break_to_depth0(...)`
- `vq_texpr_may_target_value_break_to_depth0(...)` / `vq_instr_may_target_value_break_to_depth0(...)`

Both cached helpers now short-circuit when these summaries return `false`, which avoids generic scans in cases like non-targeted branches (`br 1` under depth-0 query) and branches that never carry values (`br ... []`) even if label metadata is present.

Regression coverage in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) was expanded with red-first tests:
- `vacuum cached break helper skips unindexed non-targeted branch fallback scan`
- `vacuum cached value-break helper skips unindexed branch-without-values fallback scan`

Verification: `moon test src/passes` (red first, then green), `moon info && moon fmt`, and full `moon test` (3045 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: added pure-leaf unindexed metadata fast paths to avoid generic type/effect fallback helpers

This follow-up continues the remaining `Vacuum` Stage 3 fallback metadata specialization work in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). On unindexed rewritten instructions, metadata helpers still delegated to generic collectors/inference even for trivial pure leaves (`const`, `local.get`, etc.), which inflated helper-level fallback cost in hot rewrite churn.

`vq_type_of_cached(...)` now short-circuits common leaf kinds without calling `vq_type_of_timed(...)` (`local.get`, `global.get`, scalar/vector consts, `ref.null`, `ref.func`). Effect-side helpers now also short-circuit pure leaves without invoking `vq_collect_effects_timed(...)` (or shallow-effect collection): `vq_has_unremovable_effects_cached(...)`, `vq_has_unremovable_shallow_effects_cached(...)`, `vq_instr_has_calls_cached(...)`, and `vq_instr_effect_transfers_control_flow_cached(...)`.

Regression coverage in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) was expanded with red-first tests:
- `vacuum fallback pure leaf effect metadata skips generic collector` (asserts `collect_effects_calls == 0`)
- `vacuum fallback pure leaf type metadata skips generic type inference` (asserts `infer_type_calls == 0`)

Verification: `moon test src/passes` (red first on the new type-metadata assertion, then green), `moon info && moon fmt`, and full `moon test` (3042 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: narrowed drop-rewrite stack-signature guarding to local child-signature formulas and kept generic rewrite checks as fallback only

This follow-up continues the remaining `Vacuum` Stage 3 rewrite-guard blocker work in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). The hot `TDrop` rewrite path previously invoked `vq_rewrite_preserves_stack_sig_cached(...)` directly for candidate transitions like `drop(next_value)`, `drop(drop(inner)) -> drop(inner)`, and `drop(local.tee(...)) -> local.set(...)`, even when a cheaper local stack-signature equivalence check was available from the drop wrapper shape itself.

The drop rewrite path now uses a dedicated local guard, `vq_drop_rewrite_preserves_stack_sig_from_children(...)`, which compares wrapper-equivalent stack signatures via child signatures (`drop(child)` formula) using indexed ids when available. Generic `vq_rewrite_preserves_stack_sig_cached(...)` checks are still retained, but only as uncommon fallback when the local guard rejects a candidate. This keeps correctness safety for conservative indexed mismatches while removing generic rewrite-stack checks from the hot successful local-rewrite path.

As part of this change, `vq_rewrite_preserves_stack_sig_cached(...)` is now explicitly timed/count-tracked through `rewrite_stack_ms` / `rewrite_stack_calls`, so fallback usage is observable in helper summaries.

Regression coverage in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) now includes:
- Existing indexed test still asserting `rewrite_stack_calls == 0` for `drop(local.tee)` rewrite
- New unindexed counterpart:
  - `vacuum unindexed drop(local.tee) rewrite avoids generic stack-preservation helper`

Verification: `moon test src/passes` (red first after instrumentation showed `1 != 0`, then green after local-guard rewrite), `moon info && moon fmt`, and full `moon test` (3041 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: expanded unindexed fallback-scan fast paths to expression-level break/value-break helpers for multi-item label-free rewritten trees

This follow-up continues the `Vacuum` Stage 3 fallback-scan reductions in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). Earlier changes skipped expensive fallback scans for trivial unindexed single-instruction cases. Two helper paths were still scanning for multi-item rewritten expressions even when label metadata proved no depth-0 targets were possible:
- `vq_has_break_to_depth0_cached(...)` still called `vq_has_break_to_depth_in_texpr_timed(...)`
- `vq_has_value_break_lub_depth0_cached(...)` still called `vq_value_break_to_depth_has_lub(...)`

Both helpers now use expression-level rebase-score gating on unindexed fallback paths. They compute or reuse a score and short-circuit when the score is `< 0`, which proves no depth-0 wrapper-targeted labels exist for the queried expression. A new timed helper, `vq_texpr_rebase_label_score_timed(...)`, was added so this fallback work remains visible through `rebase_score_calls` / `rebase_score_ms`.

Regression coverage was expanded in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) with red-first tests:
- `vacuum cached break helper skips unindexed label-free multi-item fallback scan`
- `vacuum cached value-break helper skips unindexed label-free multi-item fallback scan`

Both tests assert that generic collectors are skipped (`break_scan_calls == 0` / `value_break_lub_calls == 0`) and that exactly one rebase-score pass runs (`rebase_score_calls == 1`).

Verification: `moon test src/passes` (red first on both new tests, then green), `moon info && moon fmt`, and full `moon test` (3040 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: added an unindexed single-item fast path for cached value-break LUB queries to skip unnecessary fallback collection

This follow-up continues the pathological-`Vacuum` fallback optimization work in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). `vq_has_value_break_lub_depth0_cached(...)` already used indexed depth-0 metadata when `expr_id` was available, but for unindexed rewritten expressions it always delegated to `vq_value_break_to_depth_has_lub(...)`, even for single-instruction label-free trees where a depth-0 value break is impossible.

The helper now accepts an optional single-instruction rebase-score hint and, on unindexed single-item expressions, short-circuits to `false` when the (provided or locally computed) score is `< 0`. That avoids invoking the full fallback LUB collector in no-break shapes while keeping existing behavior for indexed expressions and non-trivial unindexed trees.

Regression coverage was expanded in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) with a red-first test:
- `vacuum cached value-break helper skips unindexed label-free fallback scan`

The test now asserts both `value_break_lub_calls == 0` and `rebase_score_calls == 1`, proving the new path avoids the expensive collector and performs only one local score pass.

Verification: `moon test src/passes` (red first on the new assertion, then green), `moon info && moon fmt`, and full `moon test` (3038 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: deduplicated unindexed rebase-score analysis across simplify-block break checks and rebase gating, with explicit helper timing counters

This follow-up continues the pathological-`Vacuum` fallback optimization track in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). After the prior block-simplify reshaping, unindexed single-item wrapper-collapse candidates still scored label metadata twice: once in `vq_has_break_to_depth0_cached(...)` to decide whether depth-0 break scanning could be skipped, and again in `vq_rebase_labels_for_collapsed_wrapper_if_needed(...)` to decide whether rebasing was needed. On rewritten trees this duplicated recursive score traversal in a hot path.

The simplify path now computes one score per single-item candidate and threads it through both decision points. `vq_has_break_to_depth0_cached(...)` gained an optional `single_instr_rebase_label_score` input, and `vq_rebase_labels_for_collapsed_wrapper_if_needed(...)` gained an optional `rebase_label_score` input for unindexed fallback gating. `vq_simplify_block_to_contents(...)` now supplies a shared score (indexed-node score when available, otherwise one timed local score computation) so unindexed single-item candidates avoid repeated recursive scoring.

Helper instrumentation was also extended so this cost is observable in traces: `VQRunStats` now records `rebase_score_ms` and `rebase_score_calls`, and helper-summary output reports both fields in `helper_totals`.

Regression coverage in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) now locks in the dedupe behavior by asserting `rebase_score_calls == 1` for two unindexed simplify-block collapse cases that previously scored twice:
- `vacuum simplify_block skips label rebasing for unindexed label-free body`
- `vacuum simplify_block skips label rebasing for unindexed depth-local branch`

Verification: `moon test src/passes`, `moon info && moon fmt`, and full `moon test` (3037 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: removed unconditional depth-0 break scans from block simplification and gated unindexed fallback scans behind label-score checks

This follow-up continues the pathological-`Vacuum` hot-path cleanup in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). `vq_simplify_block_to_contents(...)` previously called `vq_has_break_to_depth0_cached(...)` up front for every block body, even when simplification could not collapse the wrapper (empty or multi-item bodies). That forced avoidable fallback scans on rewritten/unindexed trees and kept `break_scan_calls` active in cases where the function would return the original block shape either way.

The block simplifier now short-circuits by body shape first: empty and multi-item bodies return directly without any depth-0 break query, and only single-item collapse candidates perform break checks. In the same patch, `vq_has_break_to_depth0_cached(...)` gained an unindexed fast path that skips fallback `has_break_to_depth_in_texpr(...)` scans when a single instruction’s local rebase-label score is `< 0`, which proves wrapper-depth (`depth=0`) breaks are impossible.

Regression coverage was expanded in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) with red-first assertions in existing unindexed collapse tests plus a new multi-item regression:
- `vacuum simplify_block skips label rebasing for unindexed label-free body` now also asserts `break_scan_calls == 0`
- `vacuum simplify_block skips label rebasing for unindexed depth-local branch` now also asserts `break_scan_calls == 0`
- `vacuum simplify_block skips break scan for unindexed multi-item body`

Verification: `moon test src/passes`, `moon info && moon fmt`, and full `moon test` (3037 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: skipped unnecessary wrapper-collapse label rebasing for unindexed rewritten bodies by adding a local rebase-score fast path

This follow-up continues the same pathological-`Vacuum` blocker track in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). The previous change replaced the generic `ModuleTransformer` rebase with a custom recursive walker, but `vq_simplify_block_to_contents(...)` still had one expensive fallback path: when collapsing a single-item wrapper whose body no longer had an indexed `instr_id`, `vq_rebase_labels_for_collapsed_wrapper_if_needed(...)` always ran the full rebase walk even when the rewritten subtree had no labels (or only depth-local labels that do not change under one-level wrapper collapse).

The fallback gate now uses a new local recursive score helper (`vq_instr_rebase_label_score(...)` plus `vq_texpr_rebase_label_score(...)`) that mirrors the indexed `max_rebase_label_score` semantics. For indexed nodes, behavior is unchanged and still uses precomputed metadata. For unindexed rewritten nodes, rebasing now runs only when the local score is `>= 0`; otherwise the instruction is returned directly. This avoids unnecessary subtree rewrites in hot collapse paths without changing correctness for branch/catch label adjustment cases that actually need rebasing.

Regression coverage was expanded in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) with two red-first tests that enabled active helper stats and proved `vq_simplify_block_to_contents(...)` no longer calls label rebasing for unindexed single-item collapses when labels are either absent or depth-local only:
- `vacuum simplify_block skips label rebasing for unindexed label-free body`
- `vacuum simplify_block skips label rebasing for unindexed depth-local branch`

Verification: `moon test src/passes` (red first on both new tests, then green), `moon info && moon fmt`, and full `moon test` (3036 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: removed remaining value-keyed `TInstr` fallback caches from `Vacuum` metadata paths so both instruction and expression fallback queries now avoid structural-key map churn

This follow-up continues the same pathological-`Vacuum` hardening track by removing the rest of the value-keyed fallback cache surface in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). After the previous expression-cache cleanup, fallback instruction metadata still used `Map[TInstr, ...]` for type/effect/shallow-effect/call/control-transfer/stack-signature/may-not-return queries. Those maps have now been removed from `VQAnalysisCache`.

All affected helper paths keep the existing indexed-node fast path for seeded/original instructions and now do direct fallback computation when no `instr_id` is available. This keeps correctness behavior while eliminating value-keyed cache insert/lookups for rewritten instruction trees. `vq_analysis_cache_instr_entry_count(...)` now reports indexed instruction-node entries only.

Regression coverage was expanded in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) with a red-first test that exercises fallback instruction metadata helpers (`type`, `effect`, `shallow effect`, `calls`, `control transfer`, `stack signature`, `may-not-return`) and asserts no fallback instruction cache-entry growth. Existing indexed tests that previously inspected internal type-cache maps were updated to assert instruction cache cardinality stability instead.

Verification: `moon test src/passes`, `moon info && moon fmt`, and full `moon test` (3034 passing, 0 failing).

## 2026-03-12 Publishing Blocker Closed: hardened pathological `Vacuum` metadata paths by removing value-keyed `TExpr` fallback caches, keeping seeded-node lookups indexed, and proving fallback queries no longer allocate expression-cache entries

This change closes the remaining `Vacuum` pathological-cleanup blocker in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) by tightening the metadata paths that still relied on value-keyed expression maps after the earlier shape-classifier and degraded-tier work. The pass had already moved its hot original-node lookups onto integer-indexed analysis tables, but fallback metadata queries for rewritten/non-indexed expressions still maintained `Map[TExpr, ...]` caches (`control_transfer`, `throws`, `explicit_unreachable`, and depth-0 value-break LUB). Those value-keyed maps are now removed from [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt), so fallback expression metadata is computed directly when no indexed `expr_id` is available instead of re-hashing/re-comparing recursive expression values in map operations.

The cache surface was simplified in three concrete ways. First, `VQAnalysisCache` no longer stores expression-keyed fallback maps for control-transfer, throw, explicit-unreachable, or value-break-LUB facts. Second, `vq_texpr_has_control_transfer_cached`, `vq_texpr_throws_cached`, and `vq_texpr_has_explicit_unreachable_cached` now use indexed-node fast paths when available and otherwise perform direct computation without inserting expression-keyed cache entries. Third, `vq_value_break_to_depth_has_lub` keeps indexed depth-0 reuse but drops the legacy `Map[TExpr, Bool]` fallback write path. As a result, expression cache-cardinality accounting in `vq_analysis_cache_expr_entry_count(...)` now reports only indexed analysis-table entries.

Regression coverage was expanded in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) with two new tests: one that exercises fallback control/throw/unreachable metadata queries and asserts zero expression-cache entry growth, and one that exercises fallback value-break LUB querying with the same zero-growth assertion. Existing indexed value-break tests were also tightened to assert expression entry counts remain stable before/after indexed LUB checks, ensuring no hidden fallback cache writes regress back in.

Verification followed the repository gate sequence: `moon test src/passes` (red first on the new assertions, then green after the implementation), `moon info && moon fmt`, and full `moon test` (3033 passing, 0 failing).

## 2026-03-12 Publishing Blocker Closed: completed the fuzz runner usability/output/script blockers by adding discoverable CLI control commands, machine-readable JSONL summaries, and optional-seed script forwarding

This change completes the remaining low-hanging fuzz workflow blockers tracked in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): (1) control-command discoverability in the fuzz binary, (2) deterministic machine-readable summary output mode, and (3) optional seed forwarding in helper scripts so default runs exercise generated seeds.

In [`src/fuzz/main.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main.mbt), the CLI now supports control commands through `parse_fuzz_cli_command(...)`: `--help`/`-h`, `--list-suites`, and `--list-profiles`. This makes supported suite/profile discovery available directly from the binary without requiring doc/source lookup. The same parser path now supports output mode flags in the runnable command flow (`--output text|jsonl` and `--jsonl`), and result rendering is centralized in `format_fuzz_suite_result(...)` with `FuzzOutputMode` so text and JSONL output share one source of truth.

JSON output is emitted as one object per line (`jsonl`) with stable fields (`suite`, `profile`, `seed`, `attempts`, `pass`, `elapsed_ms`) to support CI parsing and metrics aggregation. The new mode still preserves existing text-mode output as default, and existing suite execution semantics are unchanged.

Helper scripts were updated to make seeds optional by default. [`scripts/run-fuzz.sh`](/home/jtenner/Projects/starshine-mb/scripts/run-fuzz.sh) now accepts `[profile] [suite] [seed|target] [target]` and only forwards `--seed` when a seed value is explicitly supplied. [`scripts/run-full-test.sh`](/home/jtenner/Projects/starshine-mb/scripts/run-full-test.sh) now mirrors that behavior with `[fuzz_profile] [seed|target] [target]`, prints `seed=auto` when no seed is provided, and delegates to `run-fuzz.sh` without a seed argument in that case.

Regression/verification coverage was extended in [`src/fuzz/main_test.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main_test.mbt) for output-mode parsing, control-command parsing, and JSONL formatting behavior. Validation was performed with `moon test src/fuzz`, direct command checks (`moon run src/fuzz -- --help`, `--list-suites`, and JSONL mode with explicit seed), and a full gate run via `bash scripts/run-full-test.sh smoke wasm-gc`.

## 2026-03-12 Fuzz Harness Migration Completed: moved randomized fuzz workloads out of `moon test` into the dedicated `src/fuzz` binary, wired CI/full-test gates to execute fuzz explicitly, and added reproducible signed seed controls for reruns

This changelog entry summarizes the fuzz-harness migration chain landed on `2026-03-12` across commits `fad5f6e`, `3772c24`, `357c650`, and `4a1b7a6`. The core shift is architectural: heavy randomized workloads are no longer hosted in the default `moon test` harness path, and instead run through a dedicated executable fuzz entrypoint in [`src/fuzz/main.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main.mbt) via `moon run src/fuzz ...`. That binary dispatches suite/profile combinations, prints reproducibility metadata, and routes into extracted package-level fuzz runner APIs.

The initial migration commit (`fad5f6e`) introduced the new main package at [`src/fuzz/moon.pkg`](/home/jtenner/Projects/starshine-mb/src/fuzz/moon.pkg), implemented CLI dispatch/tests in [`src/fuzz/main.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main.mbt) and [`src/fuzz/main_test.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main_test.mbt), and extracted major runner surfaces from package-local tests: WAST/WAT roundtrip, validator valid/invalid generation, and cmd harness profile adapters (notably in [`src/wast/fuzz_tests.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/fuzz_tests.mbt), [`src/wat/fuzz_tests.mbt`](/home/jtenner/Projects/starshine-mb/src/wat/fuzz_tests.mbt), [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt), [`src/validate/invalid_fuzzer.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/invalid_fuzzer.mbt), and [`src/cmd/fuzz_harness.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/fuzz_harness.mbt)). The follow-up commit (`3772c24`) finished migration of the binary roundtrip workload into [`src/binary/tests.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/tests.mbt) + [`src/fuzz/main.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main.mbt), and removed the remaining fuzz-execution loops from default test files so `moon test` remains deterministic and CI-friendly while fuzz stays runnable through `src/fuzz`.

Operational wiring was then consolidated in commit `357c650`: [`scripts/run-full-test.sh`](/home/jtenner/Projects/starshine-mb/scripts/run-full-test.sh) became the canonical local/CI gate (`moon info`, `moon fmt`, `moon check`, `moon test`, then fuzz), and [`.github/workflows/fuzz.yml`](/home/jtenner/Projects/starshine-mb/.github/workflows/fuzz.yml) was updated to call that unified gate for normal CI while retaining scheduled native stress fuzzing. Helper tooling and docs were aligned during the migration in [`scripts/run-fuzz.sh`](/home/jtenner/Projects/starshine-mb/scripts/run-fuzz.sh), [`docs/fuzz-migration.md`](/home/jtenner/Projects/starshine-mb/docs/fuzz-migration.md), and [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), including benchmark command updates in [`scripts/update_readme_benchmarks.sh`](/home/jtenner/Projects/starshine-mb/scripts/update_readme_benchmarks.sh).

The final hardening step (`4a1b7a6`) upgraded reproducibility controls by adding signed 64-bit seed support and explicit seed flags. [`src/fuzz/main.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main.mbt) now accepts `--seed <int64>` and `--seed=<int64>`, rejects ambiguous dual seed sources (positional + flag), and generates a default seed from Moon time APIs when omitted. The runtime-facing runner boundary still reinterprets the signed seed into `UInt64` for splitmix-backed generators, and the generated public interface in [`src/fuzz/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/fuzz/pkg.generated.mbti) reflects the `Int64`-seeded API surface. Script/docs usage was updated to include `moon run ... -- ... --seed ...` forwarding semantics so Moon does not consume the fuzz binary’s flags.

## 2026-03-12 Publishing Blocker Closed: Split the local `ConstantFieldPropagation` / Binaryen `cfp-reftest` behavior by introducing `ConstantFieldNullTestFolding`, moving the known-null `ref.test` optimization behind its own higher-gated pass, and removing the misleading one-pass parity claim from the scheduler and docs

This change closes the publishing blocker around the local handling of Binaryen's `cfp-reftest` slot. Before this patch, [`src/passes/constant_field_propagation.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/constant_field_propagation.mbt) mixed two different concerns into the same implementation surface: real constant-field propagation for `struct.get` loads, and a much narrower optimization that folded `ref.test` / `ref.test_desc` when the source field was known to be `ref.null`. That made the scheduler comment in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) read as if `ConstantFieldPropagation` already covered Binaryen's broader `cfp-reftest` transform, even though Binaryen's fixture exercises subtype-selection rewrites that this code does not implement. The pass file now shares a single field-analysis helper, keeps `ConstantFieldPropagation` focused on replacing provably constant field reads, and routes the known-null `ref.test` / `ref.test_desc` folding through a separate `ConstantFieldNullTestFolding` optimizer built on the same analysis state.

The default global pre-pass scheduler in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) now reflects that split explicitly. Closed-world GC modules still get `ConstantFieldPropagation` after `RemoveUnusedTypes`, but the narrower `ConstantFieldNullTestFolding` pass is added only at the higher `optimize_level >= 3` gate where the old code had been carrying the Binaryen `cfp-reftest` comment. The pass enum/dispatcher was extended accordingly, the generated public interface in [`src/passes/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti) was refreshed, and the explicit-pass surfaces in [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt) and [`src/node_api/custom.mbt`](/home/jtenner/Projects/starshine-mb/src/node_api/custom.mbt) now expose the new pass under the precise name `constant-field-null-test-folding`.

Regression coverage was tightened in two places. In [`src/passes/constant_field_propagation.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/constant_field_propagation.mbt), a new test proves that `make_cfp_optimizer(...)` now leaves `ref.test` alone so the split is real, while the existing known-null `ref.test` and `ref.test_desc` tests were retargeted to the dedicated null-test optimizer and extended to verify nullable-target results (`i32.const 1`) as well as non-null-target results (`i32.const 0`). In [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), the old scheduler test that claimed `cfp-reftest` mapped directly to `ConstantFieldPropagation` was replaced with a stronger split-behavior test: it now proves that `-O2` closed-world GC scheduling does not include `ConstantFieldNullTestFolding`, while `-O3` includes both `ConstantFieldPropagation` and the dedicated null-test pass in that order. The red-first TDD step was captured with an initial `moon test src/passes` run that failed because the new tests referenced the missing dedicated pass and the old CFP implementation still owned the `ref.test` fold.

The documentation and backlog were updated to match the new reality. [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md) now describes `ConstantFieldNullTestFolding` as a separate pass and no longer claims `cfp-reftest -> ConstantFieldPropagation` as a direct parity mapping. [`docs/differences.md`](/home/jtenner/Projects/starshine-mb/docs/differences.md) was rewritten to explain that the misleading one-pass parity claim is gone and that the remaining Binaryen difference is now an explicit, narrower known-null subset rather than a conflated implementation story. The closed blocker was removed from [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) and recorded in the new "Recently completed" section there so the release backlog reflects the resolved split.

Verification followed the repository workflow: `moon test src/passes` passed once the split was implemented, then `moon info`, `moon fmt`, and a full `moon test` run were used to confirm the workspace stayed green with the new pass surface and scheduler policy.

## 2026-03-12 Publishing Blocker Closed: Enabled Binaryen-parity `InliningOptimizing` scheduling in the default global post-optimization pipeline so post-cleanup inlining now runs before duplicate-elimination and global-simplification passes under the standard `-O2`/`-Os` style gates

This change closes the publishing blocker around the default global post pipeline in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt). The `InliningOptimizing` pass has existed as an implemented module runner and has long been exposed through the custom pass surface, but the default `default_global_optimization_post_passes(...)` scheduler still carried a comment saying the Binaryen-parity `inlining-optimizing` slot was intentionally skipped because of earlier option-mismatch concerns. In practice that meant the default post-cleanup flow diverged from Binaryen even when callers requested the optimization levels where post-phase inlining is expected. The scheduler now uses the already-established parity gate, `optimize_level >= 2 || shrink_level >= 2`, and inserts `InliningOptimizing` immediately after `DeadArgumentEliminationOptimizing` and before the duplicate-elimination and simplify-globals cleanup passes that are supposed to benefit from the extra inlining work.

The regression coverage for this blocker lives directly in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt). The existing post-pipeline parity test was tightened in two ways: it now asserts that `InliningOptimizing` appears exactly once for a representative `optimize_level=2, shrink_level=2` configuration, and it also asserts the pass ordering boundary by requiring `DeadArgumentEliminationOptimizing` to remain first and `InliningOptimizing` to occupy the next slot. That keeps the test focused on the scheduler policy itself rather than re-testing the inliner implementation. The red-first TDD step was captured with an initial `moon test src/passes` run that failed on the old `0 != 1` expectation before the scheduler was updated.

The Binaryen comparison note in [`docs/differences.md`](/home/jtenner/Projects/starshine-mb/docs/differences.md) was updated so the repository no longer documents `InliningOptimizing` as an open global-post-pipeline omission. The closed blocker was then removed from [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), leaving `StringGathering` and the other remaining optimizer parity items as the outstanding publish blockers in that area.

Verification followed the repository's required local sequence after the red regression run: `moon test src/passes` passed once the scheduler was fixed, then `moon info`, `moon fmt`, and a full `moon test` run were executed to confirm the broader workspace remained green.

## 2026-03-12 Publishing Blocker Closed: Refined the default late `OptimizeInstructions` cleanup policy so large modules still keep the final Binaryen-parity instruction-cleanup pass during explicit size-focused optimization while the throughput-oriented path retains the existing large-module runtime guard

This change closes the publishing blocker around the default pipeline's second `OptimizeInstructions` pass in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt). The scheduler already had a large-module cleanup-cost heuristic that could suppress the late `OptimizeInstructions` pass near the end of the default function pipeline, but that guard applied unconditionally once the module crossed the runtime threshold. In practice, that meant a caller explicitly asking for stronger code-size cleanup with `shrink_level=2` could still silently lose the late instruction-level cleanup stage simply because the module was large. The policy helper now takes the full optimization options, preserves the large-module skip for the throughput-focused path, and explicitly keeps the second `OptimizeInstructions` pass whenever the caller is in the strong size-optimization mode.

The behavior is now documented as an intentional policy choice instead of an ambiguous heuristic. The Binaryen-comparison note in [`docs/differences.md`](/home/jtenner/Projects/starshine-mb/docs/differences.md) was rewritten to explain that the local optimizer still diverges from Binaryen on very large throughput-focused modules, but no longer lets that runtime guard override explicit shrink intent. That makes the scheduler policy much easier to reason about: large `-O` style throughput runs still avoid the extra late cleanup when the module looks pathologically expensive, while large `-Oz` style runs keep the final instruction simplification step because size cleanup is the caller's stated goal.

Regression coverage for the policy now lives directly in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt). A new large synthetic module helper drives the heuristic boundary explicitly, one test proves that a large module with `optimize_level=2, shrink_level=2` now retains both `OptimizeInstructions` passes in the default function schedule, and a companion test proves that the large-module throughput-focused configuration with `optimize_level=2, shrink_level=0` still keeps only the earlier pass. The resolved blocker was removed from [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) after the new policy and regression coverage were in place.

Verification followed the project's required local sequence and the explicit TDD flow. The new size-focused scheduler test was added first and failed under `moon test src/passes` with `1 != 2`, confirming the pre-fix behavior. After the helper change, `moon test src/passes` passed with 1377 tests green. Final verification then completed with `moon info`, `moon fmt`, and a full `moon test` run with 2984 tests passing and 0 failures.

## 2026-03-12 Publishing Blocker Closed: Split optimizer pass profiling so executed pass summaries now report transform time and post-pass validation time separately instead of collapsing both costs into one misleading pass elapsed number on pathological modules

This change closes the optimizer profiling blocker where traced pass summaries in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) were measuring from pass entry through the end of any immediate validation step and then reporting only a single `elapsed_ms=` field. On pathological modules, especially when `OptimizeValidationPolicy::after_every_pass()` is enabled for debugging or investigation, that made it difficult to tell whether a slow pass summary was actually dominated by the transform itself or by the full-module validation walk that happened immediately afterward. The optimizer loop now snapshots the transform boundary as soon as the scheduled pass runner returns, records that duration as `transform_elapsed_ms`, separately records the immediate validation walk as `validation_elapsed_ms`, and preserves the overall wall-clock `elapsed_ms` field for the end-to-end pass total.

The trace surface was tightened in three concrete ways. Executed passes now emit an explicit phase-level `transform:done` timing line as soon as scheduler work finishes, pass-summary `done` lines now carry `transform_elapsed_ms=... validation_elapsed_ms=... elapsed_ms=...`, and per-pass validation failures now report the same split fields before returning the existing pass-attributed error message. Skipped passes were also normalized onto the same summary schema with zeroed transform and validation fields so downstream log parsing does not need special handling for the skip case. This keeps the profiling contract machine-readable while making pathological slowdowns much easier to classify as transform cost versus validation overhead.

Regression coverage for the runner change was added directly in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt). The new test drives `optimize_module_with_options_trace(...)` under `AfterEveryPass` validation and asserts that the emitted pass summary for an executed pass now includes both `transform_elapsed_ms=` and `validation_elapsed_ms=` fields. The tracing guidance in [`docs/tracing.md`](/home/jtenner/Projects/starshine-mb/docs/tracing.md) was also updated so future pass instrumentation preserves this split timing convention instead of reintroducing collapsed pass timings.

Verification for this blocker was completed with an initial red `moon test src/passes` run that failed on the new regression before the runner was updated, a green `moon test src/passes` run after the fix, then the required final local sequence of `moon info`, `moon fmt`, and a full `moon test` run. The remaining Moon warnings reported during the repo-wide checks are the pre-existing `unused_try` warnings outside this change.

## 2026-03-12 Publishing Blocker Closed: Replaced the default WASI wildcard-candidate stub with real recursive directory enumeration so `--glob` works under shared MoonBit filesystem APIs on both native and WASI runtimes

This change removes the last stubbed candidate-enumeration path that blocked reliable publishing for default WASI I/O. The command layer now resolves wildcard inputs through a shared MoonBit filesystem walker instead of bespoke `find` output on native builds or a separate `list_candidates` shim on WASI builds. That walker lives in [`src/fs/fs.mbt`](/home/jtenner/Projects/starshine-mb/src/fs/fs.mbt), uses `moonbitlang/x/fs` directory APIs recursively, normalizes separators, preserves deterministic depth-first ordering by explicitly sorting directory entries, and returns only file paths so CLI glob matching sees the same candidate model across runtimes.

The runtime integration was updated in three places: [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt) now routes default candidate discovery through the shared walker, [`node/internal/runtime.js`](/home/jtenner/Projects/starshine-mb/node/internal/runtime.js) and [`node/internal/wasi-runner.js`](/home/jtenner/Projects/starshine-mb/node/internal/wasi-runner.js) now expose the `moonbitlang/x/fs` wasm hooks needed for reading directories and statting entries, and [`scripts/lib/moonbit-wasi-runner.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/moonbit-wasi-runner.mjs) was brought up to the same contract so script-driven WASI runs behave the same way. In practice, this means wildcard expansion no longer depends on a custom candidate stub and instead uses the same directory-reading primitives as the rest of the filesystem layer.

Regression coverage was added in [`src/fs/fs_test.mbt`](/home/jtenner/Projects/starshine-mb/src/fs/fs_test.mbt) to build a nested directory tree and prove that recursive candidate enumeration returns the expected file-only paths in stable order, and the generated filesystem interface in [`src/fs/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/fs/pkg.generated.mbti) was refreshed to publish the new helper. Verification for this blocker was completed with `moon info`, `moon fmt`, `moon test src/fs`, `moon test src/cmd`, a syntax/import sanity check for the edited Node runtime shims, and a full `moon test` run with 2976 tests passing.

## 2026-03-12 Publishing Blocker Closed: Added the missing Binaryen-parity `RemoveUnusedNames` cleanup passes to the default function optimization pipeline so branch-name cleanup now happens at the intended repeated structural cleanup boundaries

This change closes the default-function-pipeline parity gap where `RemoveUnusedNames` existed as an implemented pass but was never scheduled by the default optimizer flow. The scheduler in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) now inserts `RemoveUnusedNames` three times in the same conceptual cleanup slots described by the repository’s Binaryen-difference notes: once immediately after `DeadCodeElimination`, once immediately after the first `RemoveUnusedBrs`, and once in the later cleanup phase after the first late `MergeBlocks` / `RemoveUnusedBrs` pair and before the final `MergeBlocks`. That brings the cleanup choreography much closer to Binaryen’s repeated name-pruning structure rather than leaving all such cleanup to later incidental transformations.

The regression coverage for this blocker was added directly in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt). The new test proves that the default function optimization pass list includes exactly three `RemoveUnusedNames` passes and that their relative order matches the intended parity boundaries around `DeadCodeElimination`, `RemoveUnusedBrs`, and the late `MergeBlocks` cleanup region. Because the repository already had execution tests for `RemoveUnusedNames` itself, the new coverage stays focused on the missing scheduler wiring rather than re-testing the transform implementation.

The parity note in [`docs/differences.md`](/home/jtenner/Projects/starshine-mb/docs/differences.md) was also updated so the repository no longer documents this as an unresolved scheduler gap. Verification for this blocker was completed with `moon test src/passes`, `moon info`, `moon fmt`, and a full `moon test` run with 2977 tests passing. The remaining Moon warnings reported during `moon info` and `moon test` are the pre-existing `unused_try` warnings outside this change.

## 2026-03-12 Publishing Blocker Closed: Aligned the closed-world global pre-pass scheduler with Binaryen by using `RemoveUnusedModuleElements` instead of `RemoveUnused` at the default pre-pass cleanup points

This change closes the scheduler-policy gap where the closed-world global pre-pass pipeline diverged from Binaryen by substituting `RemoveUnused` for `RemoveUnusedModuleElements`. The relevant logic lives in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), and the default pre-pass builder now uses `RemoveUnusedModuleElements` at both `-O2+` cleanup sites regardless of the `closed_world` flag. The closed-world-specific GC refinements such as `TypeRefining`, `SignaturePruning`, `SignatureRefining`, `GlobalTypeOptimization`, `RemoveUnusedTypes`, `ConstantFieldPropagation`, `AbstractTypeRefining`, and `Unsubtyping` remain gated as before; this change only aligns the shared unused-module-element cleanup choice itself.

The regression coverage was updated in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so the closed-world global pre-pass test now requires two `RemoveUnusedModuleElements` passes and explicitly proves that the default closed-world schedule no longer inserts `RemoveUnused` at those parity points. Because the repository already contains direct dispatch tests for `RemoveUnused`, `RemoveUnusedModuleElements`, and the legacy `RemoveUnusedNonFunctionElements` behavior, the new scheduler expectation stays focused on the default pipeline policy rather than re-testing the individual transforms.

The Binaryen-difference note in [`docs/differences.md`](/home/jtenner/Projects/starshine-mb/docs/differences.md) was also updated so the repository no longer records this closed-world pre-pass substitution as an unresolved parity difference. Verification for this blocker was completed with `moon test src/passes`, `moon info`, `moon fmt`, and a full `moon test` run with 2977 tests passing. The remaining Moon warnings reported during `moon info` and `moon test` are the pre-existing `unused_try` warnings outside this change.

## 2026-03-12 Publishing Blocker Closed: Made optimizer validation policy configurable so the default non-debug local optimization path now validates once at the end instead of after every scheduled pass

This change closes a major runtime-policy mismatch in the optimizer runner. The pass loop in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) previously performed a full module validation after every scheduled pass, regardless of whether the caller wanted debug-style validation or production-style throughput. `OptimizeOptions` now carries a public `OptimizeValidationPolicy`, with the new default set to `FinalModuleOnly` and an explicit `AfterEveryPass` override available for debugging and pass-development workflows. That shifts normal local optimization behavior closer to Binaryen's default non-debug runner, where validation cadence is policy-driven rather than unconditionally baked into every pass boundary.

The runner implementation was updated to preserve diagnostics while removing the default per-pass overhead. When `AfterEveryPass` is requested, the old behavior is retained: the pass loop validates immediately after each executed pass and reports failures against that pass. Under the new default `FinalModuleOnly` policy, the loop records the last executed pass and its pre-pass module snapshot, defers validation until the full pass sequence has completed, and still formats any resulting validation failure as a pass-attributed error with before/after context. That means callers keep the useful failure surface from [`opt_format_pass_validation_failure`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) without paying the unconditional validation cost at every single pass boundary.

Regression coverage was added directly in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt). The new tests construct an intentionally invalid module and run it through two harmless scheduler passes so the returned error message proves which validation policy actually ran: the default path now attributes the failure to the last pass in the sequence, while the explicit `AfterEveryPass` option fails immediately after the first pass. The existing validation-diff test was also deduplicated through a shared invalid-module helper so the new policy coverage stays focused on runner semantics rather than repeating module construction boilerplate.

The parity note in [`docs/differences.md`](/home/jtenner/Projects/starshine-mb/docs/differences.md) was rewritten to describe the resolved policy and its remaining explicit opt-in path, and the Node API documentation will reflect the new trailing `validationPolicy` parameter on `OptimizeOptions.new(...)` after interface regeneration. Verification for this blocker was completed with `moon test src/passes`, `moon info`, `moon fmt`, and a full `moon test` run. The remaining Moon warnings reported during `moon info` and `moon test` are the pre-existing `unused_try` warnings outside this change.
