# Starshine Docs And Wasm Knowledge Base

This file is the canonical schema for documentation and wiki maintenance in this repo. It consolidates the current repo rules from `AGENTS.md` and the wiki-maintenance rules adapted from Andrej Karpathy's `LLM Wiki` pattern plus Rohit Gupta's `LLM Wiki v2` extension.

If `AGENTS.md` and this file ever diverge, update both in the same change. Keep repo-wide operational constraints in `AGENTS.md`; keep the longer wiki schema here.

## Current Repo Rules

### Project Layout

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
- `src/`: active packages are `binary`, `cli`, `cmd`, `diff`, `fs`, `fuzz`, `ir`, `lib`, `spec_runner`, `validate`, `validate_trace`, `wast`, `wat`.
- `src/node_api/`, `src/optimization/`, `src/transformer/`: empty compatibility or staging dirs; do not describe as active unless rebuilt.
- `examples/`: runnable examples.
- `tests/spec/`, `tests/node/`: external and integration coverage.
- `scripts/`: Bun entrypoints only: `validate.ts`, `fuzz.ts`, `self-opt.ts`, `make.ts`, `examples.ts`, `pass-fuzz-compare.ts`.
- `scripts/lib/*`: shared script code.
- `scripts/test/*`: script tests.
- `agent-todo.md`: active unreleased backlog only.
- `agent-lost-and-found.md`: local friction notes only; never commit.

### Tasks And Rules

#### Core Work

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

#### Docs And Wiki

- `AGENTS.md` is the short operational contract; `docs/README.md` is the full docs and wiki schema. If one changes, update both in the same change.
- Keep `docs/` for normative docs only; put one-off investigations under `docs/wiki/raw/research/` and living concepts, decisions, comparisons, and reusable wasm knowledge under `docs/wiki/`.
- Every wiki schema, ingest, query-fileback, or lint change must keep `docs/wiki/index.md` and `docs/wiki/log.md` current.
- Prefer updating an existing wiki page over creating a near-duplicate page.
- Cite supporting numbered docs, raw sources, tests, or source files.
- Record uncertainty, contradictions, and supersession explicitly; do not silently overwrite stale claims.
- Treat completed debugging, research, and design threads as sources; file durable conclusions back into the wiki.
- Once a research note has been fully absorbed into the wiki and is no longer the active normative contract, move it out of `docs/` into `docs/wiki/raw/research/` and repoint live references.
- Do not commit secrets, credentials, tokens, or other private material into `docs/wiki/` or `docs/wiki/raw/`.

#### Working On Passes

- Correctness first.
- Match oracle Binaryen at minimum.
- Target `< 1s` or `>= 50%` of Binaryen wall time where possible.
- Verify parity with `bun fuzz compare-pass ...` or `bun scripts/pass-fuzz-compare.ts ...` at `10000` comparisons.

#### Commit

- Update relevant docs and `CHANGELOG.md` before commit.
- Keep changelog entries concise: date, bold short title, completed intent.
- Review the staged diff.
- Commit with `git commit -F <temp-file>`, not `git commit -m`.
- Include changed files and reasons in commit text.
- Prune stale `agent-todo.md` items and add new blockers or risks.

#### Publish

- Require an explicit semver bump: `patch`, `minor`, or `major`.
- Run validation first and stop on failure.
- Bump all package versions consistently before tagging.
- Reuse changelog text for tag and release notes.
- Push commit, annotated tag, and release once.

#### Research

- Use the next zero-padded serial with commit date and short kebab title.
- Scan `docs/`, `docs/wiki/`, and `docs/wiki/raw/research/` for matching topics, pass names, and legacy aliases first.
- Cover scope, current behavior, correctness constraints, validation plan, performance impact, and open questions.
- Put substantial investigations in numbered `docs/wiki/raw/research/` files; also update `docs/wiki/` when the conclusions should stay live and reusable.
- Update README and code references when replacing legacy path notes.

#### Backlog

- Keep `agent-todo.md` grouped by release target and IR2 slice id.
- Keep only active unreleased work there.
- Include goal, why, deliverables, tasks, required APIs, invariants, dependencies, exit criteria, and suggested tests.
- Keep release blockers and known test failures visible until resolved.

#### MoonBit Style

- Use block-structured `///|`; block order is non-semantic.
- Prefer constructor methods over open-struct literals.
- Keep deprecated behavior in `deprecated.mbt` with `#deprecated`.

### Tools

#### Core MoonBit

- `moon info`
- `moon fmt`
- `moon check`
- `moon test`
- `moon test --update`

