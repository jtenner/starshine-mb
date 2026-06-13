# Repo Essentials

- MoonBit workspace under `moon.mod`; `src/` contains one folder for each package.
- Review `.mbti` diffs for public API changes.
- `docs/README.md` is the canonical docs and wiki schema; keep it in sync with this file.
- Keep active backlog, wiki index/log, and local-only notes aligned with the docs schema.

# Always-Follow Workflow Rules

- Use TDD: write or update tests first, confirm failure, then implement.
- Start from `docs/` for major architecture, ABI, release, planning, or wiki-schema work. Read `docs/README.md` first for knowledge-base ingest, query, lint, or schema work.
- Update relevant docs for behavior or API changes; keep docs concise.
- Update pass tests in the implementing file and active dispatcher. Today that is usually `src/cmd/cmd.mbt`; later also `src/passes/optimize.mbt`.
- Do not remove features, disable passing tests, add telemetry-only tests, or add shell scripts under `scripts/`.
- Tests for behavior that should be implemented must fail before implementation; do not write green "fail-closed success" or no-op tests for required behavior gaps.
- Boundary/fail-closed tests are allowed only when the behavior is intentionally unsupported or invalid, and the test name/comment must say so clearly.
- Do not assert "differs from Binaryen on purpose" unless the test demonstrates an intentional Starshine semantic, validation, size, or performance win and documents why divergence is desired.
- Do not accept Binaryen-vs-Starshine drift as merely "safe" representation difference. If a diff is not a proven Starshine win, treat it as a parity gap to reduce or fix.
- Gitignore new non-repo build or cache dirs when needed.
- Do not use destructive git commands unless explicitly requested.
- Serialize `moon` commands because they contend on `_build/.moon-lock`.

# Task-Specific Rules

## Docs And Wiki

- Prefer updating an existing wiki page over creating a near-duplicate page.
- Cite supporting numbered docs, raw sources, tests, or source files.
- Record uncertainty, contradictions, and supersession explicitly; do not silently overwrite stale claims.
- Treat completed debugging, research, and design threads as sources; file durable conclusions back into the wiki.
- Once a research note in `docs/` has been fully absorbed and is no longer the active normative contract, move it to `docs/wiki/raw/research/` and repoint live references.
- Never commit secrets, credentials, tokens, or other private material into `docs/wiki/` or `docs/wiki/raw/`.

## Working On Passes

- Correctness first.
- Match oracle Binaryen semantics at minimum; byte-for-byte wasm, raw canonical wasm/text, or transform-for-transform parity is not required when normalized/canonical semantic evidence proves equivalence.
- Prefer matching Binaryen output shape when there is no clear Starshine benefit. A remaining output-shape difference may be kept only when it is intentional, source-backed, documented, and shown to be a Starshine win such as smaller canonical output, fewer effective local/stack operations without size regressions, better downstream cleanup, stronger validation/correctness, or materially better pass-local performance.
- Do not classify a diff family as safe/acceptable just because both outputs validate, appear semantically equivalent, or use fewer locals. Measure relevant deltas and either prove the Starshine shape wins without important regressions, or align to Binaryen.
- Every transform must be safe and produce a valid wasm module.
- Target `< 1s` or `>= 50%` of Binaryen pass-local wall time where possible.
- Verify parity at `10000` comparisons with an explicit prebuilt native Starshine binary and parallel workers: first run `moon build --target native --release src/cmd`, then use `bun fuzz compare-pass ... --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` (or the equivalent `bun scripts/pass-fuzz-compare.ts ... --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`). The compare-pass harness uses `.tmp/pass-fuzz-cache` by default to reuse deterministic `wasm-smith` inputs and Binaryen oracle outputs/failures across runs; use `--cache-dir <dir>` for shared or isolated caches and `--no-cache` only when debugging cache behavior. Starshine outputs are never cached.
- For DAE / `dae-optimizing` mixed-generator compare-pass lanes, include `--normalize drop-consts --normalize unreachable-control-debris` so known generated dropped-constant and unreachable/control debris counts as `cleanupNormalizedMatchCount` instead of blocking the run as raw mismatches; still classify any remaining mismatches normally.
- When reporting compare-pass mismatches, classify them as an agent judgment, not as a harness-provided fact: Starshine-win, parity gap, size-losing, unknown/risky, validation failure, tool/Binaryen failure, or true semantic mismatch. Do not call a mismatch semantically safe just because both outputs validate or Starshine is smaller; cite the transform contract, inspected diff family, replay evidence, measured size/performance/downstream deltas, or other semantic reason. If there is no measured Starshine benefit, keep the mismatch open as a parity gap.
- Prefer `--pass <name>` with canonical pass names and treat the harness as pass-targeted before expanding to combined-pass runs.
- Use `.pi/skills/starshine-pass-implementation/SKILL.md` as the detailed pass creation, porting, parity-fix, registry-wiring, and signoff workflow.

## Validation And Signoff

- Preferred quick signoff for behavior changes: `moon info`, `moon fmt`, then `moon test`.
- Docs-only commits do not require tests; use diff/link/source review unless docs change generated contracts or executable examples.
- Forward-moving test or expectation updates do not require a test run unless the intent is to fix related behavior.
- Positive behavior changes may be committed even if they temporarily leave some tests failing, as long as the commit is clear forward progress and the failure state is documented.
- Prefer `bun validate` before committing when the change needs repository-wide confidence.
- Local full gate: `bun validate full --profile ci --target wasm-gc`.
- Coverage: `bun validate coverage`.
- README sync: `bun validate readme-api-sync`.

## Commit And Publish

- Use `.pi/skills/commit/SKILL.md` whenever the user asks to commit.
- Update relevant docs before commit; do not add per-commit changelog entries.
- Use docs/wiki pages, `docs/wiki/log.md`, release notes, and git history for durable change records.
- Treat any request to "commit" as a request to split the worktree by top-level unit of change and commit each unit separately.
- Prefer large, detailed commits that explain what changed and why while staying as atomic as possible.
- Review the staged diff for each atomic unit.
- Commit titles must use `<kind>: <title>`.
- Commit with `git commit -F <temp-file>` and include changed files plus reasons in the commit body.
- Prune stale `agent-todo.md` items and add new blockers or risks.
- Publishing requires an explicit semver bump, successful validation, consistent package version bumps, and release notes drafted from the relevant docs/wiki pages and git history.

## Research, Backlog, And MoonBit Style

- Research docs use the next zero-padded serial with commit date and short kebab title after scanning `docs/`, `docs/wiki/`, and `docs/wiki/raw/research/` for overlaps.
- Substantial investigations belong in `docs/wiki/raw/research/`; keep durable conclusions live in `docs/wiki/` when they should remain reusable.
- Keep `agent-todo.md` grouped by release target and IR2 slice id, with only active unreleased work plus goal, why, deliverables, tasks, required APIs, invariants, dependencies, exit criteria, and suggested tests.
- Keep release blockers and known test failures visible until resolved.
- MoonBit style: use block-structured `///|`, prefer constructor methods over open-struct literals, and keep deprecated behavior in `deprecated.mbt` with `#deprecated`.
