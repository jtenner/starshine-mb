# Project Layout

- MoonBit workspace with directory-scoped packages via `moon.pkg` under `moon.mod.json`.
- Tests live beside implementation as `*_test.mbt` or `*_wbtest.mbt`.
- Package imports live in `package*/imports.mbt`.
- `docs/README.md`: canonical docs and wiki schema.
- `docs/`: normative docs only: schema, policies, ADRs, and active handoff docs.
- `docs/wiki/`: living wasm knowledge base.
- `docs/wiki/raw/`: committed raw sources; treat as immutable except for redaction or format normalization.
- `docs/wiki/raw/research/[serial]-[YYYY-MM-DD]-[kebab-title].md`: one-off research, plan, audit, and benchmark docs, including absorbed investigations moved out of `docs/`.
- `docs/wiki/index.md`: human-readable wiki catalog.
- `docs/wiki/log.md`: append-only wiki history.
- `src/`: active packages are `binary`, `cli`, `cmd`, `diff`, `fs`, `fuzz`, `ir`, `lib`, `spec_runner`, `validate`, `validate_proof`, `validate_trace`, `wast`, `wat`.
- `src/node_api/`, `src/optimization/`, `src/transformer/`: empty compatibility or staging dirs; do not describe as active unless rebuilt.
- `examples/`: runnable examples.
- `tests/spec/`, `tests/node/`: external and integration coverage.
- `scripts/`: Bun entrypoints only: `validate.ts`, `fuzz.ts`, `self-opt.ts`, `make.ts`, `examples.ts`, `pass-fuzz-compare.ts`.
- `scripts/lib/*`: shared script code.
- `scripts/test/*`: script tests.
- `agent-todo.md`: active unreleased backlog only.
- `agent-lost-and-found.md`: local friction notes only; never commit.

# Tasks And Rules

## Core Work

- Use TDD: write tests first, confirm failure, then implement.
- Start from `docs/` for major architecture, ABI, release, planning, or wiki-schema work.
- For knowledge-base ingest, query, lint, or schema work, read `docs/README.md` first.
- Keep docs concise; update relevant docs for behavior or API changes.
- Review `.mbti` diffs for public API changes.
- Update pass tests in the implementing file and active dispatcher.
- Today that is usually `src/cmd/cmd.mbt`; later also `src/passes/optimize.mbt`.
- Do not remove features, disable passing tests, add telemetry-only tests, or add shell scripts under `scripts/`.
- Gitignore new non-repo build or cache dirs when needed.
- Do not use destructive git commands unless explicitly requested.

## Docs And Wiki

- `AGENTS.md` is the short operational contract; `docs/README.md` is the full docs and wiki schema. If one changes, update both in the same change.
- Keep `docs/` for normative docs only; put one-off investigations under `docs/wiki/raw/research/` and living concepts, decisions, comparisons, and reusable wasm knowledge under `docs/wiki/`.
- Every wiki schema, ingest, query-fileback, or lint change must keep `docs/wiki/index.md` and `docs/wiki/log.md` current.
- Prefer updating an existing wiki page over creating a near-duplicate page.
- Cite supporting numbered docs, raw sources, tests, or source files.
- Record uncertainty, contradictions, and supersession explicitly; do not silently overwrite stale claims.
- Treat completed debugging, research, and design threads as sources; file durable conclusions back into the wiki.
- Once a research note has been fully absorbed into the wiki and is no longer the active normative contract, move it out of `docs/` into `docs/wiki/raw/research/` and repoint live references.
- Do not commit secrets, credentials, tokens, or other private material into `docs/wiki/` or `docs/wiki/raw/`.

## Working On Passes

- Correctness first.
- Match oracle Binaryen at minimum.
- Target `< 1s` or `>= 50%` of Binaryen wall time where possible.
- Verify parity with `bun fuzz compare-pass ...` or `bun scripts/pass-fuzz-compare.ts ...` at `10000` comparisons.

## Commit

- Update relevant docs and `CHANGELOG.md` before commit.
- Keep changelog entries concise: date, bold short title, completed intent.
- Review the staged diff.
- Commit with `git commit -F <temp-file>`, not `git commit -m`.
- Include changed files and reasons in commit text.
- Prune stale `agent-todo.md` items and add new blockers or risks.

## Publish

- Require an explicit semver bump: `patch`, `minor`, or `major`.
- Run validation first and stop on failure.
- Bump all package versions consistently before tagging.
- Reuse changelog text for tag and release notes.
- Push commit, annotated tag, and release once.

## Research

- Use the next zero-padded serial with commit date and short kebab title.
- Scan `docs/`, `docs/wiki/`, and `docs/wiki/raw/research/` for matching topics, pass names, and legacy aliases first.
- Cover scope, current behavior, correctness constraints, validation plan, performance impact, and open questions.
- Put substantial investigations in numbered `docs/wiki/raw/research/` files; also update `docs/wiki/` when the conclusions should stay live and reusable.
- Update README and code references when replacing legacy path notes.

## Backlog

- Keep `agent-todo.md` grouped by release target and IR2 slice id.
- Keep only active unreleased work there.
- Include goal, why, deliverables, tasks, required APIs, invariants, dependencies, exit criteria, and suggested tests.
- Keep release blockers and known test failures visible until resolved.

## MoonBit Style

- Use block-structured `///|`; block order is non-semantic.
- Prefer constructor methods over open-struct literals.
- Keep deprecated behavior in `deprecated.mbt` with `#deprecated`.

# Tools

## Core MoonBit

- `moon info`
- `moon fmt`
- `moon check`
- `moon test`
- `moon test --update`

## Bun Workflow

- `bun validate ...`
- `bun fuzz ...`
- `bun self-opt ...`
- `bun make ...`
- `bun examples ...`

## Fuzzing And Pass Comparison

- Run fuzzing via `moon run src/fuzz ...` or `bun fuzz run ...`.
- Do not put heavy randomized loops inside `moon test`.
- For pass-specific Starshine vs Binaryen differential fuzzing, use `bun fuzz compare-pass ...` or `bun scripts/pass-fuzz-compare.ts ...`.
- Prefer `--pass <name>` with canonical pass names.
- Use `bun scripts/pass-fuzz-compare.ts --list-passes` to discover supported passes.
- Treat the harness as a targeted pass tool: start with one named pass and only expand to multi-pass runs when combined-pass behavior is the goal.
- The harness alternates `wasm-tools smith` and in-repo `gen_valid`, validates with `wasm-tools validate`, and compares normalized `wasm-opt -S --strip-debug` output.

## Validation And Signoff

- Preferred quick signoff: `moon info && moon fmt`, then `moon test`.
- Prefer `bun validate` before committing.
- Local full gate: `bun validate full --profile ci --target wasm-gc`.
- Coverage: `bun validate coverage`.
- README sync: `bun validate readme-api-sync`.
- Serialize `moon` commands because they contend on `_build/.moon-lock`.

## Permission-Gated Runs

- Ask before running the full self-optimize pipeline.
- Ask before running `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --optimize`.
- Parity signoff requires canonical parity and Starshine wall time `>= 50%` of Binaryen where possible.