#### Bun Workflow

- `bun validate ...`
- `bun fuzz ...`
- `bun self-opt ...`
- `bun make ...`
- `bun examples ...`

#### Fuzzing And Pass Comparison

- Run fuzzing via `moon run src/fuzz ...` or `bun fuzz run ...`.
- Do not put heavy randomized loops inside `moon test`.
- For pass-specific Starshine vs Binaryen differential fuzzing, use `bun fuzz compare-pass ...` or `bun scripts/pass-fuzz-compare.ts ...`.
- Prefer `--pass <name>` with canonical pass names.
- Use `bun scripts/pass-fuzz-compare.ts --list-passes` to discover supported passes.
- Treat the harness as a targeted pass tool: start with one named pass and only expand to multi-pass runs when combined-pass behavior is the goal.
- The harness alternates `wasm-tools smith` and in-repo `gen_valid`, validates with `wasm-tools validate`, and compares normalized `wasm-opt -S --strip-debug` output.

#### Validation And Signoff

- Preferred quick signoff: `moon info && moon fmt`, then `moon test`.
- Prefer `bun validate` before committing.
- Local full gate: `bun validate full --profile ci --target wasm-gc`.
- Coverage: `bun validate coverage`.
- README sync: `bun validate readme-api-sync`.
- Serialize `moon` commands because they contend on `_build/.moon-lock`.

#### Permission-Gated Runs

- Ask before running the full self-optimize pipeline.
- Ask before running `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --optimize`.
- Parity signoff requires canonical parity and Starshine wall time `>= 50%` of Binaryen where possible.

## Wasm Knowledge Base Rules

### Scope

- The wiki exists to accumulate durable WebAssembly knowledge for this repo: spec semantics, Binaryen parity findings, Starshine invariants, pass behavior, debugging lessons, tooling quirks, and decision history.
- Keep `docs/` for normative docs only: schema, policies, ADRs, and active handoff docs.
- Use numbered `docs/wiki/raw/research/[serial]-[YYYY-MM-DD]-[kebab-title].md` files for one-off research, plans, audits, and benchmarks.
- Use `docs/wiki/` for living pages that should be updated over time instead of replaced.

### Architecture

Keep three layers in the wiki architecture:

- Raw sources: immutable inputs captured under `docs/wiki/raw/` when they belong in the repo.
- Research archive: repo-authored numbered investigations under `docs/wiki/raw/research/`.
- Wiki pages: maintained markdown under `docs/wiki/`.
- Schema: this file, which defines layout, workflows, and quality standards.
- Treat raw sources as read-only after capture except for redaction or format normalization needed to remove sensitive data.
- Keep `docs/wiki/index.md` as the human-readable catalog of living wiki pages.
- Keep `docs/wiki/log.md` as the append-only chronological audit trail for ingests, queries filed back into the wiki, and lint passes.

### Minimal Viable Wiki Layout

- Start with `docs/wiki/raw/`, `docs/wiki/index.md`, and `docs/wiki/log.md`.
- Add topic pages directly under `docs/wiki/` until volume makes subdirectories worthwhile.
- Create subdirectories only when the page count demands them; sensible future buckets are `concepts/`, `entities/`, `decisions/`, `comparisons/`, and `sessions/`.
- Prefer standard markdown links that render on GitHub. Do not rely on Obsidian-only wikilinks as the primary link format.

### Page Rules

- One durable topic, entity, invariant, workflow, or decision per page.
- Use concise titles and stable filenames; rename only when the page meaning materially changes.
- Cite the source pages, raw sources, or numbered research docs that support the page's claims.
- Record contradictions, caveats, and uncertainty explicitly instead of smoothing them away.
- When useful, add lightweight frontmatter for `kind`, `status`, `last_reviewed`, `sources`, `related`, `supersedes`, or `superseded_by`.
- Use links to related files, passes, proposals, and research docs so the page is navigable without chat history.

### Ingest Rules

- On new source, read it, extract the durable takeaways, and decide whether it belongs as a raw source, a numbered research doc under `docs/wiki/raw/research/`, an update to existing wiki pages, or all three.
- Update the affected wiki pages instead of creating near-duplicate pages for the same concept.
- Add or refresh the relevant entry in `docs/wiki/index.md`.
- Append a dated entry to `docs/wiki/log.md`.
- If the source changes an existing belief, mark the previous claim stale or superseded instead of silently overwriting history.
- If an old numbered doc in `docs/` has become absorbed research rather than active policy or handoff material, move it into `docs/wiki/raw/research/` in the same change.

### Query Rules

- Answer questions from the wiki first, then expand to raw sources and numbered docs when needed.
- Cite the wiki pages and supporting sources used for the answer.
- If a query produces durable knowledge, file it back into the wiki as a page update or a new page in the same change.
- Prefer the output format that matches the question: markdown summary, comparison table, timeline, dependency map, or structured data export.

### Lint Rules

- Periodically scan for contradictions, stale claims, orphan pages, missing backlinks, broken links, duplicate concepts, and data gaps worth researching.
- Auto-fix safe issues in the same pass when the correct repair is obvious.
- Flag unclear conflicts and capture the competing claims plus supporting sources.
- Keep the wiki tending toward health without waiting for a dedicated cleanup sprint.

### Lifecycle Rules

- Not all claims are equally strong; preserve how well-supported a claim is.
- Track confidence using source count, recency, and contradiction status. A simple status ladder such as `working`, `supported`, `strong`, `stale`, or `superseded` is acceptable.
- Newer, better-supported information should weaken or supersede older claims automatically.
- Do not delete useful older knowledge by default; demote or mark it stale unless it is incorrect noise or sensitive material that should not be kept.
- Architecture rules and long-lived invariants decay slowly; transient bugs and one-off observations decay quickly.

### Knowledge Graph Rules

- Go beyond flat prose where it helps: keep typed relationships explicit.
- Common entity types in this repo include proposals, instructions, passes, packages, files, tools, benchmarks, bugs, invariants, and decisions.
- Common relationship types include `uses`, `depends_on`, `contradicts`, `caused`, `fixes`, `supersedes`, `validated_by`, and `measured_by`.
- Pages are for reading; the typed links between them are for navigation, search, and impact analysis.

### Search Rules

- Use `docs/wiki/index.md` as the first catalog at small scale.
- Use repo search tools such as `rg` as the default local retrieval path once the wiki grows.
- If the wiki grows beyond what one index page can support comfortably, add stronger search rather than bloating the index indefinitely.
- Keep the index human-readable even if better search is added later.

### Automation Rules

- Favor event-driven maintenance over manual bookkeeping when tooling exists.
- On new source, update the wiki, index, and log together.
- On session end, crystallize durable findings into pages or numbered docs.
- On schedule, run lint, consolidation, and retention review.
- When adding future tooling, prioritize automation that reduces filing and cross-reference maintenance rather than replacing human curation.

### Quality And Self-Correction Rules

- Score or label content quality based on structure, evidence, consistency, and usefulness.
- Prefer self-healing maintenance: repair links, add missing cross-references, and flag stale claims proactively.
- Resolve contradictions by preferring newer, stronger, better-sourced claims, while preserving the audit trail.
- The wiki should accumulate trust over time, not just accumulate text.

### Collaboration Rules

- The committed wiki is shared project knowledge.
- Personal workflow notes belong in local-only files such as `agent-lost-and-found.md`, not in the committed wiki.
- Use `agent-todo.md` for active execution tracking; use `docs/wiki/` for durable knowledge.
- When multiple sessions touch the wiki, merge changes with timestamped log entries and explicit supersession when claims conflict.

### Privacy And Governance Rules

- Strip secrets, credentials, tokens, and other sensitive material before committing raw sources or wiki pages.
- Keep the log detailed enough to explain what changed and why.
- Make bulk cleanup or consolidation reversible in git and documented in `docs/wiki/log.md`.

### Crystallization Rules

- Completed research, debugging, or design threads are sources too.
- Distill them into durable digests that capture the question, findings, files involved, lessons learned, and follow-up questions.
- Use numbered `docs/wiki/raw/research/` docs when the output is a substantial investigation; use `docs/wiki/` when the result is a living concept or decision page.

### Wasm-Specific Priorities

- Bias toward knowledge that helps future Starshine work: validation behavior, pass contracts, IR invariants, spec edge cases, Binaryen parity findings, performance evidence, and toolchain behavior.
- Prefer pages that answer repeat questions such as "what does this proposal change," "what invariants does this pass rely on," "what breaks when this validation rule is violated," and "how does Starshine differ from Binaryen here."
- Link wiki pages back to numbered docs, tests, and relevant source files so knowledge stays grounded in the codebase.

## References

- Rohit Gupta, `LLM Wiki v2`: <https://gist.github.com/rohitg00/2067ab416f7bbe447c1977edaaa681e2>
- Andrej Karpathy, `LLM Wiki`: <https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f>
